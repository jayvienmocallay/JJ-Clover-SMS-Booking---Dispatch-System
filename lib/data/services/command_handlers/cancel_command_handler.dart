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
          'Gikanselar ang pending pre-book. Wala nay aktibong order nga nabilin.',

          sourceMessageId: sourceMessageId,
        );
        return;
      }

      await SmsHandlerUtils.sendReply(
        sender,
        'Walay aktibong order nga makansel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final latestOrder = activeOrders.first;
    final latestStatus = latestOrder['status'] as String? ?? '';
    if (latestStatus == 'in_transit') {
      await SmsHandlerUtils.sendReply(
        sender,
        'Ang imong pinakabag-ong order naa na sa transit. Palihug tawagi ang estasyon para sa pag kansel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final orderId = latestOrder['id'] as int?;
    if (orderId == null) {
      await SmsHandlerUtils.sendReply(
        sender,
        'Wala mi nakakita ug aktibong order nga makansel.',

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
        'Wala mi nakakita ug aktibong order nga makansel.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Order Gikansel',
      body: 'Gikansel sa customer ang order #$orderId gikan $sender',
      sender: sender,
    );

    final preBookNote = clearedPreBook
        ? ' Ang pending nga pre-book offer natangal sad.'
        : '';
    await SmsHandlerUtils.sendReply(
      sender,
      'Gikansel na ang order #$orderId.$preBookNote',
      sourceMessageId: sourceMessageId,
    );
  }
}
