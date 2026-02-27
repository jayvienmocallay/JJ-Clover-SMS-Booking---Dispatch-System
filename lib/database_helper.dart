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

  // Create Customers and Schedules tables
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
  }

  // Example CRUD operation: Insert Customer
  Future<int> insertCustomer(Map<String, dynamic> customerData) async {
    final db = await instance.database;
    return await db.insert('customers', customerData);
  }
}
