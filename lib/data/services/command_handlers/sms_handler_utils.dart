import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';

import '../../../core/utils/phone_number_utils.dart';
import '../../models/order_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/outgoing_sms_queue_repository.dart';
import '../../repositories/sms_message_repository.dart';
import '../app_event_bus.dart';
import '../push_notification_service.dart';

/// Static utilities shared across all SMS command handlers.
class SmsHandlerUtils {
  static final _customers = CustomerRepository();
  static final _messages = SmsMessageRepository();
  static final _orders = OrderRepository();
  static final _outgoingQueue = OutgoingSmsQueueRepository();

  /// Default delay between transactional SMS sends from the same SIM.
  ///
  /// This keeps replies responsive while avoiding bursty sending patterns that
  /// Android, the SIM, or the carrier may throttle.
  static const Duration _sendDelay = Duration(seconds: 5);

  static bool _isSending = false;
  static Timer? _retryTimer;

  /// Queues an SMS reply for persisted, throttled delivery.
  ///
  /// The queue is database-backed, so replies survive process restarts. Recent
  /// duplicate replies to the same number are suppressed by the repository.
  static Future<void> sendReply(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
    String? sourceMessageId,
  }) async {
    final queueId = await _outgoingQueue.enqueue(
      phoneNumber: phoneNumber,
      message: message,
      sourceMessageId: sourceMessageId,
    );

    if (queueId == null) {
      debugPrint('Duplicate SMS reply suppressed for $phoneNumber: $message');
      return;
    }

    return _drainQueue(smsSender: smsSender);
  }

  /// Drains all currently due outgoing replies.
  ///
  /// Failed sends are left in the persisted queue for bounded retry. This method
  /// intentionally does not throw into command handlers: an order should still
  /// be recorded even if the SMS transport is temporarily unavailable.
  static Future<void> drainOutgoingQueue({Telephony? smsSender}) {
    return _drainQueue(smsSender: smsSender);
  }

  static Future<void> _drainQueue({Telephony? smsSender}) async {
    if (_isSending) return;
    _isSending = true;
    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      var sentAny = false;
      while (true) {
        final row = await _outgoingQueue.claimNextDue();
        if (row == null) break;

        final id = row['id'] as int;
        final phoneNumber = row['phone_number'] as String;
        final message = row['message'] as String;

        if (sentAny) {
          await Future<void>.delayed(_sendDelay);
        }

        try {
          await _doSend(
            phoneNumber,
            message,
            smsSender: smsSender,
          );
          await _outgoingQueue.markSent(id);
          await _messages.insertSmsMessage({
            'phone_number': PhoneNumberUtils.normalize(phoneNumber),
            'message': message,
            'direction': 'outgoing',
            'status': 'sent',
            'sent_at': DateTime.now().toIso8601String(),
          });
        } catch (e, st) {
          debugPrint('Failed to send queued reply #$id: $e');
          debugPrintStack(stackTrace: st);
          await _outgoingQueue.markFailedOrRetry(id, e);
          await _messages.insertSmsMessage({
            'phone_number': PhoneNumberUtils.normalize(phoneNumber),
            'message': message,
            'direction': 'outgoing',
            'status': 'failed',
            'sent_at': DateTime.now().toIso8601String(),
          });
        }
        sentAny = true;
      }
    } finally {
      _isSending = false;
      unawaited(_scheduleNextRetry(smsSender: smsSender));
    }
  }

  static Future<void> _scheduleNextRetry({Telephony? smsSender}) async {
    _retryTimer?.cancel();
    _retryTimer = null;

    final nextAttemptAt = await _outgoingQueue.getNextPendingAttemptAt();
    if (nextAttemptAt == null) return;

    final now = DateTime.now();
    final delay = nextAttemptAt.isAfter(now)
        ? nextAttemptAt.difference(now)
        : Duration.zero;

    _retryTimer = Timer(delay, () {
      unawaited(_drainQueue(smsSender: smsSender));
    });
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
