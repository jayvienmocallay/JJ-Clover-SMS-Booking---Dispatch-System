import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/utils/phone_number_utils.dart';
import 'package:jj_clover_sms/data/models/pre_book_context.dart';
import 'package:jj_clover_sms/data/services/command_handlers/sms_handler_utils.dart';
import 'package:jj_clover_sms/data/services/command_handlers/yes_command_handler.dart';
import 'package:jj_clover_sms/data/services/pre_book_store.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper helper;
  late PreBookStore preBookStore;
  late YesCommandHandler handler;

  const nativeSmsChannel = MethodChannel('com.jjclover.smartrelay/native_sms');
  const sender = '+63 917 555 1000';
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
    handler = YesCommandHandler(preBookStore);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeSmsChannel, (_) async => null);
  });

  tearDown(() async {
    await SmsHandlerUtils.waitForPendingRepliesForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeSmsChannel, null);
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test('YES promotes the pending pre-book placeholder order', () async {
    final barangay = (await db.query('barangays', limit: 1)).single;
    final customerId = await helper.insertCustomer({
      'name': 'Prebook Customer',
      'contact_number': normalizedSender,
      'address': 'Purok 4',
      'barangay_id': barangay['id'],
      'consent_given': 1,
    });
    final originalCreatedAt = DateTime(2026, 5, 13, 21, 25);
    final pendingOrderId = await helper.insertOrder({
      'customer_id': customerId,
      'phone_number': sender,
      'type': 'unrecognized',
      'quantity': 5,
      'status': 'pending',
      'cancel_reason': 'DELIVER 5 - Wrong Day',
      'created_at': originalCreatedAt.toIso8601String(),
      'source_message_id': 'deliver-source',
      'source': 'sms',
    });

    await preBookStore.put(
      normalizedSender,
      PreBookContext(
        customerId: customerId,
        phoneNumber: normalizedSender,
        quantity: 5,
        address: 'Purok 4',
        deliveryDay: 'Thursday',
        scheduledFor: DateTime(2026, 5, 14),
        createdAt: originalCreatedAt,
        pendingOrderId: pendingOrderId,
      ),
    );

    await handler.handle(sender, sourceMessageId: 'yes-source');
    await SmsHandlerUtils.waitForPendingRepliesForTesting();

    final orders = await db.query('orders', orderBy: 'id ASC');
    expect(orders, hasLength(1));

    final order = orders.single;
    expect(order['id'], pendingOrderId);
    expect(order['type'], 'deliver');
    expect(order['status'], 'pending');
    expect(order['quantity'], 5);
    expect(order['is_pre_book'], 1);
    expect(order['delivery_day'], 'Thursday');
    expect(order['scheduled_for'], DateTime(2026, 5, 14).toIso8601String());
    expect(order['source'], 'prebook');
    expect(order['source_message_id'], 'yes-source');
    expect(order['cancel_reason'], isNull);
    expect(order['created_at'], originalCreatedAt.toIso8601String());
    expect(preBookStore[normalizedSender], isNull);
    expect(await helper.getPreBookPending(), isEmpty);
  });
}
