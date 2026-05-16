import '../../../core/utils/phone_number_utils.dart';
import '../../models/order_model.dart';
import '../app_event_bus.dart';
import '../order_creation_service.dart';
import '../pre_book_store.dart';
import '../push_notification_service.dart';
import 'sms_handler_utils.dart';

/// Handles the YES command — confirms a pending pre-book offer.
class YesCommandHandler {
  YesCommandHandler(this._preBookStore);

  final PreBookStore _preBookStore;
  final _orderCreation = OrderCreationService();

  Future<void> handle(String sender, {required String sourceMessageId}) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final context = _preBookStore[normalizedSender];

    if (context == null) {
      await SmsHandlerUtils.sendReply(
        sender,
        'No pending pre-book found. Please send a DELIVER command first.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    if (context.isExpired) {
      await _preBookStore.remove(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        'Pre-book offer has expired. Please send a new DELIVER command.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final order = Order(
      customerId: context.customerId,
      phoneNumber: context.phoneNumber,
      type: OrderType.deliver,
      quantity: context.quantity,
      address: context.address,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      deliveryDay: context.deliveryDay,
      scheduledFor: context.scheduledFor,
      isPreBook: true,
      sourceMessageId: sourceMessageId,
      source: 'prebook',
    );

    var orderId = 0;
    final pendingOrderId = context.pendingOrderId;
    if (pendingOrderId != null) {
      orderId = await _orderCreation.promotePendingUnrecognizedOrderFromModel(
        pendingOrderId,
        order,
        source: 'prebook',
        validateSystemMode: false,
      );
    }
    if (orderId == 0) {
      orderId = await _orderCreation.createOrderFromModel(
        order,
        source: 'prebook',
        validateSystemMode: false,
      );
    }
    if (orderId == 0) {
      await _preBookStore.remove(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        'This pre-book was already confirmed. Reply CANCEL to cancel it, or send a new DELIVER command later.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Pre-book Confirmed',
      body:
          '${context.quantity} gallon(s) from $sender – ${context.deliveryDay}',
      sender: sender,
    );

    await _preBookStore.remove(normalizedSender);

    await SmsHandlerUtils.sendReply(
      sender,
      'Pre-book confirmed! Your order of ${context.quantity} gallon(s) '
      'is scheduled for ${context.deliveryDay}.',
      sourceMessageId: sourceMessageId,
    );
  }
}
