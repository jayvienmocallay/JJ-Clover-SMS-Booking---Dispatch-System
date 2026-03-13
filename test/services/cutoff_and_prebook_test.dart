// Task 009 — Unit tests for cutoff time logic (before/after 7 AM)
// Task 009 — Unit tests for pre-book flow (YES with/without context)
//
// NOTE: The cutoff and pre-book logic lives inside SmsBackgroundService
// (private methods). These tests verify the supporting constants, models,
// and validators that the service depends on. Full end-to-end testing
// of the private methods requires integration tests (Task 013).
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/constants/app_constants.dart';
import 'package:jj_clover_sms/data/models/order_model.dart';
import 'package:jj_clover_sms/data/models/schedule_model.dart';

void main() {
  group('Cutoff time constants', () {
    // Task 009 — Verify the cutoff time is set correctly per FR-4.1 in SRS
    test('order cutoff hour is 7 AM', () {
      expect(AppConstants.orderCutOffHour, 7);
    });

    test('order cutoff minute is 0 (exact hour)', () {
      expect(AppConstants.orderCutOffMinute, 0);
    });
  });

  group('Cutoff time logic simulation', () {
    // These tests simulate the before/after cutoff decision
    // that SmsBackgroundService._handleDeliver performs

    test('6:59 AM is before cutoff → confirmed for today', () {
      final testTime = DateTime(2026, 3, 8, 6, 59); // 6:59 AM
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, true);
    });

    test('7:00 AM is NOT before cutoff → queued for next day', () {
      final testTime = DateTime(2026, 3, 8, 7, 0); // 7:00 AM exactly
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, false);
    });

    test('7:01 AM is NOT before cutoff → queued for next day', () {
      final testTime = DateTime(2026, 3, 8, 7, 1); // 7:01 AM
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, false);
    });

    test('12:00 PM (noon) is NOT before cutoff', () {
      final testTime = DateTime(2026, 3, 8, 12, 0);
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, false);
    });

    test('5:30 AM is before cutoff', () {
      final testTime = DateTime(2026, 3, 8, 5, 30);
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, true);
    });

    test('midnight (0:00) is before cutoff', () {
      final testTime = DateTime(2026, 3, 8, 0, 0);
      final isBeforeCutoff =
          testTime.hour < AppConstants.orderCutOffHour ||
          (testTime.hour == AppConstants.orderCutOffHour &&
              testTime.minute < AppConstants.orderCutOffMinute);
      expect(isBeforeCutoff, true);
    });
  });

  group('Next available day calculation', () {
    // Simulates _findNextAvailableDay logic from SmsBackgroundService
    // This is a local reimplementation for test purposes since the
    // original method is private

    String findNextAvailableDay(List<Schedule> schedules, String currentDay) {
      final allowedDays = schedules.map((s) => s.deliveryDay).toSet();
      final todayIndex = DeliveryDays.days.indexOf(currentDay);

      for (int offset = 1; offset <= 7; offset++) {
        final checkIndex = (todayIndex + offset) % 7;
        final checkDay = DeliveryDays.days[checkIndex];
        if (allowedDays.contains(checkDay)) {
          return checkDay;
        }
      }
      return currentDay;
    }

    test('Zone B: after Friday cutoff → next is Monday', () {
      final schedules = ['Monday', 'Wednesday', 'Friday']
          .map((d) => Schedule(customerId: 6, deliveryDay: d, status: 'active'))
          .toList();
      expect(findNextAvailableDay(schedules, 'Friday'), 'Monday');
    });

    test('Zone B: after Monday cutoff → next is Wednesday', () {
      final schedules = ['Monday', 'Wednesday', 'Friday']
          .map((d) => Schedule(customerId: 6, deliveryDay: d, status: 'active'))
          .toList();
      expect(findNextAvailableDay(schedules, 'Monday'), 'Wednesday');
    });

    test('Zone C: after Tuesday cutoff → next is Tuesday (weekly)', () {
      final schedules = [
        Schedule(customerId: 11, deliveryDay: 'Tuesday', status: 'active'),
      ];
      expect(findNextAvailableDay(schedules, 'Tuesday'), 'Tuesday');
    });

    test('Zone A: after Saturday cutoff → next is Monday', () {
      final schedules = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      ].map((d) => Schedule(customerId: 1, deliveryDay: d, status: 'active'))
          .toList();
      expect(findNextAvailableDay(schedules, 'Saturday'), 'Monday');
    });
  });

  group('Pre-book order model', () {
    // Task 009 — Verify that pre-booked orders are modeled correctly

    test('pre-book order has isPreBook = true', () {
      final order = Order(
        customerId: 11,
        phoneNumber: '09171000011',
        type: OrderType.deliver,
        quantity: 3,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        deliveryDay: 'Tuesday',
        isPreBook: true,
      );
      expect(order.isPreBook, true);
      expect(order.deliveryDay, 'Tuesday');
      expect(order.status, OrderStatus.pending);
    });

    test('pre-book order serializes isPreBook as 1', () {
      final order = Order(
        customerId: 11,
        phoneNumber: '09171000011',
        type: OrderType.deliver,
        quantity: 3,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        deliveryDay: 'Tuesday',
        isPreBook: true,
      );
      final map = order.toMap();
      expect(map['is_pre_book'], 1);
    });

    test('non-pre-book order serializes isPreBook as 0', () {
      final order = Order(
        customerId: 1,
        phoneNumber: '09171000001',
        type: OrderType.deliver,
        quantity: 5,
        status: OrderStatus.confirmed,
        createdAt: DateTime.now(),
        deliveryDay: 'Monday',
        isPreBook: false,
      );
      final map = order.toMap();
      expect(map['is_pre_book'], 0);
    });

    test('Order.fromMap deserializes isPreBook from integer', () {
      final map = {
        'id': 1,
        'customer_id': 11,
        'phone_number': '09171000011',
        'type': 'deliver',
        'quantity': 3,
        'gallon_type': null,
        'address': null,
        'status': 'pending',
        'created_at': '2026-03-08T06:30:00.000',
        'delivery_day': 'Tuesday',
        'is_pre_book': 1,
        'staff_id': null,
      };
      final order = Order.fromMap(map);
      expect(order.isPreBook, true);
    });

    test('pre-book order preserves gallon type', () {
      final order = Order(
        customerId: 11,
        phoneNumber: '09171000011',
        type: OrderType.deliver,
        quantity: 3,
        gallonType: GallonType.newGallon,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        deliveryDay: 'Tuesday',
        isPreBook: true,
      );
      expect(order.gallonType, GallonType.newGallon);
      final map = order.toMap();
      expect(map['gallon_type'], 'new');
    });
  });

  group('DeliveryDays utility', () {
    test('has exactly 7 days', () {
      expect(DeliveryDays.days.length, 7);
    });

    test('starts with Monday (index 0)', () {
      expect(DeliveryDays.days[0], 'Monday');
    });

    test('ends with Sunday (index 6)', () {
      expect(DeliveryDays.days[6], 'Sunday');
    });

    test('getToday returns a valid day name', () {
      final today = DeliveryDays.getToday();
      expect(DeliveryDays.days.contains(today), true);
    });
  });
}
