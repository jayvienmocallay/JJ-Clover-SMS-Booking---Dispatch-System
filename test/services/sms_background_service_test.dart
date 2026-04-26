import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
