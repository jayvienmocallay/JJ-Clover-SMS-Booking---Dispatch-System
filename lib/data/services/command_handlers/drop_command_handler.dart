import 'package:telephony/telephony.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../../database_helper.dart';
import '../../models/order_model.dart';
import '../alarm_service.dart';
import '../app_event_bus.dart';
import '../push_notification_service.dart';
import '../sms_parser.dart';
import '../system_mode_manager.dart';
import 'sms_handler_utils.dart';

/// Handles the DROP command — walk-in/drop-off at the station.
///
/// DROP bypasses zone validation because the customer is physically present.
class DropCommandHandler {
  final _db = DatabaseHelper.instance;
  final _modeManager = SystemModeManager.instance;

  Future<void> handle(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);

    // Step 1: Mode gate — only MAINTENANCE rejects drop-offs
    if (!_modeManager.canAcceptDrop()) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DROP ${parsed.quantity ?? 0} - Rejected: ${_modeManager.getDropReply()}',
        'rejected',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDropReply(),
        smsSender: smsSender,
      );
      return;
    }

    // Step 2: Customer lookup (optional — drop-offs can be unregistered)
    final customerData = await _db.getCustomerByPhone(normalizedSender);
    final customerId = customerData?['id'] as int?;

    // Step 3: Create order
    final order = Order(
      customerId: customerId,
      phoneNumber: normalizedSender,
      type: OrderType.drop,
      quantity: parsed.quantity ?? 0,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
    );

    await _db.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'Walk-in DROP Order',
      body: '${parsed.quantity} gallon(s) from $sender – walk-in at station',
      sender: sender,
    );

    // Step 4: Mode-appropriate auto-reply
    await SmsHandlerUtils.sendReply(
      sender,
      _modeManager.getDropReply(),
      smsSender: smsSender,
    );

    // Task 012 — Trigger loud alarm for walk-in customer
    await AlarmService.instance.trigger(
      phone: normalizedSender,
      qty: parsed.quantity ?? 0,
    );
  }
}
