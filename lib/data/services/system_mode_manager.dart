// Task 008 — System Mode Manager: 4-mode toggle with ChangeNotifier (Provider-ready)
// Task 013 — Singleton pattern so UI toggles and background service share the same mode
// Task 014 — Persist mode so background SMS isolates read the same state as UI
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../repositories/settings_repository.dart';

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
  final _settings = SettingsRepository();
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
      final savedMode = await _settings.getSetting(_modeSettingKey);
      final mode = _parseMode(savedMode);
      _setModeInMemory(mode, notify: notify);
    } catch (e) {
      debugPrint('Failed to load system mode: $e');
    }
  }

  bool canAcceptDelivery() {
    switch (_currentMode) {
      case SystemMode.operating:
      case SystemMode.staffAway:
        return true;
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

  String getDeliveryReply({String? queuedDeliveryDay}) {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Nakumpirma ang order. Giandam na ang delivery.';
      case SystemMode.staffAway:
        const reply =
            'Nadawat ang order. Ang staff naa pa sa delivery. '
            'Iproseso namo pagbalik.';
        if (queuedDeliveryDay == null || queuedDeliveryDay.isEmpty) {
          return reply;
        }
        return '$reply Gi-queue ang imong order para sa $queuedDeliveryDay.';
      case SystemMode.full:
        return 'Puno na ang schedule karon. Palihug mo-order sa sunod nga iskedyul.';
      case SystemMode.maintenance:
        return 'Naay maintenance ang sistema. Sirado mi karon.';
    }
  }

  String getDropReply() {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Nadawat ang order, Palihug hulat sa staff nga mo assist.';
      case SystemMode.staffAway:
        return 'Nadawat ang order. Palihug ibutang ang mga botelya sa gitudlo nga lugar. '
            'Iproseso namo pagbalik.';
      case SystemMode.full:
        return 'Nadawat ang order. Palihug hulat sa kumpirmasyon.';
      case SystemMode.maintenance:
        return 'Naay maintenance ang sistema. Sirado mi karon.';
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
      await _settings.setSetting(_modeSettingKey, mode.name);
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
