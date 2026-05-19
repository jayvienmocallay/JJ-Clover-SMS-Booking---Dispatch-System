import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/command_handlers/sms_handler_utils.dart';
import 'package:jj_clover_sms/data/services/sms_background_service.dart';
import 'package:jj_clover_sms/data/services/sms_registration_copy.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper helper;
  const channel = MethodChannel('com.jjclover.smartrelay/native_sms');

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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  Future<List<Map<String, dynamic>>> outgoingFor(String phone) {
    return db.query(
      'sms_messages',
      where: 'phone_number = ? AND direction = ?',
      whereArgs: [phone, 'outgoing'],
      orderBy: 'sent_at ASC',
    );
  }

  test(
    'unregistered first contact gets welcome and privacy notice only',
    () async {
      const sender = '+63 917 100 0001';
      const normalized = '09171000001';
      const sourceMessageId = 'first-contact-unregistered';

      await SmsBackgroundService.instance.processIncomingSmsPayloadForTesting(
        sender: sender,
        message: 'hello',
        timestamp: DateTime(2026, 5, 11, 9).millisecondsSinceEpoch,
        sourceMessageId: sourceMessageId,
      );

      await SmsHandlerUtils.waitForPendingRepliesForTesting();

      final outgoing = await outgoingFor(normalized);
      expect(outgoing, hasLength(1));
      final reply = outgoing.single['message'] as String;
      expect(reply, contains(SmsRegistrationCopy.firstContactWelcome));
      expect(reply, contains(SmsRegistrationCopy.firstContactPrivacyNotice));
      expect(await helper.isFirstContactNotified(sender), isTrue);
      expect(await helper.getOrders(), isEmpty);
      final receipt = await helper.getIncomingSmsReceipt(sourceMessageId);
      expect(receipt!['status'], 'completed');
    },
  );

  test(
    'unregistered first-contact DROP still creates order and alarm',
    () async {
      const sender = '+63 917 100 0002';
      const normalized = '09171000002';
      const sourceMessageId = 'first-contact-drop';

      await SmsBackgroundService.instance.processIncomingSmsPayloadForTesting(
        sender: sender,
        message: 'DROP 2',
        timestamp: DateTime(2026, 5, 11, 10).millisecondsSinceEpoch,
        sourceMessageId: sourceMessageId,
      );

      await SmsHandlerUtils.waitForPendingRepliesForTesting();

      final outgoing = await outgoingFor(normalized);
      expect(outgoing, hasLength(1));
      final reply = outgoing.single['message'] as String;
      expect(reply, contains(SmsRegistrationCopy.firstContactWelcome));
      expect(reply, contains(SmsRegistrationCopy.firstContactPrivacyNotice));

      final orders = await helper.getOrders();
      expect(orders, hasLength(1));
      expect(orders.single['phone_number'], normalized);
      expect(orders.single['type'], 'drop');
      expect(orders.single['quantity'], 2);

      final alarmRaw = await helper.getSetting('active_drop_alarm');
      expect(alarmRaw, isNotNull);
      final alarm = jsonDecode(alarmRaw!) as Map<String, dynamic>;
      expect(alarm['phone'], normalized);
      expect(alarm['quantity'], 2);

      expect(await helper.isFirstContactNotified(sender), isTrue);
      final receipt = await helper.getIncomingSmsReceipt(sourceMessageId);
      expect(receipt!['status'], 'completed');
    },
  );

  test('reply logging records failed status when native send fails', () async {
    const phone = '+63 917 100 0003';
    const normalized = '09171000003';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'forced_failure');
        });

    await SmsHandlerUtils.sendReply(
      phone,
      'failed reply',
      sourceMessageId: 'failed-source',
    );

    await SmsHandlerUtils.waitForPendingRepliesForTesting();
    final outgoing = await outgoingFor(normalized);
    expect(outgoing, hasLength(1));
    expect(outgoing.single['status'], 'failed');
  });

  test('queue continues draining after a failed send', () async {
    const phone = '+63 917 100 0004';
    const normalized = '09171000004';

    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          callCount++;
          if (callCount == 1) throw PlatformException(code: 'forced_failure');
          return null;
        });

    await SmsHandlerUtils.sendReply(
      phone,
      'first reply',
      sourceMessageId: 'queue-source-1',
    );
    await SmsHandlerUtils.sendReply(
      phone,
      'second reply',
      sourceMessageId: 'queue-source-2',
    );

    await SmsHandlerUtils.waitForPendingRepliesForTesting();

    final outgoing = await outgoingFor(normalized);
    expect(outgoing, hasLength(2));
    expect(outgoing.map((r) => r['status']), containsAll(['failed', 'sent']));
  });

  test('rejection message includes reason when provided', () {
    final message = SmsHandlerUtils.buildOrderRejectedMessage(
      quantity: 3,
      reason: 'Outside delivery area',
    );

    expect(message, contains('water order (3 gallons) was rejected'));
    expect(message, contains('Reason: Outside delivery area.'));
  });

  test('rejection message omits reason when not provided', () {
    final message = SmsHandlerUtils.buildOrderRejectedMessage(quantity: 1);

    expect(message, contains('water order (1 gallon) was rejected'));
    expect(message, isNot(contains('Reason:')));
  });

  test(
    'fire-and-forget reply does not cause uncaught async test errors',
    () async {
      const phone = '+63 917 100 0005';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'forced_failure');
          });

      // fire-and-forget: sendReply returns Future.value() immediately
      unawaited(
        SmsHandlerUtils.sendReply(
          phone,
          'fire-and-forget reply',
          sourceMessageId: 'ff-source',
        ).catchError((Object e, StackTrace st) {
          // defensive: should never fire since sendReply returns Future.value()
        }),
      );

      // draining must complete without throwing into the test zone
      await SmsHandlerUtils.waitForPendingRepliesForTesting();
      // reaching here means no uncaught error escaped
    },
  );

  test(
    'registered first contact gets only welcome and returns early',
    () async {
      const sender = '+63 917 100 0006';
      const normalized = '09171000006';
      const sourceMessageId = 'first-contact-registered';

      // insert a customer so the sender is registered
      final barangays = await db.query('barangays', limit: 1);
      final barangayId = barangays.first['id'] as int;
      await db.insert('customers', {
        'name': 'Test Customer',
        'contact_number': normalized,
        'barangay_id': barangayId,
        'consent_given': 1,
      });

      await SmsBackgroundService.instance.processIncomingSmsPayloadForTesting(
        sender: sender,
        message: 'hello',
        timestamp: DateTime(2026, 5, 12, 10).millisecondsSinceEpoch,
        sourceMessageId: sourceMessageId,
      );

      await SmsHandlerUtils.waitForPendingRepliesForTesting();

      final outgoing = await outgoingFor(normalized);
      expect(outgoing, hasLength(1));
      final reply = outgoing.single['message'] as String;
      expect(reply, contains(SmsRegistrationCopy.firstContactWelcome));
      expect(
        reply,
        isNot(contains(SmsRegistrationCopy.firstContactPrivacyNotice)),
      );
      expect(await helper.isFirstContactNotified(sender), isTrue);
      // first-contact returns early: no order created
      expect(await helper.getOrders(), isEmpty);
      final receipt = await helper.getIncomingSmsReceipt(sourceMessageId);
      expect(receipt!['status'], 'completed');
    },
  );
}
