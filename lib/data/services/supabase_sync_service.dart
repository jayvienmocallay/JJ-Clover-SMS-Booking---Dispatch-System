import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/utils/phone_number_utils.dart';
import '../repositories/settings_repository.dart';
import '../repositories/supabase_local_sync_repository.dart';

/// Sync status for UI display
enum SyncStatus { idle, syncing, success, error }

class SupabaseSyncService extends ChangeNotifier {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool _initialized = false;
  bool _autoSyncEnabled = false;
  bool _wifiOnly = false;
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  Timer? _periodicTimer;
  StreamSubscription? _connectivitySub;
  final SettingsRepository _settings = SettingsRepository();
  final SupabaseLocalSyncRepository _localSync = SupabaseLocalSyncRepository();

  bool get initialized => _initialized;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get wifiOnly => _wifiOnly;
  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;

  /// Tables synced to Supabase in FK dependency order.
  ///
  /// Intentionally excluded:
  /// - `pending_sms_actions` — local-only TTL state machine (30-min flows).
  ///   Syncing it would allow another device to interfere with an in-progress
  ///   registration or delete-confirm conversation.
  /// - `incoming_sms_receipts` — local deduplication guard tied to this
  ///   device's SMS receiver. Syncing would cause other devices to silently
  ///   drop messages they never saw.
  static const List<String> _syncTables = [
    'barangays',     // no dependencies
    'customers',     // depends on barangays
    'orders',        // depends on customers
    'sms_messages',  // no dependencies
  ];

  Future<void> initialize() async {
    if (_initialized) return;

    final autoSync = await _settings.getSetting('auto_sync_enabled');
    final wifi = await _settings.getSetting('sync_wifi_only');
    final lastSync = await _settings.getSetting('last_synced_at');

    _autoSyncEnabled = autoSync == 'true';
    _wifiOnly = wifi == 'true';
    _lastSyncedAt = lastSync != null ? DateTime.tryParse(lastSync) : null;

    _initialized = true;

    if (_autoSyncEnabled) {
      _startAutoSync();
    }

    await _updatePendingCount();
    notifyListeners();
  }

  Future<void> setAutoSync(bool enabled) async {
    _autoSyncEnabled = enabled;
    await _settings.setSetting('auto_sync_enabled', enabled.toString());

    if (enabled) {
      _startAutoSync();
      unawaited(syncAll());
    } else {
      _stopAutoSync();
    }
    notifyListeners();
  }

  Future<void> setWifiOnly(bool enabled) async {
    _wifiOnly = enabled;
    await _settings.setSetting('sync_wifi_only', enabled.toString());
    notifyListeners();
  }

  void _startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      if (_shouldSync(results)) {
        // Delay lets Android DNS resolver finish configuring after interface comes up.
        await Future.delayed(const Duration(seconds: 3));
        unawaited(syncAll());
      }
    });

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final results = await Connectivity().checkConnectivity();
      if (_shouldSync(results)) {
        await syncAll();
      }
    });
  }

  void _stopAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  bool _shouldSync(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) return false;
    if (_wifiOnly && !results.contains(ConnectivityResult.wifi)) return false;
    return true;
  }

  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (!_shouldSync(connectivity)) {
      _lastError = 'No suitable network connection';
      _status = SyncStatus.error;
      notifyListeners();
      return;
    }

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    const retryDelays = [Duration(seconds: 3), Duration(seconds: 8)];
    Exception? lastException;

    for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('Sync retry $attempt after DNS/network failure...');
          await Future.delayed(retryDelays[attempt - 1]);
        }

        final supabase = Supabase.instance.client;
        for (final table in _syncTables) {
          await _syncTable(supabase, table);
        }

        _lastSyncedAt = DateTime.now();
        _status = SyncStatus.success;
        _lastError = null;
        await _settings.setSetting(
          'last_synced_at',
          _lastSyncedAt!.toIso8601String(),
        );
        await _updatePendingCount();
        notifyListeners();
        return;
      } on Exception catch (e) {
        lastException = e;
        debugPrint('Sync attempt ${attempt + 1} failed: $e');
      }
    }

    _lastError = lastException.toString();
    _status = SyncStatus.error;
    notifyListeners();
  }

  Future<void> _syncTable(SupabaseClient client, String tableName) async {
    final rows = await _localSync.getRowsForSync(tableName);
    if (rows.isEmpty) return;

    const batchSize = 50;
    for (int i = 0; i < rows.length; i += batchSize) {
      final batch = rows.skip(i).take(batchSize).toList();
      final cleanedBatch = batch.map((row) {
        final cleaned = <String, dynamic>{};
        for (final entry in row.entries) {
          cleaned[entry.key] = entry.value;
        }
        return cleaned;
      }).toList();

      await client.from(tableName).upsert(cleanedBatch, onConflict: 'id');
    }

    debugPrint('Synced ${rows.length} rows from $tableName');
  }

  /// RA 10173 right-to-erasure cascade on Supabase.
  ///
  /// Called after the local customer deletion succeeds.
  /// Removes the customer's personal data from all synced Supabase tables so
  /// the right to erasure is honoured both locally and in the cloud.
  ///
  /// If the device is offline this call will throw — the caller must handle
  /// offline erasure requests (e.g. queue for next sync).
  Future<void> deleteCustomerFromSupabase(String phoneNumber) async {
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    final client = Supabase.instance.client;

    // Remove SMS history (contains message bodies with personal identifiers).
    await client
        .from('sms_messages')
        .delete()
        .eq('phone_number', normalized);

    // Anonymize orders — strip phone and address, keep aggregate stats.
    await client
        .from('orders')
        .update({'phone_number': '', 'address': null})
        .eq('phone_number', normalized);

    // Remove the customer record (Supabase FK cascade removes schedules/logs).
    await client
        .from('customers')
        .delete()
        .eq('contact_number', normalized);
  }

  Future<void> _updatePendingCount() async {
    try {
      int count = 0;
      for (final table in _syncTables) {
        count += await _localSync.countRows(table);
      }
      _pendingCount = count;
    } catch (e) {
      debugPrint('Error counting pending: $e');
    }
  }

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}
