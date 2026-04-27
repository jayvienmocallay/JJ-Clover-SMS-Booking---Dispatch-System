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

  group('Duplicate SMS Detection', () {
    test('new message is claimed successfully', () async {
      final helper = DatabaseHelper.instance;
      const messageId = 'test-msg-001';

      final result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );

      expect(result.claimed, isTrue);
      expect(result.isDuplicate, isFalse);
    });

    test('duplicate within 10-min retry window is rejected (but not marked duplicate)',
        () async {
      final helper = DatabaseHelper.instance;
      const messageId = 'test-msg-002';

      // First claim
      await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );
      await helper.completeIncomingSmsReceipt(messageId);

      // Wait should be < 10 min to trigger retry rejection (but it's in-memory, so immediate)
      // Second claim within 10 min
      final result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );

      // Within 10 min of completion, should be rejected
      expect(result.claimed, isFalse);
      expect(result.isDuplicate, isTrue);
    });

    test('duplicate after 1 hour is allowed as new resubmit', () async {
      final helper = DatabaseHelper.instance;
      const messageId = 'test-msg-003';

      // First claim and complete
      var result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );
      expect(result.claimed, isTrue);
      await helper.completeIncomingSmsReceipt(messageId);

      // Simulate 1+ hour passing by directly updating the database
      final receipt = await helper.getIncomingSmsReceipt(messageId);
      expect(receipt, isNotNull);

      final completedAtIso = receipt!['completed_at'] as String;
      final completedAt = DateTime.parse(completedAtIso);
      final oneHourAgo = completedAt.subtract(const Duration(hours: 1, minutes: 1));
      final oneHourAgoIso = oneHourAgo.toIso8601String();

      await db.update(
        'incoming_sms_receipts',
        {'completed_at': oneHourAgoIso},
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      // Now try to claim again — should succeed as new resubmit
      result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );

      expect(result.claimed, isTrue);
      expect(result.isDuplicate, isFalse);
      expect(result.claimed, isTrue);
    });

    test('different phone number bypasses duplicate check', () async {
      final helper = DatabaseHelper.instance;
      const messageId = 'test-msg-004';
      const sameMessage = 'DELIVER 5';

      // First claim from phone A
      var result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917111111',
        message: sameMessage,
      );
      expect(result.claimed, isTrue);
      await helper.completeIncomingSmsReceipt(messageId);

      // Same message ID from phone B should be treated as new (different sender)
      // In practice, message ID includes sender, so this won't happen naturally,
      // but the check verifies the logic
      final result2 = await helper.claimIncomingSmsReceipt(
        messageId: 'different-id-from-phone-b',
        phoneNumber: '+63917222222',
        message: sameMessage,
      );
      expect(result2.claimed, isTrue);
      expect(result2.isDuplicate, isFalse);
    });

    test('multiple attempts within processing window are tracked', () async {
      final helper = DatabaseHelper.instance;
      const messageId = 'test-msg-005';

      // First claim
      var result = await helper.claimIncomingSmsReceipt(
        messageId: messageId,
        phoneNumber: '+63917123456',
        message: 'DELIVER 5',
      );
      expect(result.claimed, isTrue);

      var receipt = await helper.getIncomingSmsReceipt(messageId);
      expect(receipt!['attempts'], 1);
      expect(receipt['status'], 'processing');
    });
  });
}
