// Task 008 — System Mode Manager: 4-mode toggle with ChangeNotifier (Provider-ready)
// Task 013 — Singleton pattern so UI toggles and background service share the same mode
// Task 014 — Persist mode so background SMS isolates read the same state as UI
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../database_helper.dart';

class SystemModeManager extends ChangeNotifier {
  static const String _modeSettingKey = 'system_mode';

  // Singleton — shared within an isolate. The persisted setting is the
  // cross-isolate source of truth for headless SMS callbacks.
  static final SystemModeManager instance = SystemModeManager._();
  SystemModeManager._({bool persistChanges = true})
    : _persistChanges = persistChanges;

  /// Creates a new instance for testing (avoids singleton state leaks between tests)
  factory SystemModeManager.forTest() = _TestSystemModeManager;

  final bool _persistChanges;
  SystemMode _currentMode = SystemMode.operating;

  SystemMode get currentMode => _currentMode;

  void setMode(SystemMode mode) {
    _setModeInMemory(mode, notify: true);

    if (_persistChanges && !kIsWeb) {
      unawaited(_persistMode(mode));
    }
  }

  /// Loads the persisted mode from storage.
  ///
  /// Background SMS processing calls this before handling a message because
  /// Android may execute that callback in a separate Dart isolate.
  Future<void> loadPersistedMode({bool notify = true}) async {
    if (!_persistChanges || kIsWeb) return;

    try {
      final savedMode = await DatabaseHelper.instance.getSetting(
        _modeSettingKey,
      );
      final mode = _parseMode(savedMode);
      _setModeInMemory(mode, notify: notify);
    } catch (e) {
      debugPrint('Failed to load system mode: $e');
    }
  }

  bool canAcceptDelivery() {
    switch (_currentMode) {
      case SystemMode.operating:
        return true;
      case SystemMode.staffAway:
      case SystemMode.full:
      case SystemMode.maintenance:
        return false;
    }
  }

  bool canAcceptDrop() {
    switch (_currentMode) {
      case SystemMode.operating:
      case SystemMode.staffAway:
      case SystemMode.full:
        return true;
      case SystemMode.maintenance:
        return false;
    }
  }

  String getDeliveryReply() {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Order Confirmed. Delivery is being prepared.';
      case SystemMode.staffAway:
        return 'Order Received. Staff is currently out delivering. '
            'We will process this upon return.';
      case SystemMode.full:
        return 'We are fully booked for today. Please order for the next schedule.';
      case SystemMode.maintenance:
        return 'System under maintenance. We are currently closed.';
    }
  }

  String getDropReply() {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Order received, staff will assist.';
      case SystemMode.staffAway:
        return 'Order received. Please leave bottles in the designated area. '
            'We will process upon return.';
      case SystemMode.full:
        return 'Order received. Please wait for confirmation.';
      case SystemMode.maintenance:
        return 'System under maintenance. We are currently closed.';
    }
  }

  void _setModeInMemory(SystemMode mode, {required bool notify}) {
    if (_currentMode == mode) return;

    _currentMode = mode;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _persistMode(SystemMode mode) async {
    try {
      await DatabaseHelper.instance.setSetting(_modeSettingKey, mode.name);
    } catch (e) {
      debugPrint('Failed to persist system mode: $e');
    }
  }

  SystemMode _parseMode(String? savedMode) {
    if (savedMode == null) return SystemMode.operating;

    return SystemMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => SystemMode.operating,
    );
  }
}

/// Test-only subclass that bypasses the private constructor
class _TestSystemModeManager extends SystemModeManager {
  _TestSystemModeManager() : super._(persistChanges: false);
}
