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

  // Create Customers, Schedules, and Orders tables
  Future _createSchema(Database db, int version) async {
    // 1. Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        barangay TEXT NOT NULL,
        delivery_zone TEXT NOT NULL
      )
    ''');

    // 2. Schedules Table
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        delivery_day TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // 3. Orders Table
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
  }

  // Customer CRUD
  Future<int> insertCustomer(Map<String, dynamic> customerData) async {
    final db = await instance.database;
    return await db.insert('customers', customerData);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await instance.database;
    return await db.query('customers');
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) async {
    final db = await instance.database;
    final result = await db.query(
      'customers',
      where: 'contact_number = ?',
      whereArgs: [phoneNumber],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Schedule CRUD
  Future<int> insertSchedule(Map<String, dynamic> scheduleData) async {
    final db = await instance.database;
    return await db.insert('schedules', scheduleData);
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final db = await instance.database;
    return await db.query('schedules');
  }

  // Order CRUD
  Future<int> insertOrder(Map<String, dynamic> orderData) async {
    final db = await instance.database;
    return await db.insert('orders', orderData);
  }

  Future<List<Map<String, dynamic>>> getOrders({
    String? where,
    List<dynamic>? whereArgs,
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
