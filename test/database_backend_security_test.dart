import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: DatabaseHelper.configureDatabase,
        onCreate: DatabaseHelper.instance.createSchemaForTesting,
        singleInstance: false,
      ),
    );
    DatabaseHelper.setDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test('creates audit log and deletion retry tables', () async {
    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name IN (?, ?)',
      whereArgs: ['table', 'audit_logs', 'deletion_retry_queue'],
    );

    expect(
      tables.map((row) => row['name']),
      containsAll(['audit_logs', 'deletion_retry_queue']),
    );
  });

  test('audit logs hash phone numbers instead of storing raw PII', () async {
    final helper = DatabaseHelper.instance;

    await helper.insertAuditLog(
      action: 'customer_erasure_requested',
      entityType: 'customer',
      phoneNumber: '09171234567',
    );

    final logs = await db.query('audit_logs');
    expect(logs, hasLength(1));
    expect(logs.single['phone_hash'], isNot('09171234567'));
    expect(logs.single['phone_hash'], isA<String>());
    expect(logs.single.containsKey('phone_number'), isFalse);
  });

  test('deletion retry queue deduplicates active customer erasures', () async {
    final helper = DatabaseHelper.instance;

    final firstId = await helper.enqueueDeletionRetry(
      phoneNumber: '09171234567',
      lastError: 'offline',
    );
    final secondId = await helper.enqueueDeletionRetry(
      phoneNumber: '+639171234567',
      lastError: 'still offline',
    );

    final retries = await db.query('deletion_retry_queue');
    expect(secondId, firstId);
    expect(retries, hasLength(1));
    expect(retries.single['last_error'], 'still offline');
  });

  test('retention policy removes expired sensitive records', () async {
    final helper = DatabaseHelper.instance;
    final now = DateTime(2026, 5, 13, 12);
    final oldSmsAt = now.subtract(const Duration(days: 91)).toIso8601String();
    final oldReceiptAt = now
        .subtract(const Duration(days: 31))
        .toIso8601String();

    await helper.insertSmsMessage({
      'phone_number': '09171234567',
      'message': 'DELIVER 1',
      'direction': 'incoming',
      'sent_at': oldSmsAt,
    });
    await db.insert('incoming_sms_receipts', {
      'message_id': 'old-message',
      'phone_number': '+639171234567',
      'message': 'DELIVER 1',
      'status': 'completed',
      'attempts': 1,
      'received_at': oldReceiptAt,
      'updated_at': oldReceiptAt,
    });

    final deleted = await helper.applyRetentionPolicy(now: now);

    expect(deleted, 2);
    expect(await db.query('sms_messages'), isEmpty);
    expect(await db.query('incoming_sms_receipts'), isEmpty);
    expect(await db.query('audit_logs'), hasLength(1));
  });
}
