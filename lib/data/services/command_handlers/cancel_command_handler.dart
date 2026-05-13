import '../../../core/utils/phone_number_utils.dart';
import '../../repositories/order_repository.dart';
import '../app_event_bus.dart';
import '../pre_book_store.dart';
import '../push_notification_service.dart';
import 'sms_handler_utils.dart';

/// Handles the CANCEL command from customers.
///
/// CANCEL clears any pending pre-book offer for the sender, then cancels the
/// sender's latest pending/confirmed operational order. Orders already in
/// transit must be handled by staff so delivery accountability stays intact.
class CancelCommandHandler {
  CancelCommandHandler(this._preBookStore);

  static const String _cancelReason = 'Cancelled via SMS by customer';

  final PreBookStore _preBookStore;
  final _orders = OrderRepository();

  Future<void> handle(String sender, {required String sourceMessageId}) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final pendingPreBook = _preBookStore[normalizedSender];
    final clearedPreBook = pendingPreBook != null;

    if (clearedPreBook) {
      await _preBookStore.remove(normalizedSender);
    }

    final activeOrders = await _orders.getOrders(
      where: 'phone_number = ? AND type != ? AND status IN (?, ?, ?)',
      whereArgs: [
        normalizedSender,
        'unrecognized',
        'pending',
        'confirmed',
        'in_transit',
      ],
    );

    if (activeOrders.isEmpty) {
      if (clearedPreBook) {
        AppEventBus().notifyOrderReceived();
        await SmsHandlerUtils.sendReply(
          sender,
          'Pending pre-book cancelled. No active order remains.',

          sourceMessageId: sourceMessageId,
        );
        return;
      }

      await SmsHandlerUtils.sendReply(
        sender,
        'No active order found to cancel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final latestOrder = activeOrders.first;
    final latestStatus = latestOrder['status'] as String? ?? '';
    if (latestStatus == 'in_transit') {
      await SmsHandlerUtils.sendReply(
        sender,
        'Your latest order is already in transit. Please call the station to cancel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final orderId = latestOrder['id'] as int?;
    if (orderId == null) {
      await SmsHandlerUtils.sendReply(
        sender,
        'We could not find an active order to cancel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final updated = await _orders.updateOrderStatus(
      orderId,
      'cancelled',
      reason: _cancelReason,
    );

    if (updated == 0) {
      await SmsHandlerUtils.sendReply(
        sender,
        'We could not find an active order to cancel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Order Cancelled',
      body: 'Customer cancelled order #$orderId from $sender',
      sender: sender,
    );

    final preBookNote = clearedPreBook
        ? ' Any pending pre-book offer was also cleared.'
        : '';
    await SmsHandlerUtils.sendReply(
      sender,
      'Order #$orderId has been cancelled.$preBookNote',
      sourceMessageId: sourceMessageId,
    );
  }
}
