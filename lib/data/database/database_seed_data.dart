part of 'database_helper.dart';

Future<void> seedBarangays(Database db) async {
  final defaultBarangays = [
    {'name': 'San Isidro', 'delivery_zone': 'Zone A'},
    {'name': 'San Jose', 'delivery_zone': 'Zone A'},
    {'name': 'Poblacion', 'delivery_zone': 'Zone B'},
    {'name': 'Santa Rosa', 'delivery_zone': 'Zone B'},
    {
      'name': 'Santo NiÃ±o',
      'delivery_zone': 'Zone C',
      'delivery_day': 'Tuesday',
    },
    {'name': 'Semong', 'delivery_zone': 'Zone C', 'delivery_day': 'Tuesday'},
    {'name': 'Gabuyan', 'delivery_zone': 'Zone C', 'delivery_day': 'Thursday'},
    {'name': 'Bunawan', 'delivery_zone': 'Zone C', 'delivery_day': 'Thursday'},
    {
      'name': 'Katipunan',
      'delivery_zone': 'Zone C',
      'delivery_day': 'Saturday',
    },
    {'name': 'Dagohoy', 'delivery_zone': 'Zone C', 'delivery_day': 'Saturday'},
    {'name': 'Tiburcia', 'delivery_zone': 'Zone C', 'delivery_day': 'Saturday'},
    {'name': 'Clementa', 'delivery_zone': 'Zone C', 'delivery_day': 'Saturday'},
  ];

  for (final barangay in defaultBarangays) {
    await db.insert('barangays', barangay);
  }
}

// Task 006 â€” Pre-populate customers (no longer seeded with sample data)
// Customers are now added via the app UI
Future<void> seedCustomers(Database db) async {
  // No sample data - customers added via app
}

/// Seeds the schedules table by assigning delivery days to each customer
/// based on their barangay's zone.
///
/// Zone-to-day mapping is defined in [ZoneScheduleMap]:
/// - Zone A (station vicinity): Monâ€“Sat (every operating day)
/// - Zone B (near barangays): Mon/Wed/Fri (pedicab schedule)
/// - Zone C (far/mountain): One specific day per barangay (weekly)
///
/// Each customer gets one schedule record per allowed delivery day,
/// all with 'active' status by default.
Future<void> seedSchedules(Database db) async {
  // Step 1: Query all customers joined with their barangay info.
  // We need the zone, barangay name, and delivery_day to determine delivery days.
  final customers = await db.rawQuery('''
    SELECT c.id AS customer_id, b.name AS barangay_name,
           b.delivery_zone, b.delivery_day AS barangay_delivery_day
    FROM customers c
    INNER JOIN barangays b ON c.barangay_id = b.id
  ''');

  // Step 2: For each customer, look up their allowed delivery days
  // using the ZoneScheduleMap (or the barangay's delivery_day for Zone C)
  // and insert a schedule record per day.
  for (final customer in customers) {
    // Extract the customer's zone (e.g., 'Zone A') and barangay name
    final zone = customer['delivery_zone'] as String;
    final barangayName = customer['barangay_name'] as String;
    final customerId = customer['customer_id'] as int;
    final barangayDeliveryDay = customer['barangay_delivery_day'] as String?;

    // For Zone C, prefer the DB-stored delivery_day so dynamically added
    // barangays (not in the hardcoded map) also get schedules.
    List<String> deliveryDays;
    if (zone == 'Zone C' && barangayDeliveryDay != null) {
      deliveryDays = barangayDeliveryDay
          .split(',')
          .map((d) => d.trim())
          .toList();
    } else {
      deliveryDays = ZoneScheduleMap.getDaysForZone(
        zone,
        barangayName: barangayName,
      );
    }

    // Insert one schedule record per allowed delivery day
    for (final day in deliveryDays) {
      await db.insert('schedules', {
        'customer_id': customerId,
        'delivery_day': day,
        'status': 'active',
      });
    }
  }
}

// Task 003 â€” Barangay CRUD operations
