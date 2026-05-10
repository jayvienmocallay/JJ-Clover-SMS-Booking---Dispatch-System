import 'package:flutter_test/flutter_test.dart';
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

  test('repository returns customer order history by normalized phone', () async {
    final helper = DatabaseHelper.instance;
    final repository = OrderRepository();

    await helper.insertOrder({
      'phone_number': '+63 917 111 2222',
      'type': 'drop',
      'quantity': 1,
      'gallon_type': 'new',
      'status': 'pending',
      'created_at': DateTime(2026, 5, 1, 8).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });
    await helper.insertOrder({
      'phone_number': '09179990000',
      'type': 'drop',
      'quantity': 1,
      'gallon_type': 'new',
      'status': 'pending',
      'created_at': DateTime(2026, 5, 1, 9).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });

    final rows = await repository.getCustomerOrderHistory('09171112222');

    expect(rows, hasLength(1));
    expect(rows.single['phone_number'], '09171112222');
  });

  test('repository separates invalid SMS orders for review', () async {
    final helper = DatabaseHelper.instance;
    final repository = OrderRepository();

    final invalidId = await helper.insertOrder({
      'phone_number': '09170001111',
      'type': 'unrecognized',
      'quantity': 0,
      'status': 'pending',
      'cancel_reason': 'Random message',
      'created_at': DateTime(2026, 5, 1, 8).toIso8601String(),
      'is_pre_book': 0,
      'source': 'sms',
    });
    await helper.insertOrder({
      'phone_number': '09170002222',
      'type': 'drop',
      'quantity': 1,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 1, 9).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });

    final rows = await repository.getInvalidSmsOrders();

    expect(rows, hasLength(1));
    expect(rows.single['id'], invalidId);
    expect(rows.single['type'], 'unrecognized');
    expect(rows.single['source'], 'sms');
  });

  test('repository review queue includes invalid, cancelled, and rejected orders', () async {
    final helper = DatabaseHelper.instance;
    final repository = OrderRepository();

    final invalidId = await helper.insertOrder({
      'phone_number': '09170003333',
      'type': 'unrecognized',
      'quantity': 0,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 1, 8).toIso8601String(),
      'is_pre_book': 0,
      'source': 'sms',
    });
    final rejectedId = await helper.insertOrder({
      'phone_number': '09170004444',
      'type': 'deliver',
      'quantity': 2,
      'status': 'rejected',
      'created_at': DateTime(2026, 5, 1, 9).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });
    final completedId = await helper.insertOrder({
      'phone_number': '09170005555',
      'type': 'deliver',
      'quantity': 2,
      'status': 'completed',
      'created_at': DateTime(2026, 5, 1, 10).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });

    final rows = await repository.getOrdersNeedingReview();
    final ids = rows.map((row) => row['id']).toSet();

    expect(ids, contains(invalidId));
    expect(ids, contains(rejectedId));
    expect(ids, isNot(contains(completedId)));
  });
}
