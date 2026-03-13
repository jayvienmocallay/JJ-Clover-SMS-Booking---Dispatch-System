// Task 001 — App configuration constants derived from scope & zone mapping interview
class AppConstants {
  static const String appName = 'JJ Clover';
  static const String dbName = 'clover_secure.db';
  static const String dbKeyName = 'db_encryption_key';

  // Task 007 — Order cutoff time from FR-4.1 in SRS (default: 7:00 AM)
  static const int orderCutOffHour = 7;
  static const int orderCutOffMinute = 0;
}

// Task 008 — System modes from SRS Section 2.2 (Status Toggles)
enum SystemMode { operating, staffAway, full, maintenance }

// Task 008 — Display names and auto-reply messages per system mode
extension SystemModeExtension on SystemMode {
  String get displayName {
    switch (this) {
      case SystemMode.operating:
        return 'OPERATING';
      case SystemMode.staffAway:
        return 'STAFF AWAY';
      case SystemMode.full:
        return 'FULL / BUSY';
      case SystemMode.maintenance:
        return 'MAINTENANCE';
    }
  }

  String get autoReply {
    switch (this) {
      case SystemMode.operating:
        return 'Order Confirmed. Delivery is being prepared.';
      case SystemMode.staffAway:
        return 'Order Received. Staff is currently out delivering. We will process this upon return.';
      case SystemMode.full:
        return 'We are fully booked for today. Please order for the next schedule.';
      case SystemMode.maintenance:
        return 'System under maintenance. We are currently closed.';
    }
  }
}

// Task 001 — Delivery day reference list used by zone validator and schedule seeding
class DeliveryDays {
  /// All days of the week (index 0 = Monday, matches DateTime.weekday - 1)
  static const List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Returns the name of the current day (e.g., 'Monday')
  static String getToday() {
    final now = DateTime.now();
    // DateTime.weekday: 1=Monday, so subtract 1 to match our list index
    return days[now.weekday - 1];
  }
}

// Task 001, Task 006 — Zone-to-day mapping from Scope & Zone Mapping document
/// Maps each delivery zone to its allowed delivery days.
///
/// Based on the Scope & Zone Mapping document (Jan 24, 2026 interview):
/// - Zone A (Station Vicinity): Available every operating day (Mon–Sat)
/// - Zone B (Near Barangays): Pedicab delivery on scheduled days (Mon/Wed/Fri)
/// - Zone C (Far/Mountain): Weekly schedule — one assigned day per week
class ZoneScheduleMap {
  /// Zone A — station vicinity, customers can order any operating day
  static const List<String> zoneADays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// Zone B — near barangays, pedicab delivery on alternating weekdays
  static const List<String> zoneBDays = [
    'Monday',
    'Wednesday',
    'Friday',
  ];

  /// Zone C — far/mountain barangays, each gets one specific day per week.
  /// This map assigns a delivery day to each Zone C barangay by name.
  static const Map<String, String> zoneCBarangayDays = {
    'Santo Niño': 'Tuesday',   // barangay_id: 5
    'Semong': 'Tuesday',       // barangay_id: 6
    'Gabuyan': 'Thursday',     // barangay_id: 7
    'Bunawan': 'Thursday',     // barangay_id: 8
    'Katipunan': 'Saturday',   // barangay_id: 9
    'Dagohoy': 'Saturday',     // barangay_id: 10
    'Tiburcia': 'Saturday',    // barangay_id: 11
    'Clementa': 'Saturday',    // barangay_id: 12
  };

  /// Returns the list of allowed delivery days for a given zone and barangay.
  ///
  /// [zone] — the delivery zone string (e.g., 'Zone A')
  /// [barangayName] — the barangay name, required for Zone C lookup
  static List<String> getDaysForZone(String zone, {String? barangayName}) {
    switch (zone) {
      case 'Zone A':
        // Zone A customers can order any day Mon–Sat
        return zoneADays;
      case 'Zone B':
        // Zone B customers are served Mon/Wed/Fri
        return zoneBDays;
      case 'Zone C':
        // Zone C customers have one specific day based on their barangay
        if (barangayName != null && zoneCBarangayDays.containsKey(barangayName)) {
          return [zoneCBarangayDays[barangayName]!];
        }
        // Fallback: return empty if barangay not found in the map
        return [];
      default:
        // Unknown zone — no delivery days assigned
        return [];
    }
  }
}
