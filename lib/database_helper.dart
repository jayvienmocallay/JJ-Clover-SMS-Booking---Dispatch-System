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

    // Open the database using the secure password
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

    // Seed default barangays
    await _seedBarangays(db);
  }

  // Pre-populate barangays with default data
  Future<void> _seedBarangays(Database db) async {
    final defaultBarangays = [
      {'name': 'San Isidro', 'delivery_zone': 'Zone A'},
      {'name': 'San Jose', 'delivery_zone': 'Zone A'},
      {'name': 'Poblacion', 'delivery_zone': 'Zone B'},
      {'name': 'Santa Rosa', 'delivery_zone': 'Zone B'},
      {'name': 'Santo Niño', 'delivery_zone': 'Zone C'},
    ];

    for (final barangay in defaultBarangays) {
      await db.insert('barangays', barangay);
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

  /// Get all customers with their barangay info joined
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.contact_number,
             b.name AS barangay, b.delivery_zone
      FROM customers c
      INNER JOIN barangays b ON c.barangay_id = b.id
      ORDER BY c.name ASC
    ''');
  }
}
