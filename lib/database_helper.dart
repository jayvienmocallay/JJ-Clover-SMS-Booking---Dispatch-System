// Task 005 — Data Layer: SQLCipher encrypted database with full CRUD operations
// Task 006 — Data seeding: barangays, customers, and schedules
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'core/constants/app_constants.dart';
import 'core/security/database_encryption_key_repository.dart';
import 'core/utils/phone_number_utils.dart';

class CustomerPhoneAlreadyExistsException implements Exception {
  final String contactNumber;

  const CustomerPhoneAlreadyExistsException(this.contactNumber);

  @override
  String toString() => 'A customer with $contactNumber already exists';
}

class CustomerPhoneIdentityMigrationException implements Exception {
  final String message;

  const CustomerPhoneIdentityMigrationException(this.message);

  @override
  String toString() => message;
}

// Task 005 — Singleton DatabaseHelper for encrypted SQLCipher access
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _schemaIntegrityChecked = false;
  static const int databaseVersion = 5;
  static const Duration _receiptRetryAfter = Duration(minutes: 10);
  final DatabaseEncryptionKeyRepository _encryptionKeyRepository =
      DatabaseEncryptionKeyRepository();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      await _ensureSchemaIntegrity(_database!);
      return _database!;
    }

    final db = await _initDB('clover_secure.db');
    _database = db;
    await _ensureSchemaIntegrity(db);
    return db;
  }

  /// Ensures default schedules exist for databases created before schedule
  /// seeding was added.
  Future<void> ensureSchedulesSeeded() async {
    final db = await database;
    final existingSchedules = await db.query('schedules', limit: 1);
    if (existingSchedules.isEmpty) {
      await _seedSchedules(db);
    }
  }

  // Retrieve or generate the database password securely
  Future<String> _getSecurePassword() async {
    return _encryptionKeyRepository.readOrCreate();
  }

  Future<Database> _initDB(String filePath) async {
    final dbDirectory = await getApplicationDocumentsDirectory();
    final path = '${dbDirectory.path}${Platform.pathSeparator}$filePath';

    final password = await _getSecurePassword();

    return await openDatabase(
      path,
      password: password,
      // Version 5: Enforces normalized, unique customer phone identity.
      version: databaseVersion,
      onConfigure: configureDatabase,
      onCreate: _createSchema,
      // Handles upgrading existing v1 databases to v2 schema
      onUpgrade: _upgradeSchema,
    );
  }

  static Future<void> configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Test hooks let in-memory database tests exercise the same helper methods
  // without touching the encrypted app database or platform storage channels.
  static void setDatabaseForTesting(Database? database) {
    _database = database;
    _schemaIntegrityChecked = false;
  }

  Future<void> createSchemaForTesting(Database db, int version) async {
    await _createSchema(db, version);
  }

  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _upgradeSchema(db, oldVersion, newVersion);
  }

  // Task 005 — Create all tables (schema v5)
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

    await _createCustomerContactNumberIndex(db);

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
        cancel_reason TEXT,
        created_at TEXT NOT NULL,
        delivery_day TEXT,
        is_pre_book INTEGER DEFAULT 0,
        staff_id INTEGER,
        source_message_id TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // Add indexes for query performance
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_phone ON orders(phone_number)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_delivery_day ON orders(delivery_day)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(type)',
    );

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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_delivery_logs_order ON delivery_logs(order_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_delivery_logs_customer ON delivery_logs(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_delivery_logs_delivered ON delivery_logs(delivered_at)',
    );

    await _createSmsMessagesTable(db);
    await _createIncomingSmsReceiptsTable(db);
    await _createAppSettingsTable(db);

    // Task 006 — Seed default data in order: barangays first, then customers, then schedules.
    // Order matters because of foreign key dependencies:
    // schedules -> customers -> barangays
    await _seedBarangays(db);
    await _seedCustomers(db);
    await _seedSchedules(db);
  }

  // Task 005 — Database migration: v1 → current schema upgrade
  /// Handles upgrading the database schema from an older version to the current one.
  ///
  /// v1 → v2 changes:
  /// - Added `address` column to customers (FR-1.2: full address)
  /// - Added `gallon_type` column to orders (gallon classification: new/old)
  /// - Added `staff_id` column to orders (staff assignment & accountability)
  /// - Created `delivery_logs` table (per-household delivery tracking)
  /// - Seeded schedules if missing from v1
  ///
  /// v2 → v3 changes:
  /// - Created `app_settings` table for persisted runtime settings
  Future _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    // Migrate from version 1 to version 2
    if (oldVersion < 2) {
      // Add address column to customers table for full delivery address
      await db.execute('ALTER TABLE customers ADD COLUMN address TEXT');

      // Add gallon classification column: 'new' (household) or 'old' (store)
      await db.execute('ALTER TABLE orders ADD COLUMN gallon_type TEXT');

      // Add staff assignment column for delivery accountability
      await db.execute('ALTER TABLE orders ADD COLUMN staff_id INTEGER');

      // Add cancel reason column for rejected orders
      await db.execute('ALTER TABLE orders ADD COLUMN cancel_reason TEXT');

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

      // Add indexes for query performance (idempotent)
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_phone ON orders(phone_number)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_delivery_day ON orders(delivery_day)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(type)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delivery_logs_order ON delivery_logs(order_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delivery_logs_customer ON delivery_logs(customer_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_delivery_logs_delivered ON delivery_logs(delivered_at)',
        );
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await _createAppSettingsTable(db);
    }

    if (oldVersion < 4) {
      await _createSmsMessagesTable(db);
      await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
      await _addColumnIfMissing(
        db,
        'sms_messages',
        'source_message_id',
        'TEXT',
      );
      await _createIncomingSmsReceiptsTable(db);
      await _createSourceMessageIndexes(db);
    }

    if (oldVersion < 5) {
      await _normalizeCustomerContactNumbers(db);
      await _createCustomerContactNumberIndex(db);
    }

    // Create sms_messages table if not exists (for old databases)
    await _createSmsMessagesTable(db);
    await _createIncomingSmsReceiptsTable(db);
    await _createSourceMessageIndexes(db);
    await _createCustomerContactNumberIndex(db);
  }

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSmsMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        message TEXT NOT NULL,
        direction TEXT NOT NULL,
        related_order_id INTEGER,
        status TEXT,
        source_message_id TEXT,
        sent_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sms_phone ON sms_messages(phone_number)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sms_direction ON sms_messages(direction)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sms_sent ON sms_messages(sent_at)',
    );
    await _createSourceMessageIndexes(db);
  }

  Future<void> _createIncomingSmsReceiptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incoming_sms_receipts (
        message_id TEXT PRIMARY KEY,
        phone_number TEXT NOT NULL,
        message TEXT NOT NULL,
        sms_timestamp INTEGER,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        received_at TEXT NOT NULL,
        claimed_at TEXT,
        completed_at TEXT,
        updated_at TEXT NOT NULL,
        last_error TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sms_receipts_status ON incoming_sms_receipts(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sms_receipts_phone ON incoming_sms_receipts(phone_number)',
    );
  }

  Future<void> _createSourceMessageIndexes(Database db) async {
    await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
    await _addColumnIfMissing(db, 'sms_messages', 'source_message_id', 'TEXT');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_source_message '
      'ON sms_messages(source_message_id) '
      'WHERE source_message_id IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_source_message '
      'ON orders(source_message_id) '
      'WHERE source_message_id IS NOT NULL',
    );
  }

  Future<void> _createCustomerContactNumberIndex(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS '
      'idx_customers_contact_number_unique '
      'ON customers(contact_number)',
    );
  }

  Future<void> _normalizeCustomerContactNumbers(Database db) async {
    final customers = await db.query(
      'customers',
      columns: ['id', 'contact_number'],
      orderBy: 'id ASC',
    );
    final idsByPhone = <String, List<int>>{};
    final normalizedById = <int, String>{};

    for (final customer in customers) {
      final id = customer['id'] as int;
      final currentPhone = customer['contact_number'] as String? ?? '';
      final normalizedPhone = PhoneNumberUtils.normalize(currentPhone);
      normalizedById[id] = normalizedPhone;
      idsByPhone.putIfAbsent(normalizedPhone, () => <int>[]).add(id);
    }

    final duplicates = idsByPhone.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}: customer IDs ${entry.value.join(', ')}')
        .toList();

    if (duplicates.isNotEmpty) {
      throw CustomerPhoneIdentityMigrationException(
        'Duplicate customer phone numbers after normalization: '
        '${duplicates.join('; ')}',
      );
    }

    for (final customer in customers) {
      final id = customer['id'] as int;
      final currentPhone = customer['contact_number'] as String? ?? '';
      final normalizedPhone = normalizedById[id]!;
      if (currentPhone != normalizedPhone) {
        await db.update(
          'customers',
          {'contact_number': normalizedPhone},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Map<String, dynamic> _normalizeCustomerData(Map<String, dynamic> data) {
    final normalizedData = Map<String, dynamic>.from(data);
    final contactNumber = normalizedData['contact_number'] as String?;
    if (contactNumber != null) {
      normalizedData['contact_number'] = PhoneNumberUtils.normalize(
        contactNumber,
      );
    }
    return normalizedData;
  }

  bool _isCustomerContactNumberUniqueError(DatabaseException error) {
    final message = error.toString().toLowerCase();
    return error.isUniqueConstraintError('customers.contact_number') ||
        (error.isUniqueConstraintError() &&
            message.contains('customers.contact_number'));
  }

  Future<void> _ensureSchemaIntegrity(Database db) async {
    if (_schemaIntegrityChecked) return;

    await _normalizeCustomerContactNumbers(db);
    await _createCustomerContactNumberIndex(db);
    await _createAppSettingsTable(db);
    await _createSmsMessagesTable(db);
    await _createIncomingSmsReceiptsTable(db);
    await _addColumnIfMissing(db, 'orders', 'cancel_reason', 'TEXT');
    await _addColumnIfMissing(db, 'orders', 'source_message_id', 'TEXT');
    await _addColumnIfMissing(db, 'sms_messages', 'source_message_id', 'TEXT');
    await _createSourceMessageIndexes(db);

    _schemaIntegrityChecked = true;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // Task 006 — Pre-populate barangays with default data
  DateTime? _tryParseDate(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

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

  // Task 006 — Pre-populate customers (no longer seeded with sample data)
  // Customers are now added via the app UI
  Future<void> _seedCustomers(Database db) async {
    // No sample data - customers added via app
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
          'customer_id': customerId, // Links schedule to this customer
          'delivery_day': day, // The day they can receive deliveries
          'status': 'active', // All seeded schedules start as active
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

  /// Delete a customer by ID
  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // Task 003, Task 005 — Customer CRUD operations

  /// Insert a new customer and automatically create schedules based on barangay zone
  Future<int> insertCustomer(Map<String, dynamic> customerData) async {
    final db = await instance.database;
    final normalizedData = _normalizeCustomerData(customerData);
    late final int customerId;
    try {
      customerId = await db.insert('customers', normalizedData);
    } on DatabaseException catch (error) {
      if (_isCustomerContactNumberUniqueError(error)) {
        throw CustomerPhoneAlreadyExistsException(
          normalizedData['contact_number'] as String? ?? '',
        );
      }
      rethrow;
    }

    // Auto-create schedules based on barangay's delivery zone
    final barangayId = normalizedData['barangay_id'] as int?;
    if (barangayId != null) {
      final barangay = await getBarangayById(barangayId);
      if (barangay != null) {
        final zone = barangay['delivery_zone'] as String;
        final barangayName = barangay['name'] as String;
        final deliveryDays = ZoneScheduleMap.getDaysForZone(
          zone,
          barangayName: barangayName,
        );
        for (final day in deliveryDays) {
          await db.insert('schedules', {
            'customer_id': customerId,
            'delivery_day': day,
            'status': 'active',
          });
        }
      }
    }

    return customerId;
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
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final result = await db.query(
      'customers',
      where: 'contact_number = ?',
      whereArgs: [normalizedPhone],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Find a customer by phone number with joined barangay and zone details.
  Future<Map<String, dynamic>?> getCustomerWithBarangayByPhone(
    String phoneNumber,
  ) async {
    final db = await instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final result = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.contact_number, c.address,
             c.barangay_id,
             b.name AS barangay, b.delivery_zone
      FROM customers c
      INNER JOIN barangays b ON c.barangay_id = b.id
      WHERE c.contact_number = ?
      LIMIT 1
    ''',
      [normalizedPhone],
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
    final normalizedData = Map<String, dynamic>.from(orderData);
    final phoneNumber = normalizedData['phone_number'] as String?;
    if (phoneNumber != null) {
      normalizedData['phone_number'] = PhoneNumberUtils.normalize(phoneNumber);
    }
    return await db.insert(
      'orders',
      normalizedData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
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

  Future<int> updateOrderStatus(
    int id,
    String status, {
    String? reason,
    String? notes,
    DateTime? deliveredAt,
  }) async {
    final db = await instance.database;
    final data = <String, dynamic>{'status': status};
    if (reason != null && reason.isNotEmpty) {
      data['cancel_reason'] = reason;
    }
    if (status != 'completed') {
      return await db.update('orders', data, where: 'id = ?', whereArgs: [id]);
    }

    return await db.transaction<int>((txn) async {
      final orders = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (orders.isEmpty) {
        return 0;
      }

      final order = orders.single;
      final customerId = order['customer_id'] as int?;
      if (customerId == null) {
        throw StateError(
          'Cannot complete order $id because it has no customer_id for a delivery log.',
        );
      }

      final updated = await txn.update(
        'orders',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        return 0;
      }

      final existingLogs = await txn.query(
        'delivery_logs',
        columns: ['id'],
        where: 'order_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingLogs.isEmpty) {
        final logData = <String, dynamic>{
          'order_id': id,
          'customer_id': customerId,
          'quantity_delivered': order['quantity'] as int? ?? 0,
          'delivered_at': (deliveredAt ?? DateTime.now()).toIso8601String(),
        };

        final staffId = order['staff_id'] as int?;
        if (staffId != null) {
          logData['staff_id'] = staffId;
        }

        final gallonType = _nonEmptyString(order['gallon_type'] as String?);
        if (gallonType != null) {
          logData['gallon_type'] = gallonType;
        }

        final deliveryNotes = _nonEmptyString(notes);
        if (deliveryNotes != null) {
          logData['notes'] = deliveryNotes;
        }

        await txn.insert('delivery_logs', logData);
      }

      return updated;
    });
  }

  String? _nonEmptyString(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

  // --- SMS Messages CRUD ---

  /// Claims an incoming SMS for processing. Returns false for completed or
  /// recently active duplicate receipts.
  Future<bool> claimIncomingSmsReceipt({
    required String messageId,
    required String phoneNumber,
    required String message,
    int? smsTimestamp,
  }) async {
    final db = await instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);

    return await db.transaction<bool>((txn) async {
      final existing = await txn.query(
        'incoming_sms_receipts',
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('incoming_sms_receipts', {
          'message_id': messageId,
          'phone_number': normalizedPhone,
          'message': message,
          'sms_timestamp': smsTimestamp,
          'status': 'processing',
          'attempts': 1,
          'received_at': nowIso,
          'claimed_at': nowIso,
          'updated_at': nowIso,
        });
        return true;
      }

      final row = existing.first;
      final status = row['status'] as String? ?? '';
      if (status == 'completed') {
        return false;
      }

      if (status == 'processing') {
        final claimedAt = _tryParseDate(row['claimed_at'] as String?);
        if (claimedAt != null &&
            now.difference(claimedAt) < _receiptRetryAfter) {
          return false;
        }
      }

      final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
      await txn.update(
        'incoming_sms_receipts',
        {
          'phone_number': normalizedPhone,
          'message': message,
          'sms_timestamp': smsTimestamp,
          'status': 'processing',
          'attempts': attempts + 1,
          'claimed_at': nowIso,
          'updated_at': nowIso,
          'last_error': null,
        },
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
      return true;
    });
  }

  Future<void> completeIncomingSmsReceipt(String messageId) async {
    final db = await instance.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'incoming_sms_receipts',
      {
        'status': 'completed',
        'completed_at': nowIso,
        'updated_at': nowIso,
        'last_error': null,
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> failIncomingSmsReceipt(String messageId, Object error) async {
    final db = await instance.database;
    await db.update(
      'incoming_sms_receipts',
      {
        'status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
        'last_error': error.toString(),
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<Map<String, dynamic>?> getIncomingSmsReceipt(String messageId) async {
    final db = await instance.database;
    final rows = await db.query(
      'incoming_sms_receipts',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Insert an SMS message (incoming or outgoing)
  Future<int> insertSmsMessage(Map<String, dynamic> messageData) async {
    final db = await instance.database;
    final normalizedData = Map<String, dynamic>.from(messageData);
    final phoneNumber = normalizedData['phone_number'] as String?;
    if (phoneNumber != null) {
      normalizedData['phone_number'] = PhoneNumberUtils.normalize(phoneNumber);
    }
    return await db.insert(
      'sms_messages',
      normalizedData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all SMS messages for a phone number
  Future<List<Map<String, dynamic>>> getSmsMessagesForPhone(
    String phoneNumber, {
    int? limit,
  }) async {
    final db = await instance.database;
    return await db.query(
      'sms_messages',
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
      orderBy: 'sent_at DESC',
      limit: limit,
    );
  }

  /// Get all SMS messages, newest first
  Future<List<Map<String, dynamic>>> getAllSmsMessages({int? limit}) async {
    final db = await instance.database;
    return await db.query(
      'sms_messages',
      orderBy: 'sent_at DESC',
      limit: limit,
    );
  }

  /// Get all SMS messages for today
  Future<List<Map<String, dynamic>>> getTodaySmsMessages() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'sms_messages',
      where: 'date(sent_at) = ?',
      whereArgs: [today],
      orderBy: 'sent_at DESC',
    );
  }

  /// Update customer info
  Future<int> updateCustomer(
    int customerId,
    Map<String, dynamic> customerData,
  ) async {
    final db = await instance.database;
    final normalizedData = _normalizeCustomerData(customerData);
    try {
      return await db.update(
        'customers',
        normalizedData,
        where: 'id = ?',
        whereArgs: [customerId],
      );
    } on DatabaseException catch (error) {
      if (_isCustomerContactNumberUniqueError(error)) {
        throw CustomerPhoneAlreadyExistsException(
          normalizedData['contact_number'] as String? ?? '',
        );
      }
      rethrow;
    }
  }

  // App settings CRUD operations

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  static const String readMessageIdsKey = 'read_message_ids';
  static const String preBookPendingKey = 'pre_book_pending';
  static const String cutoffHourKey = 'cutoff_hour';
  static const String cutoffMinuteKey = 'cutoff_minute';

  Future<Set<int>> getReadMessageIds() async {
    final value = await getSetting(readMessageIdsKey);
    if (value == null || value.isEmpty) return {};
    try {
      return value
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setReadMessageIds(Set<int> ids) async {
    await setSetting(readMessageIdsKey, ids.join(','));
  }

  Future<Map<String, Map<String, dynamic>>> getPreBookPending() async {
    final value = await getSetting(preBookPendingKey);
    if (value == null || value.isEmpty) return {};
    try {
      return _decodePreBookPendingJson(value);
    } on FormatException {
      final legacyPending = _decodeLegacyPreBookPending(value);
      if (legacyPending.isNotEmpty) {
        await setPreBookPending(legacyPending);
      }
      return legacyPending;
    } catch (_) {
      return {};
    }
  }

  Future<void> setPreBookPending(
    Map<String, Map<String, dynamic>> pending,
  ) async {
    final serialized = <String, Map<String, dynamic>>{};
    for (final entry in pending.entries) {
      final context = _coercePreBookPendingContext(entry.key, entry.value);
      if (context != null) {
        serialized[entry.key] = context;
      }
    }
    await setSetting(preBookPendingKey, jsonEncode(serialized));
  }

  Map<String, Map<String, dynamic>> _decodePreBookPendingJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) return {};

    final result = <String, Map<String, dynamic>>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) continue;

      final context = _coercePreBookPendingContext(key, entry.value);
      if (context != null) {
        result[key] = context;
      }
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _decodeLegacyPreBookPending(String value) {
    final result = <String, Map<String, dynamic>>{};
    final entries = value.split(RegExp(r'\|(?=\+?\d+~\d+~\d+~)'));

    for (final entry in entries) {
      final context = _decodeLegacyPreBookPendingEntry(entry);
      if (context != null) {
        result[context['phoneNumber'] as String] = context;
      }
    }
    return result;
  }

  Map<String, dynamic>? _decodeLegacyPreBookPendingEntry(String value) {
    if (value.isEmpty) return null;

    final parts = value.split('~');
    if (parts.length < 6) return null;

    final phoneNumber = parts[0];
    final customerId = int.tryParse(parts[1]);
    final quantity = int.tryParse(parts[2]);
    if (phoneNumber.isEmpty || customerId == null || quantity == null) {
      return null;
    }

    final timestamp = int.tryParse(parts.last);
    final deliveryDayIndex = timestamp == null
        ? parts.length - 1
        : parts.length - 2;
    if (deliveryDayIndex < 5) return null;

    final address = parts.sublist(4, deliveryDayIndex).join('~');
    final deliveryDay = parts[deliveryDayIndex];
    if (deliveryDay.isEmpty) return null;

    return {
      'customerId': customerId,
      'phoneNumber': phoneNumber,
      'quantity': quantity,
      'gallonType': parts[3].isEmpty ? null : parts[3],
      'address': address.isEmpty ? null : address,
      'deliveryDay': deliveryDay,
      'timestamp': timestamp ?? 0,
    };
  }

  Map<String, dynamic>? _coercePreBookPendingContext(
    String phoneKey,
    Object? value,
  ) {
    if (value is! Map) return null;

    final customerId = _asInt(value['customerId']);
    final quantity = _asInt(value['quantity']);
    final deliveryDay = _asNonEmptyString(value['deliveryDay']);
    if (customerId == null || quantity == null || deliveryDay == null) {
      return null;
    }

    return {
      'customerId': customerId,
      'phoneNumber': _asNonEmptyString(value['phoneNumber']) ?? phoneKey,
      'quantity': quantity,
      'gallonType': _asNonEmptyString(value['gallonType']),
      'address': _asNonEmptyString(value['address']),
      'deliveryDay': deliveryDay,
      'timestamp': _asInt(value['timestamp']) ?? 0,
    };
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? _asNonEmptyString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  Future<int> getCutoffHour() async {
    final value = await getSetting(cutoffHourKey);
    return int.tryParse(value ?? '') ?? 7;
  }

  Future<int> getCutoffMinute() async {
    final value = await getSetting(cutoffMinuteKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> setCutoffTime(int hour, int minute) async {
    await setSetting(cutoffHourKey, hour.toString());
    await setSetting(cutoffMinuteKey, minute.toString());
  }
}
