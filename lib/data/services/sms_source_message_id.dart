import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/utils/phone_number_utils.dart';

class SmsSourceMessageId {
  const SmsSourceMessageId._();

  static String build({
    required String sender,
    required String message,
    int? timestamp,
    int? subscriptionId,
  }) {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final senderKey = normalizedSender.isEmpty
        ? sender.trim()
        : normalizedSender;
    final bodyHash = sha256.convert(utf8.encode(message)).toString();
    return '$senderKey|${timestamp ?? -1}|${subscriptionId ?? -1}|$bodyHash';
  }
}
