import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../models/order_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/sms_message_repository.dart';
import '../app_event_bus.dart';
import '../native_sms_sender.dart';
import '../push_notification_service.dart';

/// Static utilities shared across all SMS command handlers.
class SmsHandlerUtils {
  static final _customers = CustomerRepository();
  static final _messages = SmsMessageRepository();
  static final _orders = OrderRepository();

  static const Duration _sendDelay = Duration(seconds: 2);
  static final Queue<_QueuedReply> _replyQueue = Queue<_QueuedReply>();
  static bool _isSending = false;

  /// Queues an SMS reply for sending and records the final send status.
  ///
  /// By default this returns after queueing so command/database processing is
  /// not blocked by Android SMS delivery or MethodChannel behavior. Tests and
  /// explicit send flows can pass [waitForSend] when they need the final log
  /// status before continuing.
  static Future<void> sendReply(
    String phoneNumber,
    String message, {
    String? sourceMessageId,
    bool waitForSend = false,
  }) {
    final completer = Completer<void>();
    final outgoingSourceMessageId = _outgoingSourceMessageId(
      sourceMessageId,
      message,
    );

    _replyQueue.add(
      _QueuedReply(
        phoneNumber: phoneNumber,
        message: message,
        sourceMessageId: outgoingSourceMessageId,
        completer: completer,
      ),
    );

    unawaited(_drainQueue());
    return waitForSend ? completer.future : Future<void>.value();
  }

  @visibleForTesting
  static Future<void> waitForPendingRepliesForTesting() async {
    while (_isSending || _replyQueue.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  static Future<void> _drainQueue() async {
    if (_isSending) return;
    _isSending = true;

    try {
      while (_replyQueue.isNotEmpty) {
        final item = _replyQueue.removeFirst();
        try {
          await _sendAndRecord(item);
          item.completer.complete();
        } catch (e, st) {
          debugPrint('SMS reply queue failed: $e');
          debugPrintStack(stackTrace: st);
          item.completer.completeError(e, st);
        }

        if (_replyQueue.isNotEmpty) {
          await Future<void>.delayed(_sendDelay);
        }
      }
    } finally {
      _isSending = false;
    }
  }

  static Future<void> _sendAndRecord(_QueuedReply item) async {
    final normalizedPhone = PhoneNumberUtils.normalize(item.phoneNumber);

    try {
      await _doSend(item.phoneNumber, item.message);
      await _insertOutgoingMessage(
        phoneNumber: normalizedPhone,
        message: item.message,
        status: 'sent',
        sourceMessageId: item.sourceMessageId,
      );
    } catch (e, st) {
      debugPrint('SMS reply send failed: $e');
      debugPrintStack(stackTrace: st);
      await _insertOutgoingMessage(
        phoneNumber: normalizedPhone,
        message: item.message,
        status: 'failed',
        sourceMessageId: item.sourceMessageId,
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

  static String? _outgoingSourceMessageId(
    String? incomingSourceMessageId,
    String message,
  ) {
    if (incomingSourceMessageId == null || incomingSourceMessageId.isEmpty) {
      return null;
    }
    final hash = message.hashCode.toRadixString(16);
    return 'reply|$incomingSourceMessageId|$hash';
  }

  static Future<void> _doSend(String phoneNumber, String message) async {
    await NativeSmsSender.sendSms(to: phoneNumber, message: message);
    debugPrint('Reply sent to $phoneNumber');
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

class _QueuedReply {
  final String phoneNumber;
  final String message;
  final String? sourceMessageId;
  final Completer<void> completer;

  _QueuedReply({
    required this.phoneNumber,
    required this.message,
    required this.sourceMessageId,
    required this.completer,
  });
}
