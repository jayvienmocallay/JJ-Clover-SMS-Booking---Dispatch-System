import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/native_sms_sender.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.jjclover.smartrelay/native_sms';
  const channel = MethodChannel(channelName);
  const codec = StandardMethodCodec();

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  Future<void> emitNativeStatus(Map<String, Object?> args) async {
    final completer = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channelName,
          codec.encodeMethodCall(MethodCall('smsStatusChanged', args)),
          completer.complete,
        );
    await completer.future;
  }

  test('sendTrackedSms maps queued native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'sendSms');
          return {'status': 'queued'};
        });

    final result = await NativeSmsSender.sendTrackedSms(
      to: '09171234567',
      message: 'hello',
      sourceMessageId: 'reply-source',
    );

    expect(result.status, SmsSendStatus.queued);
    expect(result.failed, isFalse);
  });

  test('sendTrackedSms maps native failures without throwing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return {
            'status': 'failed',
            'errorCode': 'no_service',
            'errorMessage': 'No service',
          };
        });

    final result = await NativeSmsSender.sendTrackedSms(
      to: '09171234567',
      message: 'hello',
      sourceMessageId: 'reply-source',
    );

    expect(result.status, SmsSendStatus.failed);
    expect(result.errorCode, 'no_service');
    expect(result.errorMessage, 'No service');
  });

  test(
    'native status callbacks update SMS message status by source id',
    () async {
      const sourceMessageId = 'reply-status-source';
      await db.insert('sms_messages', {
        'phone_number': '09171234567',
        'message': 'reply',
        'direction': 'outgoing',
        'status': 'queued',
        'source_message_id': sourceMessageId,
        'sent_at': DateTime(2026, 5, 13, 10).toIso8601String(),
      });

      await NativeSmsSender.ensureStatusMonitoring();
      await emitNativeStatus({
        'sourceMessageId': sourceMessageId,
        'status': 'sent',
      });
      await emitNativeStatus({
        'sourceMessageId': sourceMessageId,
        'status': 'delivered',
      });

      final rows = await db.query(
        'sms_messages',
        where: 'source_message_id = ?',
        whereArgs: [sourceMessageId],
      );
      expect(rows.single['status'], 'delivered');
    },
  );
}
