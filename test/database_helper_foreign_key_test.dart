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

  test('enables foreign keys and cascades customer deletion safely', () async {
    final helper = DatabaseHelper.instance;
    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);

    await expectLater(
      db.insert('schedules', {
        'customer_id': 9999,
        'delivery_day': 'Monday',
        'status': 'active',
      }),
      throwsA(isA<DatabaseException>()),
    );

    final barangay = (await db.query(
      'barangays',
      where: 'name = ?',
      whereArgs: ['San Isidro'],
      limit: 1,
    )).single;

    final customerId = await helper.insertCustomer({
      'name': 'FK Cascade Customer',
      'contact_number': '09171234567',
      'address': 'Purok 1',
      'barangay_id': barangay['id'],
    });

    final schedules = await helper.getSchedulesForCustomer(customerId);
    expect(schedules, isNotEmpty);

    final orderCreatedAt = DateTime(2026, 4, 26, 8).toIso8601String();
    final orderId = await helper.insertOrder({
      'customer_id': customerId,
      'phone_number': '09171234567',
      'type': 'deliver',
      'quantity': 3,
      'gallon_type': 'new',
      'address': 'Purok 1',
      'status': 'completed',
      'created_at': orderCreatedAt,
      'delivery_day': 'Monday',
      'is_pre_book': 0,
    });
    expect(orderId, greaterThan(0));

    final logId = await helper.insertDeliveryLog({
      'order_id': orderId,
      'customer_id': customerId,
      'staff_id': 7,
      'quantity_delivered': 3,
      'gallon_type': 'new',
      'notes': 'Delivered in full',
      'delivered_at': DateTime(2026, 4, 26, 9).toIso8601String(),
    });
    expect(logId, greaterThan(0));

    expect(await helper.deleteCustomer(customerId), 1);

    expect(
      await db.query('customers', where: 'id = ?', whereArgs: [customerId]),
      isEmpty,
    );
    expect(
      await db.query(
        'schedules',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      ),
      isEmpty,
    );
    expect(
      await db.query('delivery_logs', where: 'id = ?', whereArgs: [logId]),
      isEmpty,
    );

    final remainingOrders = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
    expect(remainingOrders, hasLength(1));
    expect(remainingOrders.single['customer_id'], isNull);
    expect(remainingOrders.single['type'], 'deliver');
    expect(remainingOrders.single['quantity'], 3);
    expect(remainingOrders.single['status'], 'completed');
    expect(remainingOrders.single['created_at'], orderCreatedAt);
  });
}
