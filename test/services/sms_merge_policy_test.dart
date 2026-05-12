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

  test('unregistered first contact gets welcome and privacy notice only', () async {
    const sender = '+63 917 100 0001';
    const normalized = '09171000001';
    const sourceMessageId = 'first-contact-unregistered';

    await SmsBackgroundService.instance.processIncomingSmsPayloadForTesting(
      sender: sender,
      message: 'hello',
      timestamp: DateTime(2026, 5, 11, 9).millisecondsSinceEpoch,
      sourceMessageId: sourceMessageId,
    );

    final outgoing = await outgoingFor(normalized);
    expect(outgoing, hasLength(1));
    final reply = outgoing.single['message'] as String;
    expect(reply, contains(SmsRegistrationCopy.firstContactWelcome));
    expect(reply, contains(SmsRegistrationCopy.firstContactPrivacyNotice));
    expect(await helper.isFirstContactNotified(sender), isTrue);
    expect(await helper.getOrders(), isEmpty);
    final receipt = await helper.getIncomingSmsReceipt(sourceMessageId);
    expect(receipt!['status'], 'completed');
  });

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

    final outgoing = await outgoingFor(normalized);
    expect(outgoing, hasLength(1));
    expect(outgoing.single['status'], 'failed');
  });
}
