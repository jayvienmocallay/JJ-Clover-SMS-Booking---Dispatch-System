import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
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

  // --- SMS reply queue with throttling ---
  // Prevents overwhelming the Android SMS API when multiple customers
  // text at the same time by spacing out outgoing replies.

  /// Minimum delay between consecutive SMS sends.
  static const Duration _sendDelay = Duration(seconds: 15);

  /// FIFO queue of pending outgoing SMS replies.
  static final Queue<_QueuedReply> _replyQueue = Queue<_QueuedReply>();

  /// Whether the queue is currently being drained.
  static bool _isSending = false;

  /// Queues an SMS reply for sending. Replies are sent sequentially with
  /// a [_sendDelay] gap between each send to avoid Android SMS rate limits.
  static Future<void> sendReply(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
  }) async {
    final completer = Completer<void>();
    _replyQueue.add(_QueuedReply(
      phoneNumber: phoneNumber,
      message: message,
      smsSender: smsSender,
      completer: completer,
    ));
    _drainQueue(); // Start draining if not already running
    return completer.future;
  }

  /// Processes the queue one item at a time, waiting [_sendDelay] between sends.
  static Future<void> _drainQueue() async {
    if (_isSending) return; // Already draining
    _isSending = true;

    while (_replyQueue.isNotEmpty) {
      final item = _replyQueue.removeFirst();
      try {
        await _doSend(
          item.phoneNumber,
          item.message,
          smsSender: item.smsSender,
        );
        item.completer.complete();
      } catch (e) {
        item.completer.completeError(e);
      }

      // Wait before sending the next one (skip delay if queue is empty)
      if (_replyQueue.isNotEmpty) {
        await Future<void>.delayed(_sendDelay);
      }
    }

    _isSending = false;
  }

  /// Actually sends the SMS and logs it. Called only by [_drainQueue].
  static Future<void> _doSend(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
  }) async {
    final telephony = smsSender ?? Telephony.instance;
    try {
      await telephony.sendSms(to: phoneNumber, message: message);
      debugPrint('Reply sent to $phoneNumber: $message');
      await _messages.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to send reply: $e');
      await _messages.insertSmsMessage({
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
      gallonType: gallonType,
      cancelReason: message,
      status: orderStatus,
      createdAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
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

/// Internal data class for a queued outgoing SMS reply.
class _QueuedReply {
  final String phoneNumber;
  final String message;
  final Telephony? smsSender;
  final Completer<void> completer;

  _QueuedReply({
    required this.phoneNumber,
    required this.message,
    this.smsSender,
    required this.completer,
  });
}
