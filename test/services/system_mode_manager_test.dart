// Task 009 — Unit tests for SystemModeManager (all 4 modes)
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/system_mode_manager.dart';
import 'package:jj_clover_sms/core/constants/app_constants.dart';

void main() {
  late SystemModeManager manager;

  setUp(() {
    // Create a fresh manager for each test to avoid state leaking
    manager = SystemModeManager.forTest();
  });

  group('SystemModeManager — Initial state', () {
    test('starts in OPERATING mode by default', () {
      expect(manager.currentMode, SystemMode.operating);
    });
  });

  group('SystemModeManager — setMode()', () {
    test('switches to STAFF AWAY mode', () {
      manager.setMode(SystemMode.staffAway);
      expect(manager.currentMode, SystemMode.staffAway);
    });

    test('switches to FULL mode', () {
      manager.setMode(SystemMode.full);
      expect(manager.currentMode, SystemMode.full);
    });

    test('switches to MAINTENANCE mode', () {
      manager.setMode(SystemMode.maintenance);
      expect(manager.currentMode, SystemMode.maintenance);
    });

    test('switches back to OPERATING mode', () {
      manager.setMode(SystemMode.maintenance);
      manager.setMode(SystemMode.operating);
      expect(manager.currentMode, SystemMode.operating);
    });

    test('notifies listeners on mode change', () {
      // Track how many times the listener is called
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.setMode(SystemMode.staffAway);
      expect(notifyCount, 1);

      manager.setMode(SystemMode.full);
      expect(notifyCount, 2);
    });
  });

  group('SystemModeManager — canAcceptDelivery()', () {
    test('accepts delivery in OPERATING mode', () {
      manager.setMode(SystemMode.operating);
      expect(manager.canAcceptDelivery(), true);
    });

    test('rejects delivery in STAFF AWAY mode', () {
      manager.setMode(SystemMode.staffAway);
      expect(manager.canAcceptDelivery(), false);
    });

    test('rejects delivery in FULL mode', () {
      manager.setMode(SystemMode.full);
      expect(manager.canAcceptDelivery(), false);
    });

    test('rejects delivery in MAINTENANCE mode', () {
      manager.setMode(SystemMode.maintenance);
      expect(manager.canAcceptDelivery(), false);
    });
  });

  group('SystemModeManager — canAcceptDrop()', () {
    test('accepts drop in OPERATING mode', () {
      manager.setMode(SystemMode.operating);
      expect(manager.canAcceptDrop(), true);
    });

    test('accepts drop in STAFF AWAY mode', () {
      manager.setMode(SystemMode.staffAway);
      expect(manager.canAcceptDrop(), true);
    });

    test('accepts drop in FULL mode', () {
      manager.setMode(SystemMode.full);
      expect(manager.canAcceptDrop(), true);
    });

    test('rejects drop in MAINTENANCE mode', () {
      manager.setMode(SystemMode.maintenance);
      expect(manager.canAcceptDrop(), false);
    });
  });

  group('SystemModeManager — getDeliveryReply()', () {
    test('OPERATING reply confirms order', () {
      manager.setMode(SystemMode.operating);
      expect(manager.getDeliveryReply(), contains('Confirmed'));
    });

    test('STAFF AWAY reply mentions staff out', () {
      manager.setMode(SystemMode.staffAway);
      expect(manager.getDeliveryReply(), contains('Staff'));
    });

    test('FULL reply says fully booked', () {
      manager.setMode(SystemMode.full);
      expect(manager.getDeliveryReply(), contains('fully booked'));
    });

    test('MAINTENANCE reply says closed', () {
      manager.setMode(SystemMode.maintenance);
      expect(manager.getDeliveryReply(), contains('closed'));
    });
  });

  group('SystemModeManager — getDropReply()', () {
    test('OPERATING reply mentions staff assist', () {
      manager.setMode(SystemMode.operating);
      expect(manager.getDropReply(), contains('staff will assist'));
    });

    test('STAFF AWAY reply mentions leave bottles', () {
      manager.setMode(SystemMode.staffAway);
      expect(manager.getDropReply(), contains('leave bottles'));
    });

    test('FULL reply asks to wait', () {
      manager.setMode(SystemMode.full);
      expect(manager.getDropReply(), contains('wait'));
    });

    test('MAINTENANCE reply says closed', () {
      manager.setMode(SystemMode.maintenance);
      expect(manager.getDropReply(), contains('closed'));
    });
  });

  group('SystemMode extension — displayName', () {
    test('OPERATING display name', () {
      expect(SystemMode.operating.displayName, 'OPERATING');
    });

    test('STAFF AWAY display name', () {
      expect(SystemMode.staffAway.displayName, 'STAFF AWAY');
    });

    test('FULL display name', () {
      expect(SystemMode.full.displayName, 'FULL / BUSY');
    });

    test('MAINTENANCE display name', () {
      expect(SystemMode.maintenance.displayName, 'MAINTENANCE');
    });
  });

  group('SystemMode extension — autoReply', () {
    test('each mode has a non-empty auto-reply', () {
      for (final mode in SystemMode.values) {
        expect(mode.autoReply.isNotEmpty, true,
            reason: '${mode.name} should have a non-empty autoReply');
      }
    });
  });
}
