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

  test('sms_messages.source_message_id allows duplicate values', () async {
    const sharedId = 'shared-source-msg-001';

    await db.insert('sms_messages', {
      'phone_number': '09171000001',
      'message': 'First reply',
      'direction': 'outgoing',
      'source_message_id': sharedId,
      'sent_at': DateTime(2026, 5, 12, 10).toIso8601String(),
    });

    await expectLater(
      db.insert('sms_messages', {
        'phone_number': '09171000001',
        'message': 'Second reply',
        'direction': 'outgoing',
        'source_message_id': sharedId,
        'sent_at': DateTime(2026, 5, 12, 10, 5).toIso8601String(),
      }),
      completes,
    );

    final rows = await db.query(
      'sms_messages',
      where: 'source_message_id = ?',
      whereArgs: [sharedId],
    );
    expect(rows, hasLength(2));
  });

  test('orders.source_message_id rejects duplicate non-null values', () async {
    const sharedId = 'shared-order-source-001';

    await db.insert('orders', {
      'phone_number': '09171000002',
      'type': 'deliver',
      'quantity': 1,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 12, 10).toIso8601String(),
      'source_message_id': sharedId,
    });

    await expectLater(
      db.insert('orders', {
        'phone_number': '09171000002',
        'type': 'deliver',
        'quantity': 2,
        'status': 'pending',
        'created_at': DateTime(2026, 5, 12, 10, 5).toIso8601String(),
        'source_message_id': sharedId,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('orders.source_message_id allows multiple null values', () async {
    await db.insert('orders', {
      'phone_number': '09171000003',
      'type': 'deliver',
      'quantity': 1,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 12, 11).toIso8601String(),
    });

    await expectLater(
      db.insert('orders', {
        'phone_number': '09171000003',
        'type': 'deliver',
        'quantity': 2,
        'status': 'pending',
        'created_at': DateTime(2026, 5, 12, 11, 5).toIso8601String(),
      }),
      completes,
    );
  });

  test('idx_sms_source_message is non-unique (PRAGMA index_list)', () async {
    final indexes = await db.rawQuery(
      "PRAGMA index_list('sms_messages')",
    );
    final smsIdx = indexes.firstWhere(
      (row) => row['name'] == 'idx_sms_source_message',
      orElse: () => throw TestFailure(
        'idx_sms_source_message not found in sms_messages index list',
      ),
    );
    expect(
      smsIdx['unique'],
      0,
      reason: 'idx_sms_source_message must be non-unique',
    );
  });

  test('idx_orders_source_message is unique (PRAGMA index_list)', () async {
    final indexes = await db.rawQuery(
      "PRAGMA index_list('orders')",
    );
    final ordersIdx = indexes.firstWhere(
      (row) => row['name'] == 'idx_orders_source_message',
      orElse: () => throw TestFailure(
        'idx_orders_source_message not found in orders index list',
      ),
    );
    expect(
      ordersIdx['unique'],
      1,
      reason: 'idx_orders_source_message must be unique',
    );
  });

  test('upgrading over old unique idx_sms_source_message succeeds', () async {
    final altDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: DatabaseHelper.configureDatabase,
        onCreate: (Database d, int v) async {
          await DatabaseHelper.instance.createSchemaForTesting(d, v);
          // Simulate old production: recreate the index as UNIQUE so upgrade
          // logic must DROP and recreate it as non-unique.
          await d.execute('DROP INDEX IF EXISTS idx_sms_source_message');
          await d.execute(
            'CREATE UNIQUE INDEX idx_sms_source_message '
            'ON sms_messages(source_message_id) '
            'WHERE source_message_id IS NOT NULL',
          );
        },
        singleInstance: false,
      ),
    );

    // _createSourceMessageIndexes is called via _ensureSchemaIntegrity;
    // invoke it directly through the upgrade helper so it runs DROP + recreate.
    await DatabaseHelper.instance.upgradeSchemaForTesting(
      altDb,
      3, // oldVersion < 4 triggers _createSourceMessageIndexes
      DatabaseHelper.databaseVersion,
    );

    final indexes = await altDb.rawQuery(
      "PRAGMA index_list('sms_messages')",
    );
    final idx = indexes.firstWhere(
      (row) => row['name'] == 'idx_sms_source_message',
    );
    expect(idx['unique'], 0, reason: 'index must be non-unique after upgrade');

    await altDb.close();
  });
}
