import '../../../core/utils/phone_number_utils.dart';
import '../../models/order_model.dart';
import '../../repositories/customer_repository.dart';
import '../alarm_service.dart';
import '../app_event_bus.dart';
import '../order_creation_service.dart';
import '../push_notification_service.dart';
import '../sms_parser.dart';
import '../system_mode_manager.dart';
import 'sms_handler_utils.dart';

/// Handles the DROP command — walk-in/drop-off at the station.
///
/// DROP bypasses zone validation because the customer is physically present.
class DropCommandHandler {
  final _customers = CustomerRepository();
  final _modeManager = SystemModeManager.instance;
  final _orderCreation = OrderCreationService();

  Future<void> handle(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final acceptedReply = _modeManager.getDropReply();

    // Step 1: Mode gate — only MAINTENANCE rejects drop-offs
    if (!_modeManager.canAcceptDrop()) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DROP ${parsed.quantity ?? 0} - Rejected: ${_modeManager.getDropReply()}',
        'rejected',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
      );
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDropReply(),

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    // Step 2: Customer lookup (optional — drop-offs can be unregistered)
    final customerData = await _customers.getCustomerByPhone(normalizedSender);
    final customerId = customerData?['id'] as int?;

    // Step 3: Create order
    final now = DateTime.now();

    final order = Order(
      customerId: customerId,
      phoneNumber: normalizedSender,
      type: OrderType.drop,
      quantity: parsed.quantity ?? 0,
      status: OrderStatus.pending,
      createdAt: now,
      scheduledFor: now,
      sourceMessageId: sourceMessageId,
      source: 'sms',
    );

    final orderId = await _orderCreation.createOrderFromModel(
      order,
      source: 'sms',
      validateSystemMode: false,
    );
    if (orderId == 0) {
      await SmsHandlerUtils.sendReply(
        sender,
        'Nadawat na kining order. Tubaga ug CANCEL para ma kansel, o hulat ug 1 ka oras para mo-order pag-usab.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Walk-in DROP nga Order',
      body: '${parsed.quantity} galon gikan $sender - walk-in sa estasyon',
      sender: sender,
    );

    // Staff acknowledgement sends the customer reply from the UI alert.
    // Task 012 — Trigger loud alarm for walk-in customer
    await AlarmService.instance.trigger(
      phone: normalizedSender,
      qty: parsed.quantity ?? 0,
      replyMessage: acceptedReply,
    );
  }
}
