import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../../database_helper.dart';
import '../../models/order_model.dart';
import '../app_event_bus.dart';
import '../push_notification_service.dart';

/// Static utilities shared across all SMS command handlers.
class SmsHandlerUtils {
  /// Sends an SMS reply, logs it to the outgoing message history, and
  /// swallows errors so a send failure never crashes the background service.
  static Future<void> sendReply(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
  }) async {
    final telephony = smsSender ?? Telephony.instance;
    try {
      await telephony.sendSms(to: phoneNumber, message: message);
      debugPrint('Reply sent to $phoneNumber: $message');
      await DatabaseHelper.instance.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to send reply: $e');
      await DatabaseHelper.instance.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'failed',
        'sent_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Saves a message that couldn't be processed as a regular order so it
  /// remains visible in the Messages / Unrecognized tab.
  static Future<void> saveUnrecognized(
    String sender,
    String message,
    String status, {
    String? sourceMessageId,
    int quantity = 0,
    GallonType? gallonType,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final customerData =
        await DatabaseHelper.instance.getCustomerByPhone(normalizedSender);
    final customerId = customerData?['id'] as int?;

    final OrderStatus orderStatus;
    switch (status) {
      case 'rejected':
        orderStatus = OrderStatus.rejected;
        break;
      case 'Unregistered':
      case 'Incomplete':
      case 'prebook':
        orderStatus = OrderStatus.pending;
        break;
      default:
        orderStatus = OrderStatus.rejected;
    }

    final order = Order(
      customerId: customerId,
      phoneNumber: normalizedSender,
      type: OrderType.unrecognized,
      quantity: quantity,
      gallonType: gallonType,
      cancelReason: message,
      status: orderStatus,
      createdAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
    );
    await DatabaseHelper.instance.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showMessageNotification(
      title: 'Unrecognized Message',
      body: '$status from $sender',
      sender: sender,
    );
    debugPrint('Saved unrecognized message from $normalizedSender: $status');
  }

  /// Maps the parser's lowercase gallon-type string to the model enum.
  static GallonType? mapGallonType(String? gallonTypeStr) {
    switch (gallonTypeStr) {
      case 'new':
        return GallonType.newGallon;
      case 'old':
        return GallonType.oldGallon;
      default:
        return null;
    }
  }
}
