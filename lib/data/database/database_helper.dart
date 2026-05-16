// Task 005 - Data Layer: SQLCipher encrypted database with full CRUD operations
// Task 006 - Data seeding: barangays, customers, and schedules
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/security/database_encryption_key_repository.dart';
import '../../core/utils/phone_number_utils.dart';
import '../services/order_status_transition_service.dart';

part 'database_schema.dart';
part 'database_seed_data.dart';
part 'database_customer_operations.dart';
part 'database_order_operations.dart';
part 'database_sms_operations.dart';
part 'database_settings_operations.dart';
part 'database_pending_sms_operations.dart';
part 'database_privacy_operations.dart';

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

// Task 005 - Singleton DatabaseHelper for encrypted SQLCipher access.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _schemaIntegrityChecked = false;
  static Completer<Database>? _dbCompleter;
  static const int databaseVersion = 11;
  static const Duration _receiptRetryAfter = Duration(minutes: 10);
  static const Duration _resubmitCooldownAfter = Duration(hours: 1);
  static const String readMessageIdsKey = 'read_message_ids';
  static const String preBookPendingKey = 'pre_book_pending';
  static const String cutoffHourKey = 'cutoff_hour';
  static const String cutoffMinuteKey = 'cutoff_minute';

  final DatabaseEncryptionKeyRepository _encryptionKeyRepository =
      DatabaseEncryptionKeyRepository();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      await ensureDatabaseSchemaIntegrity(_database!);
      return _database!;
    }

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    _dbCompleter = Completer<Database>();
    try {
      final db = await _initDB('clover_secure.db');
      _database = db;
      await ensureDatabaseSchemaIntegrity(db);
      _dbCompleter!.complete(db);
      return db;
    } catch (e, st) {
      final completer = _dbCompleter!;
      _dbCompleter = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  /// Ensures default schedules exist for databases created before schedule
  /// seeding was added.
  Future<void> ensureSchedulesSeeded() async {
    final db = await database;
    final existingSchedules = await db.query('schedules', limit: 1);
    if (existingSchedules.isEmpty) {
      await seedSchedules(db);
    }
  }

  Future<String> _getSecurePassword() {
    return _encryptionKeyRepository.readOrCreate();
  }

  Future<Database> _initDB(String filePath) async {
    final dbDirectory = await getApplicationDocumentsDirectory();
    final path = '${dbDirectory.path}${Platform.pathSeparator}$filePath';
    final password = await _getSecurePassword();

    try {
      return await openDatabase(
        path,
        password: password,
        version: databaseVersion,
        onConfigure: configureDatabase,
        onCreate: createDatabaseSchema,
        onUpgrade: upgradeDatabaseSchema,
      );
    } catch (e) {
      final file = File(path);
      if (await file.exists()) {
        debugPrint(
          'DB open failed ($e) - stale encrypted file detected, recreating.',
        );
        await file.delete();
      }
      return await openDatabase(
        path,
        password: password,
        version: databaseVersion,
        onConfigure: configureDatabase,
        onCreate: createDatabaseSchema,
        onUpgrade: upgradeDatabaseSchema,
      );
    }
  }

  static Future<void> configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static void setDatabaseForTesting(Database? database) {
    _database = database;
    _schemaIntegrityChecked = false;
  }

  Future<void> createSchemaForTesting(Database db, int version) async {
    await createDatabaseSchema(db, version);
  }

  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await upgradeDatabaseSchema(db, oldVersion, newVersion);
  }
}
