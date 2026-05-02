import 'package:telephony/telephony.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../../database_helper.dart';
import '../../models/order_model.dart';
import '../app_event_bus.dart';
import '../pre_book_store.dart';
import '../push_notification_service.dart';
import 'sms_handler_utils.dart';

/// Handles the YES command — confirms a pending pre-book offer.
class YesCommandHandler {
  YesCommandHandler(this._preBookStore);

  final PreBookStore _preBookStore;
  final _db = DatabaseHelper.instance;

  Future<void> handle(
    String sender, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final context = _preBookStore[normalizedSender];

    if (context == null) {
      await SmsHandlerUtils.sendReply(
        sender,
        'No pending pre-book found. Please send a DELIVER command first.',
        smsSender: smsSender,
      );
      return;
    }

    if (context.isExpired) {
      await _preBookStore.remove(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        'Pre-book offer has expired. Please send a new DELIVER command.',
        smsSender: smsSender,
      );
      return;
    }

    final order = Order(
      customerId: context.customerId,
      phoneNumber: context.phoneNumber,
      type: OrderType.deliver,
      quantity: context.quantity,
      gallonType: SmsHandlerUtils.mapGallonType(context.gallonType),
      address: context.address,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      deliveryDay: context.deliveryDay,
      isPreBook: true,
      sourceMessageId: sourceMessageId,
    );

    await _db.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Pre-book Confirmed',
      body: '${context.quantity} gallon(s) from $sender – ${context.deliveryDay}',
      sender: sender,
    );

    await _preBookStore.remove(normalizedSender);

    await SmsHandlerUtils.sendReply(
      sender,
      'Pre-book confirmed! Your order of ${context.quantity} gallon(s) '
      'is scheduled for ${context.deliveryDay}.',
      smsSender: smsSender,
    );
  }
}
