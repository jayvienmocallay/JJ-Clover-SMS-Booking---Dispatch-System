import 'dart:io';

import 'package:flutter/services.dart';

class NativeSmsSender {
  static const MethodChannel _channel = MethodChannel(
    'com.jjclover.smartrelay/native_sms',
  );

  static Future<void> sendSms({
    required String to,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod<void>('sendSms', {
        'to': to,
        'message': message,
      });
    } on MissingPluginException {
      if (_isFlutterTest) return;
      rethrow;
    }
  }

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      Platform.resolvedExecutable.contains('flutter_tester');
}
