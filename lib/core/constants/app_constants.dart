class AppConstants {
  static const String appName = 'JJ Clover';
  static const String dbName = 'clover_secure.db';
  static const String dbKeyName = 'db_encryption_key';

  static const int orderCutOffHour = 7;
  static const int orderCutOffMinute = 0;
}

enum SystemMode { operating, staffAway, full, maintenance }

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

class DeliveryDays {
  static const List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String getToday() {
    final now = DateTime.now();
    return days[now.weekday - 1];
  }
}
