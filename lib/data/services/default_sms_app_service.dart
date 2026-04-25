import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class DefaultSmsAppService {
  static const _channel = MethodChannel('com.jjclover.smartrelay/default_sms');

  static Future<bool> isDefaultSmsApp() async {
    if (kIsWeb) return true;

    try {
      return await _channel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> requestDefaultSmsApp() async {
    if (kIsWeb) return true;

    try {
      return await _channel.invokeMethod<bool>('requestDefaultSmsApp') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
