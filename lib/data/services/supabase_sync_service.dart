import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/utils/phone_number_utils.dart';
import '../repositories/deletion_retry_queue_repository.dart';
import '../repositories/retention_policy_repository.dart';
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
  final DeletionRetryQueueRepository _deletionRetries =
      DeletionRetryQueueRepository();
  final RetentionPolicyRepository _retentionPolicy =
      RetentionPolicyRepository();

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
    'barangays', // no dependencies
    'customers', // depends on barangays
    'orders', // depends on customers
    'sms_messages', // no dependencies
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
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
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
        await _processDeletionRetryQueue(supabase);
        await _processSyncedRowDeletions(supabase);
        for (final table in _syncTables) {
          await _syncTable(supabase, table);
        }
        await _retentionPolicy.applyDefaultPolicy();

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
    final pendingDeletedIds = await _localSync.pendingDeletedRowIds(tableName);
    final lastRemoteId = await _localSync.lastRemoteId(tableName);
    final remoteRows = await _fetchRemoteRows(
      client,
      tableName,
      afterId: lastRemoteId,
    );
    final insertedRemoteRows = await _localSync.mergeRemoteRows(
      tableName,
      remoteRows,
      excludedIds: pendingDeletedIds,
    );
    final maxRemoteId = _maxRowId(remoteRows);
    if (maxRemoteId > lastRemoteId) {
      await _localSync.saveSyncState(tableName, lastRemoteId: maxRemoteId);
    }

    final baselineUploaded = await _localSync.isBaselineUploaded(tableName);
    final rows = baselineUploaded
        ? await _getDueLocalRows(tableName)
        : await _localSync.getRowsForSync(tableName);
    if (rows.isEmpty) return;

    const batchSize = 50;
    for (int i = 0; i < rows.length; i += batchSize) {
      final batch = rows.skip(i).take(batchSize).toList();
      await client.from(tableName).upsert(_cleanRows(batch), onConflict: 'id');
      if (!baselineUploaded) {
        await _localSync.markUpsertRowsSucceeded(tableName, _rowIds(batch));
      }
    }

    if (baselineUploaded) {
      final syncedQueueIds = rows
          .map((row) => (row['_sync_queue_id'] as num?)?.toInt())
          .whereType<int>();
      await _localSync.markUpsertsSucceeded(syncedQueueIds);
    } else {
      await _localSync.saveSyncState(tableName, baselineUploaded: true);
    }

    debugPrint(
      'Synced $tableName: pulled $insertedRemoteRows remote rows, '
      'pushed ${rows.length} local rows',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteRows(
    SupabaseClient client,
    String tableName, {
    int afterId = 0,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];

    for (int offset = 0; ; offset += pageSize) {
      var query = client.from(tableName).select();
      if (afterId > 0) {
        query = query.gt('id', afterId);
      }
      final page = await query
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final pageRows = page
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      rows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _getDueLocalRows(String tableName) async {
    final queueRows = await _localSync.dueUpsertRows(tableName);
    final idsByRowId = <int, int>{};
    for (final queueRow in queueRows) {
      final queueId = (queueRow['id'] as num?)?.toInt();
      final rowId = (queueRow['row_id'] as num?)?.toInt();
      if (queueId == null || rowId == null) continue;
      idsByRowId[rowId] = queueId;
    }
    final rows = await _localSync.getRowsByIds(
      tableName,
      idsByRowId.keys.toSet(),
    );
    final decoratedRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      final rowId = (row['id'] as num?)?.toInt();
      final queueId = rowId == null ? null : idsByRowId[rowId];
      if (queueId == null) continue;
      decoratedRows.add({...row, '_sync_queue_id': queueId});
    }

    final foundRowIds = decoratedRows
        .map((row) => (row['id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    for (final entry in idsByRowId.entries) {
      if (!foundRowIds.contains(entry.key)) {
        await _localSync.markUpsertsSucceeded([entry.value]);
      }
    }
    return decoratedRows;
  }

  List<Map<String, dynamic>> _cleanRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final cleaned = <String, dynamic>{};
      for (final entry in row.entries) {
        if (entry.key.startsWith('_sync_')) continue;
        cleaned[entry.key] = entry.value;
      }
      return cleaned;
    }).toList();
  }

  Iterable<int> _rowIds(List<Map<String, dynamic>> rows) {
    return rows.map((row) => (row['id'] as num?)?.toInt()).whereType<int>();
  }

  int _maxRowId(List<Map<String, dynamic>> rows) {
    var maxId = 0;
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null && id > maxId) maxId = id;
    }
    return maxId;
  }

  Future<void> _processSyncedRowDeletions(SupabaseClient client) async {
    final dueDeletes = await _localSync.dueDeletedRows();
    for (final delete in dueDeletes) {
      final id = delete['id'] as int;
      final tableName = delete['table_name'] as String;
      final rowId = (delete['row_id'] as num).toInt();
      try {
        await client.from(tableName).delete().eq('id', rowId);
        await _localSync.markDeletedRowSynced(id);
      } on Exception catch (e) {
        await _localSync.markDeletedRowFailed(id, e);
      }
    }
  }

  Future<void> _processDeletionRetryQueue(SupabaseClient client) async {
    final dueRetries = await _deletionRetries.dueCustomerErasures();
    for (final retry in dueRetries) {
      final id = retry['id'] as int;
      final phoneNumber = retry['phone_number'] as String;
      try {
        await _deleteCustomerFromSupabaseClient(client, phoneNumber);
        await _deletionRetries.markSucceeded(id);
      } on Exception catch (e) {
        await _deletionRetries.markFailed(id, e);
      }
    }
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

    try {
      await _deleteCustomerFromSupabaseClient(client, normalized);
    } on Exception catch (e) {
      await _deletionRetries.enqueueCustomerErasure(
        phoneNumber: normalized,
        lastError: e,
      );
      rethrow;
    }
  }

  Future<void> _deleteCustomerFromSupabaseClient(
    SupabaseClient client,
    String phoneNumber,
  ) async {
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    // Remove SMS history (contains message bodies with personal identifiers).
    await client.from('sms_messages').delete().eq('phone_number', normalized);

    // Anonymize orders — strip phone and address, keep aggregate stats.
    await client
        .from('orders')
        .update({'phone_number': '', 'address': null})
        .eq('phone_number', normalized);

    // Remove the customer record (Supabase FK cascade removes schedules/logs).
    await client.from('customers').delete().eq('contact_number', normalized);
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
