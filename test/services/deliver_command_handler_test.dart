import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/constants/app_constants.dart';
import 'package:jj_clover_sms/core/utils/phone_number_utils.dart';
import 'package:jj_clover_sms/data/services/command_handlers/deliver_command_handler.dart';
import 'package:jj_clover_sms/data/services/command_handlers/sms_handler_utils.dart';
import 'package:jj_clover_sms/data/services/pre_book_store.dart';
import 'package:jj_clover_sms/data/services/sms_parser.dart';
import 'package:jj_clover_sms/data/services/system_mode_manager.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper helper;
  late PreBookStore preBookStore;
  late DeliverCommandHandler handler;

  const nativeSmsChannel = MethodChannel('com.jjclover.smartrelay/native_sms');
  const sender = '+63 917 555 2000';
  const sourceMessageId = 'deliver-staff-away-wrong-day';
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
    handler = DeliverCommandHandler(preBookStore);

    await helper.setSetting('system_mode', SystemMode.staffAway.name);
    await SystemModeManager.instance.loadPersistedMode(notify: false);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeSmsChannel, (_) async {
          return {'status': 'sent'};
        });
  });

  tearDown(() async {
    await SmsHandlerUtils.waitForPendingRepliesForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeSmsChannel, null);

    await helper.setSetting('system_mode', SystemMode.operating.name);
    await SystemModeManager.instance.loadPersistedMode(notify: false);

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
    'staff-away wrong-day delivery reply mentions staff and pre-book',
    () async {
      final todayIndex = DeliveryDays.days.indexOf(DeliveryDays.getToday());
      final nextDay =
          DeliveryDays.days[(todayIndex + 1) % DeliveryDays.days.length];
      final barangayId = await helper.insertBarangay({
        'name': 'Staff Away Test Barangay',
        'delivery_zone': 'Zone C',
        'delivery_day': nextDay,
      });
      await helper.insertCustomer({
        'name': 'Staff Away Customer',
        'contact_number': normalizedSender,
        'address': 'Purok 1',
        'barangay_id': barangayId,
        'consent_given': 1,
      });

      await handler.handle(
        sender,
        SmsParser.parse('DELIVER 5'),
        sourceMessageId: sourceMessageId,
      );
      await SmsHandlerUtils.waitForPendingRepliesForTesting();

      final outgoing = await outgoingFor(normalizedSender);
      expect(outgoing, hasLength(1));

      final reply = outgoing.single['message'] as String;
      expect(reply, contains('staff naa pa sa delivery'));
      expect(reply, contains('naka-iskedyul sa $nextDay'));
      expect(reply, contains('Tubaga ug YES'));

      final pendingPreBook = preBookStore[normalizedSender];
      expect(pendingPreBook, isNotNull);
      expect(pendingPreBook!.deliveryDay, nextDay);
      expect(pendingPreBook.quantity, 5);
    },
  );
}
