import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/command_handlers/sms_handler_utils.dart';
import 'package:jj_clover_sms/data/services/sms_background_service.dart';
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

  Future<void> insertReceipt({
    required String messageId,
    required String status,
    required int attempts,
    DateTime? claimedAt,
    String message = 'hello',
  }) async {
    final now = DateTime(2026, 5, 13, 10);
    await db.insert('incoming_sms_receipts', {
      'message_id': messageId,
      'phone_number': '09171234567',
      'message': message,
      'sms_timestamp': now.millisecondsSinceEpoch,
      'status': status,
      'attempts': attempts,
      'received_at': now.toIso8601String(),
      'claimed_at': (claimedAt ?? now).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'last_error': status == 'failed' ? 'previous failure' : null,
    });
  }

  test(
    'foreground processing failures are recorded without uncaught async errors',
    () async {
      const sourceMessageId = 'foreground-failure-receipt';
      final helper = DatabaseHelper.instance;
      final service = SmsBackgroundService.instance;
      final uncaughtErrors = <Object>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() {
        debugPrint = previousDebugPrint;
      });

      // Mark schema integrity as checked, then remove a table to force a
      // deterministic failure after the incoming receipt has been claimed.
      await helper.database;
      await db.execute('DROP TABLE sms_messages');

      await runZonedGuarded<Future<void>>(
        () async {
          await service.guardForegroundSmsProcessingForTesting(
            service.processIncomingSmsPayloadForTesting(
              sender: '+63 917 123 4567',
              message: 'badly malformed SMS payload',
              timestamp: DateTime(2026, 4, 26, 12).millisecondsSinceEpoch,
              subscriptionId: 1,
              sourceMessageId: sourceMessageId,
            ),
          );
        },
        (error, stackTrace) {
          uncaughtErrors.add(error);
        },
      );

      expect(uncaughtErrors, isEmpty);

      final receipt = await helper.getIncomingSmsReceipt(sourceMessageId);
      expect(receipt, isNotNull);
      expect(receipt!['status'], 'failed');
      expect(receipt['last_error'].toString(), contains('sms_messages'));
    },
  );

  test('failed incoming receipt is retried and completed', () async {
    const sourceMessageId = 'failed-retry-receipt';
    await insertReceipt(
      messageId: sourceMessageId,
      status: 'failed',
      attempts: 1,
    );

    final retried = await SmsBackgroundService.instance
        .retryPendingReceiptsForTesting();
    await SmsHandlerUtils.waitForPendingRepliesForTesting();

    expect(retried, 1);
    final receipt = await DatabaseHelper.instance.getIncomingSmsReceipt(
      sourceMessageId,
    );
    expect(receipt!['status'], 'completed');
    expect(receipt['attempts'], 2);
    expect(receipt['last_error'], isNull);
  });

  test('stale processing receipt is retried', () async {
    const sourceMessageId = 'stale-processing-retry';
    await insertReceipt(
      messageId: sourceMessageId,
      status: 'processing',
      attempts: 1,
      claimedAt: DateTime.now().subtract(const Duration(minutes: 11)),
    );

    final retried = await SmsBackgroundService.instance
        .retryPendingReceiptsForTesting();
    await SmsHandlerUtils.waitForPendingRepliesForTesting();

    expect(retried, 1);
    final receipt = await DatabaseHelper.instance.getIncomingSmsReceipt(
      sourceMessageId,
    );
    expect(receipt!['status'], 'completed');
    expect(receipt['attempts'], 2);
  });

  test(
    'stale processing receipt at max attempts is finalized as failed',
    () async {
      const sourceMessageId = 'stale-processing-exhausted';
      await insertReceipt(
        messageId: sourceMessageId,
        status: 'processing',
        attempts: 3,
        claimedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      );

      final retried = await SmsBackgroundService.instance
          .retryPendingReceiptsForTesting();

      expect(retried, 0);
      final receipt = await DatabaseHelper.instance.getIncomingSmsReceipt(
        sourceMessageId,
      );
      expect(receipt!['status'], 'failed');
      expect(receipt['attempts'], 3);
      expect(receipt['last_error'], contains('exceeded 3 attempts'));
    },
  );
}
