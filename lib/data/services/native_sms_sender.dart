import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../repositories/sms_message_repository.dart';
import 'app_event_bus.dart';

enum SmsSendStatus {
  queued,
  sent,
  delivered,
  failed;

  static SmsSendStatus fromName(String? value) {
    return SmsSendStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SmsSendStatus.failed,
    );
  }
}

class SmsSendResult {
  final SmsSendStatus status;
  final String? errorCode;
  final String? errorMessage;

  const SmsSendResult({
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  bool get failed => status == SmsSendStatus.failed;

  factory SmsSendResult.fromNative(Object? value) {
    if (value == null) {
      return const SmsSendResult(status: SmsSendStatus.sent);
    }
    if (value is! Map) {
      return const SmsSendResult(
        status: SmsSendStatus.failed,
        errorCode: 'invalid_native_sms_result',
        errorMessage: 'Native SMS result must be a map.',
      );
    }

    final result = Map<Object?, Object?>.from(value);
    return SmsSendResult(
      status: SmsSendStatus.fromName(result['status']?.toString()),
      errorCode: result['errorCode']?.toString(),
      errorMessage: result['errorMessage']?.toString(),
    );
  }

  factory SmsSendResult.platformFailure(PlatformException error) {
    return SmsSendResult(
      status: SmsSendStatus.failed,
      errorCode: error.code,
      errorMessage: error.message,
    );
  }
}

class NativeSmsSender {
  static const MethodChannel _channel = MethodChannel(
    'com.jjclover.smartrelay/native_sms',
  );

  static final SmsMessageRepository _messages = SmsMessageRepository();
  static bool _statusHandlerReady = false;

  static Future<void> ensureStatusMonitoring() async {
    if (_statusHandlerReady) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'smsStatusChanged':
          await _handleSmsStatusChanged(call.arguments);
          return true;
        default:
          throw MissingPluginException(
            'Unknown native SMS method: ${call.method}',
          );
      }
    });
    _statusHandlerReady = true;

    if (!_isFlutterTest) {
      try {
        await _channel.invokeMethod<void>('smsStatusListenerReady');
      } on MissingPluginException {
        // Older native builds do not expose status buffering.
      } on PlatformException catch (e) {
        debugPrint('Unable to mark native SMS status listener ready: $e');
      }
    }
  }

  static Future<SmsSendResult> sendTrackedSms({
    required String to,
    required String message,
    String? sourceMessageId,
  }) async {
    await ensureStatusMonitoring();

    try {
      final args = <String, Object>{'to': to, 'message': message};
      if (sourceMessageId != null) {
        args['sourceMessageId'] = sourceMessageId;
      }
      final result = await _channel
          .invokeMethod<Object?>('sendSms', args)
          .timeout(const Duration(seconds: 10));
      return SmsSendResult.fromNative(result);
    } on MissingPluginException {
      if (_isFlutterTest) {
        return const SmsSendResult(status: SmsSendStatus.sent);
      }
      rethrow;
    } on PlatformException catch (e) {
      return SmsSendResult.platformFailure(e);
    } on TimeoutException {
      return const SmsSendResult(
        status: SmsSendStatus.failed,
        errorCode: 'sms_send_timeout',
        errorMessage: 'Timed out waiting for native SMS sender.',
      );
    }
  }

  static Future<void> sendSms({
    required String to,
    required String message,
    String? sourceMessageId,
  }) async {
    final result = await sendTrackedSms(
      to: to,
      message: message,
      sourceMessageId: sourceMessageId,
    );
    if (result.failed) {
      throw PlatformException(
        code: result.errorCode ?? 'sms_send_failed',
        message: result.errorMessage,
      );
    }
  }

  static Future<void> _handleSmsStatusChanged(Object? rawArgs) async {
    if (rawArgs is! Map) return;

    final args = Map<Object?, Object?>.from(rawArgs);
    final sourceMessageId = args['sourceMessageId']?.toString();
    final status = SmsSendStatus.fromName(args['status']?.toString());
    if (sourceMessageId == null || sourceMessageId.isEmpty) return;

    try {
      await _messages.updateSmsMessageStatusBySourceMessageId(
        sourceMessageId,
        status.name,
      );
      AppEventBus().notifyMessageReceived();
    } catch (e, st) {
      debugPrint('Unable to record SMS status update: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      Platform.resolvedExecutable.contains('flutter_tester');
}
