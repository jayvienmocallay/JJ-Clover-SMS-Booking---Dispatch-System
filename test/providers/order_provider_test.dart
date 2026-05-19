import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/providers/order_provider.dart';
import 'package:jj_clover_sms/data/repositories/order_repository.dart';
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

  test(
    'completing an order through OrderProvider creates one delivery log',
    () async {
      final helper = DatabaseHelper.instance;
      final barangay = (await db.query(
        'barangays',
        where: 'name = ?',
        whereArgs: ['San Isidro'],
        limit: 1,
      )).single;

      final customerId = await helper.insertCustomer({
        'name': 'Provider Completion Customer',
        'contact_number': '09182223333',
        'address': 'Purok 4',
        'barangay_id': barangay['id'],
      });
      final orderId = await helper.insertOrder({
        'customer_id': customerId,
        'phone_number': '09182223333',
        'type': 'deliver',
        'quantity': 4,
        'address': 'Purok 4',
        'status': 'in_transit',
        'created_at': DateTime.now().toIso8601String(),
        'delivery_day': 'Monday',
        'is_pre_book': 0,
        'staff_id': 3,
      });

      final provider = OrderProvider(OrderRepository());

      final completed = await provider.updateStatus(
        orderId,
        'completed',
        notes: 'Provider completion',
      );

      expect(completed, isTrue);
      expect(provider.error, isNull);
      expect(provider.todayOrders, isNotEmpty);
      expect(
        provider.todayOrders.firstWhere(
          (order) => order['id'] == orderId,
        )['status'],
        'completed',
      );

      final logs = await helper.getDeliveryLogsForOrder(orderId);
      expect(logs, hasLength(1));
      expect(logs.single['order_id'], orderId);
      expect(logs.single['customer_id'], customerId);
      expect(logs.single['quantity_delivered'], 4);
      expect(logs.single['staff_id'], 3);
      expect(logs.single['notes'], 'Provider completion');

      final repeatedCompletion = await provider.updateStatus(
        orderId,
        'completed',
      );

      expect(repeatedCompletion, isTrue);
      expect(provider.error, isNull);
      expect(await helper.getDeliveryLogsForOrder(orderId), hasLength(1));
    },
  );

  test('updateStatus returns false when no order rows are affected', () async {
    final provider = OrderProvider(OrderRepository());

    final updated = await provider.updateStatus(999999, 'confirmed');

    expect(updated, isFalse);
    expect(provider.error, 'No order was updated.');

    provider.dispose();
  });

  test('loadOrders exposes upcoming pre-booked orders', () async {
    final helper = DatabaseHelper.instance;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final futureDate = startOfToday.add(const Duration(days: 3));

    final orderId = await helper.insertOrder({
      'phone_number': '09189990000',
      'type': 'deliver',
      'quantity': 2,
      'status': 'pending',
      'created_at': today.toIso8601String(),
      'delivery_day': 'Friday',
      'scheduled_for': futureDate.toIso8601String(),
      'is_pre_book': 1,
      'source': 'prebook',
    });

    final provider = OrderProvider(OrderRepository());
    await provider.loadOrders();

    expect(provider.error, isNull);
    expect(
      provider.todayOrders.where((order) => order['id'] == orderId),
      isEmpty,
    );
    expect(provider.upcomingPreBookOrders, hasLength(1));
    expect(provider.upcomingPreBookOrders.single['id'], orderId);

    provider.dispose();
  });
}
