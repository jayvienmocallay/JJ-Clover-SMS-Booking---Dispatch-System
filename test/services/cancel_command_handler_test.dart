import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/utils/phone_number_utils.dart';
import 'package:jj_clover_sms/data/models/pre_book_context.dart';
import 'package:jj_clover_sms/data/services/command_handlers/cancel_command_handler.dart';
import 'package:jj_clover_sms/data/services/pre_book_store.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper helper;
  late PreBookStore preBookStore;
  late CancelCommandHandler handler;

  const sender = '+63 917 555 0000';
  const sourceMessageId = 'test-cancel-source-message';
  final normalizedSender = PhoneNumberUtils.normalize(sender);

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
    helper = DatabaseHelper.instance;
    preBookStore = PreBookStore();
    handler = CancelCommandHandler(preBookStore);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test(
    'cancels the latest pending or confirmed order for the sender',
    () async {
      final olderOrderId = await helper.insertOrder({
        'phone_number': sender,
        'type': 'deliver',
        'quantity': 2,
        'status': 'pending',
        'created_at': DateTime(2026, 5, 7, 8).toIso8601String(),
        'is_pre_book': 0,
      });
      final latestOrderId = await helper.insertOrder({
        'phone_number': sender,
        'type': 'deliver',
        'quantity': 3,
        'status': 'confirmed',
        'created_at': DateTime(2026, 5, 7, 9).toIso8601String(),
        'is_pre_book': 0,
      });

      await handler.handle(sender, sourceMessageId: sourceMessageId);

      final olderOrder = (await helper.getOrders(
        where: 'id = ?',
        whereArgs: [olderOrderId],
      )).single;
      final latestOrder = (await helper.getOrders(
        where: 'id = ?',
        whereArgs: [latestOrderId],
      )).single;

      expect(olderOrder['status'], 'pending');
      expect(latestOrder['status'], 'cancelled');
      expect(latestOrder['cancel_reason'], 'Cancelled via SMS by customer');
    },
  );

  test('does not cancel when the latest active order is in transit', () async {
    final olderOrderId = await helper.insertOrder({
      'phone_number': sender,
      'type': 'deliver',
      'quantity': 2,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 7, 8).toIso8601String(),
      'is_pre_book': 0,
    });
    final latestOrderId = await helper.insertOrder({
      'phone_number': sender,
      'type': 'deliver',
      'quantity': 3,
      'status': 'in_transit',
      'created_at': DateTime(2026, 5, 7, 9).toIso8601String(),
      'is_pre_book': 0,
    });

    await handler.handle(sender, sourceMessageId: sourceMessageId);

    final olderOrder = (await helper.getOrders(
      where: 'id = ?',
      whereArgs: [olderOrderId],
    )).single;
    final latestOrder = (await helper.getOrders(
      where: 'id = ?',
      whereArgs: [latestOrderId],
    )).single;

    expect(olderOrder['status'], 'pending');
    expect(latestOrder['status'], 'in_transit');
  });

  test('clears a pending pre-book when no active order exists', () async {
    await preBookStore.put(
      normalizedSender,
      PreBookContext(
        customerId: 1,
        phoneNumber: normalizedSender,
        quantity: 4,
        deliveryDay: 'Friday',
      ),
    );

    await handler.handle(sender, sourceMessageId: sourceMessageId);

    expect(preBookStore[normalizedSender], isNull);
    expect(await helper.getPreBookPending(), isEmpty);
  });
}
