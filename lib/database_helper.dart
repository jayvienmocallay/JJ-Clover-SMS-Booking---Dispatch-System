import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      version: 1,
      onCreate: _createSchema,
    );
  }

  // Create all tables
  Future _createSchema(Database db, int version) async {
    // 1. Barangays Lookup Table
    await db.execute('''
      CREATE TABLE barangays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        delivery_zone TEXT NOT NULL
      )
    ''');

    // 2. Customers Table (references barangays)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        barangay_id INTEGER NOT NULL,
        FOREIGN KEY (barangay_id) REFERENCES barangays (id)
      )
    ''');

    // 3. Schedules Table
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        delivery_day TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // 4. Orders Table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        phone_number TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        address TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        delivery_day TEXT,
        is_pre_book INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // Seed default barangays and customers
    await _seedBarangays(db);
    await _seedCustomers(db);
  }

  // Pre-populate barangays with default data
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

  // Pre-populate customers with synthetic data
  Future<void> _seedCustomers(Database db) async {
    final defaultCustomers = [
      // Zone A — San Isidro (barangay_id: 1)
      {
        'name': 'Maria Santos',
        'contact_number': '09171000001',
        'barangay_id': 1,
      },
      {
        'name': 'Juan dela Cruz',
        'contact_number': '09171000002',
        'barangay_id': 1,
      },
      {'name': 'Rosa Reyes', 'contact_number': '09171000003', 'barangay_id': 1},
      // Zone A — San Jose (barangay_id: 2)
      {
        'name': 'Pedro Garcia',
        'contact_number': '09171000004',
        'barangay_id': 2,
      },
      {
        'name': 'Ana Mendoza',
        'contact_number': '09171000005',
        'barangay_id': 2,
      },
      // Zone B — Poblacion (barangay_id: 3)
      {
        'name': 'Carlos Ramos',
        'contact_number': '09171000006',
        'barangay_id': 3,
      },
      {
        'name': 'Elena Torres',
        'contact_number': '09171000007',
        'barangay_id': 3,
      },
      {
        'name': 'Roberto Cruz',
        'contact_number': '09171000008',
        'barangay_id': 3,
      },
      // Zone B — Santa Rosa (barangay_id: 4)
      {
        'name': 'Liza Navarro',
        'contact_number': '09171000009',
        'barangay_id': 4,
      },
      {
        'name': 'Miguel Aquino',
        'contact_number': '09171000010',
        'barangay_id': 4,
      },
      // Zone C — Santo Niño (barangay_id: 5)
      {
        'name': 'Teresa Villanueva',
        'contact_number': '09171000011',
        'barangay_id': 5,
      },
      {
        'name': 'Ramon Bautista',
        'contact_number': '09171000012',
        'barangay_id': 5,
      },
      // Zone C — Semong (barangay_id: 6)
      {
        'name': 'Gloria Pascual',
        'contact_number': '09171000013',
        'barangay_id': 6,
      },
      {
        'name': 'Ernesto Diaz',
        'contact_number': '09171000014',
        'barangay_id': 6,
      },
      // Zone C — Gabuyan (barangay_id: 7)
      {
        'name': 'Cynthia Flores',
        'contact_number': '09171000015',
        'barangay_id': 7,
      },
      {
        'name': 'Alberto Lopez',
        'contact_number': '09171000016',
        'barangay_id': 7,
      },
      // Zone C — Bunawan (barangay_id: 8)
      {
        'name': 'Nelia Soriano',
        'contact_number': '09171000017',
        'barangay_id': 8,
      },
      {
        'name': 'Danny Castillo',
        'contact_number': '09171000018',
        'barangay_id': 8,
      },
      // Zone C — Katipunan (barangay_id: 9)
      {
        'name': 'Beatriz Salazar',
        'contact_number': '09171000019',
        'barangay_id': 9,
      },
      {
        'name': 'Fernando Rivera',
        'contact_number': '09171000020',
        'barangay_id': 9,
      },
      // Zone C — Dagohoy (barangay_id: 10)
      {
        'name': 'Josefa Mangubat',
        'contact_number': '09171000021',
        'barangay_id': 10,
      },
      {
        'name': 'Ricky Pelaez',
        'contact_number': '09171000022',
        'barangay_id': 10,
      },
      // Zone C — Tiburcia (barangay_id: 11)
      {
        'name': 'Maricel Tan',
        'contact_number': '09171000023',
        'barangay_id': 11,
      },
      {
        'name': 'Joel Fernandez',
        'contact_number': '09171000024',
        'barangay_id': 11,
      },
      // Zone C — Clementa (barangay_id: 12)
      {
        'name': 'Luz Morales',
        'contact_number': '09171000025',
        'barangay_id': 12,
      },
    ];

    for (final customer in defaultCustomers) {
      await db.insert('customers', customer);
    }
  }

  // --- Barangay operations ---

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

  // --- Customer operations ---

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

  /// Get all customers with their barangay info joined
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.contact_number,
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

  // --- Schedule operations ---

  Future<int> insertSchedule(Map<String, dynamic> scheduleData) async {
    final db = await instance.database;
    return await db.insert('schedules', scheduleData);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await instance.database;
    return await db.query('schedules', orderBy: 'id DESC');
  }

  // --- Order operations ---

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
}
