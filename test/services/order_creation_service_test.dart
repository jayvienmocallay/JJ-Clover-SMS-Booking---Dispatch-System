import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/models/order_model.dart';
import 'package:jj_clover_sms/data/services/order_creation_service.dart';
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

  test('manual walk-in order stores normalized phone and manual source', () async {
    final service = OrderCreationService();

    final orderId = await service.createManualOrder(
      phoneNumber: '+63 917 123 4567',
      type: OrderType.drop,
      quantity: 2,
      gallonType: GallonType.oldGallon,
    );

    expect(orderId, greaterThan(0));
    final row = (await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    ))
        .single;

    expect(row['phone_number'], '09171234567');
    expect(row['type'], 'drop');
    expect(row['quantity'], 2);
    expect(row['gallon_type'], 'old');
    expect(row['source'], 'manual');
    expect(row['status'], 'pending');
  });

  test('guest delivery requires an address', () async {
    final service = OrderCreationService();

    await expectLater(
      service.createManualOrder(
        phoneNumber: '09171234567',
        type: OrderType.deliver,
        quantity: 1,
        gallonType: GallonType.newGallon,
      ),
      throwsA(isA<OrderCreationException>()),
    );
  });

  test('delivery with existing customer can be created without manual address', () async {
    final helper = DatabaseHelper.instance;
    final barangay = (await db.query(
      'barangays',
      where: 'name = ?',
      whereArgs: ['San Isidro'],
      limit: 1,
    ))
        .single;

    final customerId = await helper.insertCustomer({
      'name': 'Existing Delivery Customer',
      'contact_number': '09170000001',
      'address': 'Known address',
      'barangay_id': barangay['id'],
    });

    final orderId = await OrderCreationService().createManualOrder(
      customerId: customerId,
      phoneNumber: '09170000001',
      type: OrderType.deliver,
      quantity: 3,
      gallonType: GallonType.newGallon,
    );

    expect(orderId, greaterThan(0));
    final row = (await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    ))
        .single;

    expect(row['customer_id'], customerId);
    expect(row['type'], 'deliver');
    expect(row['source'], 'manual');
  });

  test('rejects invalid quantity before inserting an order', () async {
    final service = OrderCreationService();

    await expectLater(
      service.createManualOrder(
        phoneNumber: '09170000002',
        type: OrderType.drop,
        quantity: 0,
        gallonType: GallonType.newGallon,
      ),
      throwsA(isA<OrderCreationException>()),
    );

    expect(await db.query('orders'), isEmpty);
  });
}
