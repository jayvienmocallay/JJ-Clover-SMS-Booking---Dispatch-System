// Task 012 - Alarm service: loud audio alarm for DROP commands
// Plays a continuous alarm sound until staff acknowledges.
// Persists active alerts so background SMS isolates can wake the UI isolate.
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../repositories/settings_repository.dart';

/// Manages the walk-in alarm audio playback.
///
/// Android can deliver SMS callbacks to a background Dart isolate, where this
/// singleton is not shared with the foreground UI. Active alerts are therefore
/// persisted and also forwarded through [IsolateNameServer] when the UI isolate
/// is alive.
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const String _activeAlertSettingKey = 'active_drop_alarm';
  static const String _uiAlarmPortName = 'jj_clover_drop_alarm_port';

  final AudioPlayer _player = AudioPlayer();
  final _settings = SettingsRepository();
  ReceivePort? _uiAlarmPort;
  bool _isPlaying = false;

  // DROP order details shown in the alert overlay.
  String? _customerPhone;
  int? _quantity;
  DateTime? _triggeredAt;

  bool get isPlaying => _isPlaying;
  String? get customerPhone => _customerPhone;
  int? get quantity => _quantity;
  DateTime? get triggeredAt => _triggeredAt;

  /// Triggers the alarm for a DROP order.
  ///
  /// [phone] is the customer's phone number.
  /// [qty] is the number of gallons in the DROP order.
  Future<void> trigger({required String phone, required int qty}) async {
    final alert = _DropAlarmAlert(
      phone: phone,
      quantity: qty,
      triggeredAt: DateTime.now(),
    );

    await _persistAlert(alert);

    // The UI isolate owns audible playback so acknowledge can always stop it.
    // Background SMS isolates only persist and notify the UI isolate.
    if (_uiAlarmPort != null || kIsWeb) {
      await _activateAlert(alert);
    } else {
      _sendToUiIsolate(alert);
    }
  }

  /// Registers the foreground isolate to receive DROP alerts from SMS callbacks.
  Future<void> startUiSync() async {
    if (kIsWeb) return;

    if (_uiAlarmPort == null) {
      final port = ReceivePort();
      var registered = IsolateNameServer.registerPortWithName(
        port.sendPort,
        _uiAlarmPortName,
      );

      if (!registered) {
        IsolateNameServer.removePortNameMapping(_uiAlarmPortName);
        registered = IsolateNameServer.registerPortWithName(
          port.sendPort,
          _uiAlarmPortName,
        );
      }

      if (registered) {
        _uiAlarmPort = port;
        port.listen((message) async {
          final alert = _DropAlarmAlert.fromMessage(message);
          if (alert != null) {
            await _activateAlert(alert);
          }
        });
      } else {
        port.close();
        debugPrint('AlarmService: Unable to register UI alarm port');
      }
    }

    await syncPendingAlert();
  }

  /// Stops receiving cross-isolate alert messages for the current UI isolate.
  void stopUiSync() {
    if (kIsWeb) return;

    IsolateNameServer.removePortNameMapping(_uiAlarmPortName);
    _uiAlarmPort?.close();
    _uiAlarmPort = null;
  }

  /// Loads any persisted unacknowledged DROP alert and activates it in the UI.
  Future<void> syncPendingAlert() async {
    if (kIsWeb) return;

    final alert = await _loadPersistedAlert();
    if (alert == null) return;

    if (_isSameAlert(alert) && _isPlaying) {
      return;
    }

    await _activateAlert(alert);
  }

  Future<void> _activateAlert(_DropAlarmAlert alert) async {
    final alreadyPlaying = _isSameAlert(alert) && _isPlaying;

    _customerPhone = alert.phone;
    _quantity = alert.quantity;
    _triggeredAt = alert.triggeredAt;
    _isPlaying = true;
    notifyListeners();

    if (alreadyPlaying) return;

    try {
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/alarm.wav'));
      debugPrint(
        'AlarmService: Alarm triggered for DROP from '
        '${alert.phone} (${alert.quantity} gal)',
      );
    } catch (e) {
      debugPrint('AlarmService: Error playing alarm - $e');
      // Even if audio fails, keep the visual alert active.
    }
  }

  /// Stops the alarm when staff acknowledges.
  Future<void> acknowledge() async {
    await _clearPersistedAlert();

    _isPlaying = false;
    notifyListeners();

    try {
      await _player.stop();
      debugPrint('AlarmService: Alarm acknowledged');
    } catch (e) {
      debugPrint('AlarmService: Error stopping alarm - $e');
    }
  }

  Future<void> _persistAlert(_DropAlarmAlert alert) async {
    if (kIsWeb) return;

    try {
      await _settings.setSetting(
        _activeAlertSettingKey,
        jsonEncode(alert.toJson()),
      );
    } catch (e) {
      debugPrint('AlarmService: Error persisting alert - $e');
    }
  }

  Future<_DropAlarmAlert?> _loadPersistedAlert() async {
    if (kIsWeb) return null;

    try {
      final raw = await _settings.getSetting(_activeAlertSettingKey);
      return _DropAlarmAlert.fromJsonString(raw);
    } catch (e) {
      debugPrint('AlarmService: Error loading persisted alert - $e');
      return null;
    }
  }

  Future<void> _clearPersistedAlert() async {
    if (kIsWeb) return;

    try {
      await _settings.deleteSetting(_activeAlertSettingKey);
    } catch (e) {
      debugPrint('AlarmService: Error clearing persisted alert - $e');
    }
  }

  void _sendToUiIsolate(_DropAlarmAlert alert) {
    if (kIsWeb) return;

    final sendPort = IsolateNameServer.lookupPortByName(_uiAlarmPortName);
    if (sendPort == null) {
      debugPrint('AlarmService: No UI alarm port; alert persisted for resume');
      return;
    }

    sendPort.send(alert.toJson());
  }

  bool _isSameAlert(_DropAlarmAlert alert) {
    return _customerPhone == alert.phone &&
        _quantity == alert.quantity &&
        _triggeredAt?.toIso8601String() == alert.triggeredAt.toIso8601String();
  }

  /// Disposes the audio player (call on app shutdown).
  @override
  void dispose() {
    stopUiSync();
    _player.dispose();
    super.dispose();
  }
}

class _DropAlarmAlert {
  const _DropAlarmAlert({
    required this.phone,
    required this.quantity,
    required this.triggeredAt,
  });

  final String phone;
  final int quantity;
  final DateTime triggeredAt;

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'quantity': quantity,
      'triggeredAt': triggeredAt.toIso8601String(),
    };
  }

  static _DropAlarmAlert? fromMessage(Object? message) {
    if (message is Map) {
      return fromJson(Map<String, dynamic>.from(message));
    }

    if (message is String) {
      return fromJsonString(message);
    }

    return null;
  }

  static _DropAlarmAlert? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static _DropAlarmAlert? fromJson(Map<String, dynamic> json) {
    final phone = json['phone'] as String?;
    final quantity = json['quantity'];
    final triggeredAt = DateTime.tryParse(json['triggeredAt'] as String? ?? '');

    if (phone == null || triggeredAt == null) {
      return null;
    }

    return _DropAlarmAlert(
      phone: phone,
      quantity: quantity is int ? quantity : int.tryParse('$quantity') ?? 0,
      triggeredAt: triggeredAt,
    );
  }
}
