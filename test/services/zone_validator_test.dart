// Task 009 — Unit tests for ZoneValidator (Zone A/B/C + unregistered)
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/zone_validator.dart';
import 'package:jj_clover_sms/data/models/customer_model.dart';
import 'package:jj_clover_sms/data/models/schedule_model.dart';

void main() {
  // --- Test data: customers from different zones ---

  // Zone A customer — San Isidro, station vicinity
  final zoneACustomer = Customer(
    id: 1,
    name: 'Maria Santos',
    contactNumber: '09171000001',
    address: 'Purok 1, near barangay hall',
    barangay: 'San Isidro',
    deliveryZone: 'Zone A',
  );

  // Zone B customer — Poblacion, near barangay
  final zoneBCustomer = Customer(
    id: 6,
    name: 'Carlos Ramos',
    contactNumber: '09171000006',
    address: 'Purok 4, near public market',
    barangay: 'Poblacion',
    deliveryZone: 'Zone B',
  );

  // Zone C customer — Santo Niño, far/mountain
  final zoneCCustomer = Customer(
    id: 11,
    name: 'Teresa Villanueva',
    contactNumber: '09171000011',
    address: 'Sitio Upper, near water tank',
    barangay: 'Santo Niño',
    deliveryZone: 'Zone C',
  );

  // --- Test data: schedules ---

  // Zone A schedules — Mon through Sat (6 records)
  final zoneASchedules = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ]
      .map((day) => Schedule(
            id: null,
            customerId: 1,
            deliveryDay: day,
            status: 'active',
          ))
      .toList();

  // Zone B schedules — Mon/Wed/Fri (3 records)
  final zoneBSchedules = ['Monday', 'Wednesday', 'Friday']
      .map((day) => Schedule(
            id: null,
            customerId: 6,
            deliveryDay: day,
            status: 'active',
          ))
      .toList();

  // Zone C schedules — Tuesday only (Santo Niño)
  final zoneCSchedules = [
    Schedule(
      id: null,
      customerId: 11,
      deliveryDay: 'Tuesday',
      status: 'active',
    ),
  ];

  group('ZoneValidator — checkCustomer()', () {
    test('returns valid for registered customer', () {
      final result = ZoneValidator.checkCustomer(customer: zoneACustomer);
      expect(result.result, ValidationResult.valid);
      expect(result.customer, isNotNull);
    });

    test('returns unregistered for null customer', () {
      final result = ZoneValidator.checkCustomer(customer: null);
      expect(result.result, ValidationResult.unregistered);
      expect(result.message, contains('Unknown number'));
    });
  });

  group('ZoneValidator — Zone A (station vicinity)', () {
    test('valid on Monday (operating day)', () {
      final result = ZoneValidator.validate(
        customer: zoneACustomer,
        schedules: zoneASchedules,
        currentDay: 'Monday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('valid on Saturday (last operating day)', () {
      final result = ZoneValidator.validate(
        customer: zoneACustomer,
        schedules: zoneASchedules,
        currentDay: 'Saturday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('invalid on Sunday (no Zone A schedule)', () {
      final result = ZoneValidator.validate(
        customer: zoneACustomer,
        schedules: zoneASchedules,
        currentDay: 'Sunday',
      );
      expect(result.result, ValidationResult.invalidDay);
      expect(result.correctDay, 'Monday');
    });
  });

  group('ZoneValidator — Zone B (near barangays)', () {
    test('valid on Monday (scheduled day)', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Monday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('valid on Wednesday (scheduled day)', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Wednesday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('valid on Friday (scheduled day)', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Friday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('invalid on Tuesday (not scheduled)', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Tuesday',
      );
      expect(result.result, ValidationResult.invalidDay);
      // Next scheduled day after Tuesday is Wednesday
      expect(result.correctDay, 'Wednesday');
    });

    test('invalid on Thursday (not scheduled)', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Thursday',
      );
      expect(result.result, ValidationResult.invalidDay);
      // Next scheduled day after Thursday is Friday
      expect(result.correctDay, 'Friday');
    });

    test('invalid on Saturday — wraps to Monday', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Saturday',
      );
      expect(result.result, ValidationResult.invalidDay);
      // Next scheduled day after Saturday wraps to Monday
      expect(result.correctDay, 'Monday');
    });

    test('reply message includes pre-book offer', () {
      final result = ZoneValidator.validate(
        customer: zoneBCustomer,
        schedules: zoneBSchedules,
        currentDay: 'Tuesday',
      );
      expect(result.message, contains('pre-book'));
      expect(result.message, contains('YES'));
    });
  });

  group('ZoneValidator — Zone C (far/mountain)', () {
    test('valid on Tuesday (Santo Niño delivery day)', () {
      final result = ZoneValidator.validate(
        customer: zoneCCustomer,
        schedules: zoneCSchedules,
        currentDay: 'Tuesday',
      );
      expect(result.result, ValidationResult.valid);
    });

    test('invalid on Monday (not scheduled)', () {
      final result = ZoneValidator.validate(
        customer: zoneCCustomer,
        schedules: zoneCSchedules,
        currentDay: 'Monday',
      );
      expect(result.result, ValidationResult.invalidDay);
      // Next scheduled day after Monday is Tuesday
      expect(result.correctDay, 'Tuesday');
    });

    test('invalid on Wednesday — wraps to next Tuesday', () {
      final result = ZoneValidator.validate(
        customer: zoneCCustomer,
        schedules: zoneCSchedules,
        currentDay: 'Wednesday',
      );
      expect(result.result, ValidationResult.invalidDay);
      // Next Tuesday is 6 days away from Wednesday
      expect(result.correctDay, 'Tuesday');
    });
  });

  group('ZoneValidator — Edge cases', () {
    test('returns invalidDay when customer has no schedules', () {
      final result = ZoneValidator.validate(
        customer: zoneACustomer,
        schedules: [], // Empty schedule list
        currentDay: 'Monday',
      );
      expect(result.result, ValidationResult.invalidDay);
      expect(result.message, contains('No schedule found'));
    });

    test('handles schedules for different customers (filters correctly)', () {
      // Pass Zone B schedules (customerId: 6) but validate Zone A customer (id: 1)
      final result = ZoneValidator.validate(
        customer: zoneACustomer,
        schedules: zoneBSchedules, // These belong to customer 6, not 1
        currentDay: 'Monday',
      );
      // Should filter out all schedules since none match customer id 1
      expect(result.result, ValidationResult.invalidDay);
    });
  });
}
