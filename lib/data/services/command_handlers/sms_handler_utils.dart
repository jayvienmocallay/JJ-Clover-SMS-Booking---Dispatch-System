import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../models/order_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/sms_message_repository.dart';
import '../app_event_bus.dart';
import '../push_notification_service.dart';

/// Static utilities shared across all SMS command handlers.
class SmsHandlerUtils {
  static final _customers = CustomerRepository();
  static final _messages = SmsMessageRepository();
  static final _orders = OrderRepository();

  /// Sends an SMS reply immediately and records the send result.
  static Future<void> sendReply(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
    String? sourceMessageId,
  }) async {
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final outgoingSourceMessageId = _outgoingSourceMessageId(
      sourceMessageId,
      message,
    );

    try {
      await _doSend(phoneNumber, message, smsSender: smsSender);
      await _insertOutgoingMessage(
        phoneNumber: normalizedPhone,
        message: message,
        status: 'sent',
        sourceMessageId: outgoingSourceMessageId,
      );
    } catch (e, st) {
      debugPrint('SMS reply send failed for $phoneNumber: $e');
      debugPrintStack(stackTrace: st);
      await _insertOutgoingMessage(
        phoneNumber: normalizedPhone,
        message: message,
        status: 'failed',
        sourceMessageId: outgoingSourceMessageId,
      );
    } finally {
      AppEventBus().notifyMessageReceived();
    }
  }

  static Future<void> _insertOutgoingMessage({
    required String phoneNumber,
    required String message,
    required String status,
    required String? sourceMessageId,
  }) async {
    try {
      await _messages.insertSmsMessage({
        'phone_number': phoneNumber,
        'message': message,
        'direction': 'outgoing',
        'status': status,
        'source_message_id': sourceMessageId,
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('Failed to record outgoing SMS as $status: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  static String? _outgoingSourceMessageId(String? incomingSourceMessageId, String message) {
    if (incomingSourceMessageId == null || incomingSourceMessageId.isEmpty) {
      return null;
    }
    final hash = message.hashCode.toRadixString(16);
    return 'reply|$incomingSourceMessageId|$hash';
  }

  static Future<void> _doSend(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
  }) async {
    final telephony = smsSender ?? Telephony.instance;
    await telephony.sendSms(to: phoneNumber, message: message);
    debugPrint('Reply sent to $phoneNumber: $message');
  }

  /// Saves a message that couldn't be processed as a regular order so it
  /// remains visible in the Messages / Unrecognized tab.
  static Future<void> saveUnrecognized(
    String sender,
    String message,
    String status, {
    String? sourceMessageId,
    int quantity = 0,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final customerData = await _customers.getCustomerByPhone(normalizedSender);
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
      cancelReason: message,
      status: orderStatus,
      createdAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
      source: 'sms',
    );
    await _orders.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showMessageNotification(
      title: 'Unrecognized Message',
      body: '$status from $sender',
      sender: sender,
    );
    debugPrint('Saved unrecognized message from $normalizedSender: $status');
  }
}
