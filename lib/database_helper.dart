// Task 005 — Data Layer: SQLCipher encrypted database with full CRUD operations
// Task 006 — Data seeding: barangays, customers, and schedules
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/constants/app_constants.dart';

// Task 005 — Singleton DatabaseHelper for encrypted SQLCipher access
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clover_secure.db');
    return _database!;
  }

  // Retrieve or generate the database password securely
  Future<String> _getSecurePassword() async {
    const key = 'db_encryption_key';
    String? password = await _secureStorage.read(key: key);

    if (password == null) {
      // Generate a new secure password on first install
      password = '${DateTime.now().millisecondsSinceEpoch}random_secure_salt';
      await _secureStorage.write(key: key, value: password);
    }
    return password;
  }

  Future<Database> _initDB(String filePath) async {
    final dbDirectory = await getApplicationDocumentsDirectory();
    final path = '${dbDirectory.path}${Platform.pathSeparator}$filePath';

    final password = await _getSecurePassword();

    return await openDatabase(
      path,
      password: password,
      // Version 2: Added address to customers, gallon_type/staff_id to orders,
      // and created delivery_logs table
      version: 2,
      onCreate: _createSchema,
      // Handles upgrading existing v1 databases to v2 schema
      onUpgrade: _upgradeSchema,
    );
  }

  // Task 005 — Create all tables (schema v2)
  Future _createSchema(Database db, int version) async {
    // Task 001 — 1. Barangays Lookup Table (zone mapping from interview)
    await db.execute('''
      CREATE TABLE barangays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        delivery_zone TEXT NOT NULL
      )
    ''');

    // Task 005 — 2. Customers Table (references barangays)
    // Stores registered customer profiles per FR-1.2 in SRS:
    // Phone Number, Name, Full Address, and Barangay (Zone)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        address TEXT,
        barangay_id INTEGER NOT NULL,
        FOREIGN KEY (barangay_id) REFERENCES barangays (id)
      )
    ''');

    // Task 005, Task 006 — 3. Schedules Table (zone-day mapping per customer)
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        delivery_day TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Task 003, Task 005 — 4. Orders Table (core order tracking)
    // Tracks all orders with gallon classification and staff assignment
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        phone_number TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        gallon_type TEXT,
        address TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        delivery_day TEXT,
        is_pre_book INTEGER DEFAULT 0,
        staff_id INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // Task 005 — 5. Delivery Logs Table (per-household accountability)
    // Records per-household delivery details for accountability and loss tracking.
    // Each log entry ties a delivery to an order, customer, and staff member.
    await db.execute('''
      CREATE TABLE delivery_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        staff_id INTEGER,
        quantity_delivered INTEGER NOT NULL,
        gallon_type TEXT,
        notes TEXT,
        delivered_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Task 006 — Seed default data in order: barangays first, then customers, then schedules.
    // Order matters because of foreign key dependencies:
    // schedules -> customers -> barangays
    await _seedBarangays(db);
    await _seedCustomers(db);
    await _seedSchedules(db);
  }

  // Task 005 — Database migration: v1 → v2 schema upgrade
  /// Handles upgrading the database schema from an older version to the current one.
  ///
  /// v1 → v2 changes:
  /// - Added `address` column to customers (FR-1.2: full address)
  /// - Added `gallon_type` column to orders (gallon classification: new/old)
  /// - Added `staff_id` column to orders (staff assignment & accountability)
  /// - Created `delivery_logs` table (per-household delivery tracking)
  /// - Seeded schedules if missing from v1
  Future _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    // Migrate from version 1 to version 2
    if (oldVersion < 2) {
      // Add address column to customers table for full delivery address
      await db.execute('ALTER TABLE customers ADD COLUMN address TEXT');

      // Add gallon classification column: 'new' (household) or 'old' (store)
      await db.execute('ALTER TABLE orders ADD COLUMN gallon_type TEXT');

      // Add staff assignment column for delivery accountability
      await db.execute('ALTER TABLE orders ADD COLUMN staff_id INTEGER');

      // Create the delivery_logs table for per-household tracking
      await db.execute('''
        CREATE TABLE delivery_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          customer_id INTEGER NOT NULL,
          staff_id INTEGER,
          quantity_delivered INTEGER NOT NULL,
          gallon_type TEXT,
          notes TEXT,
          delivered_at TEXT NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');

      // Seed schedules if they were missing in v1 (the critical gap)
      final existingSchedules = await db.query('schedules', limit: 1);
      if (existingSchedules.isEmpty) {
        await _seedSchedules(db);
      }
    }
  }

  // Task 006 — Pre-populate barangays with default data
  Future<void> _seedBarangays(Database db) async {
    final defaultBarangays = [
      {'name': 'San Isidro', 'delivery_zone': 'Zone A'},
      {'name': 'San Jose', 'delivery_zone': 'Zone A'},
      {'name': 'Poblacion', 'delivery_zone': 'Zone B'},
      {'name': 'Santa Rosa', 'delivery_zone': 'Zone B'},
      {'name': 'Santo Niño', 'delivery_zone': 'Zone C'},
      {'name': 'Semong', 'delivery_zone': 'Zone C'},
      {'name': 'Gabuyan', 'delivery_zone': 'Zone C'},
      {'name': 'Bunawan', 'delivery_zone': 'Zone C'},
      {'name': 'Katipunan', 'delivery_zone': 'Zone C'},
      {'name': 'Dagohoy', 'delivery_zone': 'Zone C'},
      {'name': 'Tiburcia', 'delivery_zone': 'Zone C'},
      {'name': 'Clementa', 'delivery_zone': 'Zone C'},
    ];

    for (final barangay in defaultBarangays) {
      await db.insert('barangays', barangay);
    }
  }

  // Task 006 — Pre-populate customers with synthetic data
  Future<void> _seedCustomers(Database db) async {
    final defaultCustomers = [
      // Zone A — San Isidro (barangay_id: 1)
      // Station vicinity — customers can walk in or request same-day delivery
      {
        'name': 'Maria Santos',
        'contact_number': '09171000001',
        'address': 'Purok 1, near barangay hall',
        'barangay_id': 1,
      },
      {
        'name': 'Juan dela Cruz',
        'contact_number': '09171000002',
        'address': 'Purok 2, beside sari-sari store',
        'barangay_id': 1,
      },
      {
        'name': 'Rosa Reyes',
        'contact_number': '09171000003',
        'address': 'Purok 3, corner house',
        'barangay_id': 1,
      },
      // Zone A — San Jose (barangay_id: 2)
      {
        'name': 'Pedro Garcia',
        'contact_number': '09171000004',
        'address': 'Purok 1, near chapel',
        'barangay_id': 2,
      },
      {
        'name': 'Ana Mendoza',
        'contact_number': '09171000005',
        'address': 'Purok 2, along main road',
        'barangay_id': 2,
      },
      // Zone B — Poblacion (barangay_id: 3)
      // Near barangays — pedicab delivery on scheduled days
      {
        'name': 'Carlos Ramos',
        'contact_number': '09171000006',
        'address': 'Purok 4, near public market',
        'barangay_id': 3,
      },
      {
        'name': 'Elena Torres',
        'contact_number': '09171000007',
        'address': 'Purok 5, beside health center',
        'barangay_id': 3,
      },
      {
        'name': 'Roberto Cruz',
        'contact_number': '09171000008',
        'address': 'Purok 6, along national highway',
        'barangay_id': 3,
      },
      // Zone B — Santa Rosa (barangay_id: 4)
      {
        'name': 'Liza Navarro',
        'contact_number': '09171000009',
        'address': 'Purok 1, near elementary school',
        'barangay_id': 4,
      },
      {
        'name': 'Miguel Aquino',
        'contact_number': '09171000010',
        'address': 'Purok 2, end of paved road',
        'barangay_id': 4,
      },
      // Zone C — Santo Niño (barangay_id: 5)
      // Far/mountain barangays — weekly delivery schedule
      {
        'name': 'Teresa Villanueva',
        'contact_number': '09171000011',
        'address': 'Sitio Upper, near water tank',
        'barangay_id': 5,
      },
      {
        'name': 'Ramon Bautista',
        'contact_number': '09171000012',
        'address': 'Sitio Lower, along creek',
        'barangay_id': 5,
      },
      // Zone C — Semong (barangay_id: 6)
      {
        'name': 'Gloria Pascual',
        'contact_number': '09171000013',
        'address': 'Purok 1, hilltop area',
        'barangay_id': 6,
      },
      {
        'name': 'Ernesto Diaz',
        'contact_number': '09171000014',
        'address': 'Purok 2, near barangay outpost',
        'barangay_id': 6,
      },
      // Zone C — Gabuyan (barangay_id: 7)
      {
        'name': 'Cynthia Flores',
        'contact_number': '09171000015',
        'address': 'Sitio Centro, main junction',
        'barangay_id': 7,
      },
      {
        'name': 'Alberto Lopez',
        'contact_number': '09171000016',
        'address': 'Sitio Riverside, near bridge',
        'barangay_id': 7,
      },
      // Zone C — Bunawan (barangay_id: 8)
      {
        'name': 'Nelia Soriano',
        'contact_number': '09171000017',
        'address': 'Purok 3, mountain trail entrance',
        'barangay_id': 8,
      },
      {
        'name': 'Danny Castillo',
        'contact_number': '09171000018',
        'address': 'Purok 4, near coconut farm',
        'barangay_id': 8,
      },
      // Zone C — Katipunan (barangay_id: 9)
      {
        'name': 'Beatriz Salazar',
        'contact_number': '09171000019',
        'address': 'Sitio Bukid, uphill road',
        'barangay_id': 9,
      },
      {
        'name': 'Fernando Rivera',
        'contact_number': '09171000020',
        'address': 'Sitio Crossing, near waiting shed',
        'barangay_id': 9,
      },
      // Zone C — Dagohoy (barangay_id: 10)
      {
        'name': 'Josefa Mangubat',
        'contact_number': '09171000021',
        'address': 'Purok 1, near day care center',
        'barangay_id': 10,
      },
      {
        'name': 'Ricky Pelaez',
        'contact_number': '09171000022',
        'address': 'Purok 2, end of dirt road',
        'barangay_id': 10,
      },
      // Zone C — Tiburcia (barangay_id: 11)
      {
        'name': 'Maricel Tan',
        'contact_number': '09171000023',
        'address': 'Sitio Taas, mountain barangay',
        'barangay_id': 11,
      },
      {
        'name': 'Joel Fernandez',
        'contact_number': '09171000024',
        'address': 'Sitio Ubos, lower portion',
        'barangay_id': 11,
      },
      // Zone C — Clementa (barangay_id: 12)
      {
        'name': 'Luz Morales',
        'contact_number': '09171000025',
        'address': 'Purok 1, near spring source',
        'barangay_id': 12,
      },
    ];

    for (final customer in defaultCustomers) {
      await db.insert('customers', customer);
    }
  }

  /// Seeds the schedules table by assigning delivery days to each customer
  /// based on their barangay's zone.
  ///
  /// Zone-to-day mapping is defined in [ZoneScheduleMap]:
  /// - Zone A (station vicinity): Mon–Sat (every operating day)
  /// - Zone B (near barangays): Mon/Wed/Fri (pedicab schedule)
  /// - Zone C (far/mountain): One specific day per barangay (weekly)
  ///
  /// Each customer gets one schedule record per allowed delivery day,
  /// all with 'active' status by default.
  Future<void> _seedSchedules(Database db) async {
    // Step 1: Query all customers joined with their barangay info.
    // We need the zone and barangay name to determine delivery days.
    final customers = await db.rawQuery('''
      SELECT c.id AS customer_id, b.name AS barangay_name, b.delivery_zone
      FROM customers c
      INNER JOIN barangays b ON c.barangay_id = b.id
    ''');

    // Step 2: For each customer, look up their allowed delivery days
    // using the ZoneScheduleMap and insert a schedule record per day.
    for (final customer in customers) {
      // Extract the customer's zone (e.g., 'Zone A') and barangay name
      final zone = customer['delivery_zone'] as String;
      final barangayName = customer['barangay_name'] as String;
      final customerId = customer['customer_id'] as int;

      // Get the list of delivery days for this customer's zone/barangay
      final deliveryDays = ZoneScheduleMap.getDaysForZone(
        zone,
        barangayName: barangayName,
      );

      // Insert one schedule record per allowed delivery day
      for (final day in deliveryDays) {
        await db.insert('schedules', {
          'customer_id': customerId,  // Links schedule to this customer
          'delivery_day': day,        // The day they can receive deliveries
          'status': 'active',         // All seeded schedules start as active
        });
      }
    }
  }

  // Task 003 — Barangay CRUD operations

  /// Get all barangays (useful for dropdowns)
  Future<List<Map<String, dynamic>>> getBarangays() async {
    final db = await instance.database;
    return await db.query('barangays', orderBy: 'name ASC');
  }

  /// Get a single barangay by ID
  Future<Map<String, dynamic>?> getBarangayById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'barangays',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert a new barangay
  Future<int> insertBarangay(Map<String, dynamic> barangayData) async {
    final db = await instance.database;
    return await db.insert('barangays', barangayData);
  }

  /// Delete a barangay by ID
  Future<int> deleteBarangay(int id) async {
    final db = await instance.database;
    return await db.delete('barangays', where: 'id = ?', whereArgs: [id]);
  }

  // Task 003, Task 005 — Customer CRUD operations

  /// Insert a new customer
  Future<int> insertCustomer(Map<String, dynamic> customerData) async {
    final db = await instance.database;
    return await db.insert('customers', customerData);
  }

  /// Get all customers (raw)
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await instance.database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  /// Get all customers with their barangay info joined.
  /// Includes the address field added in v2 for complete customer profiles.
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.contact_number, c.address,
             c.barangay_id,
             b.name AS barangay, b.delivery_zone
      FROM customers c
      INNER JOIN barangays b ON c.barangay_id = b.id
      ORDER BY c.name ASC
    ''');
  }

  /// Find a customer by phone number
  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await instance.database;
    final result = await db.query(
      'customers',
      where: 'contact_number = ?',
      whereArgs: [phoneNumber],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Task 003, Task 006 — Schedule CRUD operations

  /// Insert a new schedule record for a customer
  Future<int> insertSchedule(Map<String, dynamic> scheduleData) async {
    final db = await instance.database;
    return await db.insert('schedules', scheduleData);
  }

  /// Get all schedule records (newest first)
  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await instance.database;
    return await db.query('schedules', orderBy: 'id DESC');
  }

  /// Get all schedule records for a specific customer.
  /// Returns only 'active' schedules by default.
  /// Used by the ZoneValidator to check if a customer can order today.
  Future<List<Map<String, dynamic>>> getSchedulesForCustomer(
    int customerId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'schedules',
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, 'active'],
    );
  }

  // Task 003, Task 005 — Order CRUD operations

  Future<int> insertOrder(Map<String, dynamic> orderData) async {
    final db = await instance.database;
    return await db.insert('orders', orderData);
  }

  Future<List<Map<String, dynamic>>> getOrders({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await instance.database;
    return await db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayOrders() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'orders',
      where: 'date(created_at) = ?',
      whereArgs: [today],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> updateOrderStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Task 005 — Delivery Log CRUD operations

  /// Insert a new delivery log entry.
  /// Called when staff confirms a delivery was made to a household.
  Future<int> insertDeliveryLog(Map<String, dynamic> logData) async {
    final db = await instance.database;
    return await db.insert('delivery_logs', logData);
  }

  /// Get all delivery logs, newest first.
  /// Useful for the shift-end reconciliation view.
  Future<List<Map<String, dynamic>>> getDeliveryLogs() async {
    final db = await instance.database;
    return await db.query('delivery_logs', orderBy: 'delivered_at DESC');
  }

  /// Get all delivery logs for a specific order.
  /// Shows which households received gallons from a given order.
  Future<List<Map<String, dynamic>>> getDeliveryLogsForOrder(
    int orderId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'delivery_logs',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'delivered_at DESC',
    );
  }

  /// Get all delivery logs for a specific customer.
  /// Shows the full delivery history for a household (accountability tracking).
  Future<List<Map<String, dynamic>>> getDeliveryLogsForCustomer(
    int customerId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'delivery_logs',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'delivered_at DESC',
    );
  }

  /// Get today's delivery logs for shift-end reconciliation.
  /// Sums up all gallons delivered today for inventory checking.
  Future<List<Map<String, dynamic>>> getTodayDeliveryLogs() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'delivery_logs',
      where: 'date(delivered_at) = ?',
      whereArgs: [today],
      orderBy: 'delivered_at DESC',
    );
  }
}
