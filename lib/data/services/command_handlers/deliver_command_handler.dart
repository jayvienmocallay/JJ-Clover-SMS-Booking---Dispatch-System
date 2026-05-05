import 'package:telephony/telephony.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../models/schedule_model.dart';
import '../../models/pre_book_context.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/settings_repository.dart';
import '../app_event_bus.dart';
import '../push_notification_service.dart';
import '../sms_parser.dart';
import '../sms_registration_copy.dart';
import '../system_mode_manager.dart';
import '../zone_validator.dart';
import '../pre_book_store.dart';
import 'sms_handler_utils.dart';

/// Handles the DELIVER command end-to-end:
///   mode gate → customer lookup → zone validation →
///   cutoff check → order creation → auto-reply.
class DeliverCommandHandler {
  DeliverCommandHandler(this._preBookStore);

  final PreBookStore _preBookStore;

  final _customers = CustomerRepository();
  final _orders = OrderRepository();
  final _schedules = ScheduleRepository();
  final _settings = SettingsRepository();
  final _modeManager = SystemModeManager.instance;

  Future<void> handle(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);

    // Step 1: Mode gate
    if (!_modeManager.canAcceptDelivery()) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Rejected: ${_modeManager.getDeliveryReply()}',
        'rejected',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(),
        smsSender: smsSender,
      );
      return;
    }

    // Step 2: Customer lookup
    final customerData = await _customers.getCustomerByPhone(normalizedSender);
    if (customerData == null) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        parsed.rawMessage,
        'Unregistered',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.unknownNumberPrompt,
        smsSender: smsSender,
      );
      return;
    }

    // Step 3: Customer profile + schedules
    final customerJoined = await _customers.getCustomerWithBarangayByPhone(
      normalizedSender,
    );
    if (customerJoined == null) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        parsed.rawMessage,
        'Incomplete',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );
      await SmsHandlerUtils.sendReply(
        sender,
        'Customer profile is incomplete. Please call the station.',
        smsSender: smsSender,
      );
      return;
    }
    final customer = Customer.fromMap(customerJoined);
    final schedulesData = await _schedules.getSchedulesForCustomer(
      customer.id!,
    );
    final schedules = schedulesData.map((s) => Schedule.fromMap(s)).toList();
    final today = DeliveryDays.getToday();

    // Step 4: Zone validation
    final validation = ZoneValidator.validate(
      customer: customer,
      schedules: schedules,
      currentDay: today,
    );

    if (validation.result == ValidationResult.invalidDay) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Wrong Day (${validation.message})',
        'prebook',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );
      if (validation.correctDay != null) {
        await _preBookStore.put(
          normalizedSender,
          PreBookContext(
            customerId: customer.id!,
            phoneNumber: normalizedSender,
            quantity: parsed.quantity ?? 0,
            gallonType: parsed.gallonType,
            address: parsed.address,
            deliveryDay: validation.correctDay!,
          ),
        );
      }
      await SmsHandlerUtils.sendReply(
        sender,
        validation.message!,
        smsSender: smsSender,
      );
      return;
    }

    // Step 5: Cutoff check
    final now = DateTime.now();
    final cutoffHour = await _settings.getCutoffHour();
    final cutoffMinute = await _settings.getCutoffMinute();
    final isBeforeCutoff =
        now.hour < cutoffHour ||
        (now.hour == cutoffHour && now.minute < cutoffMinute);

    String? deliveryDay;
    OrderStatus orderStatus;
    final isStaffAway = _modeManager.currentMode == SystemMode.staffAway;

    if (isStaffAway) {
      deliveryDay = isBeforeCutoff
          ? today
          : _findNextAvailableDay(schedules, today);
      orderStatus = OrderStatus.pending;
    } else if (isBeforeCutoff) {
      deliveryDay = today;
      orderStatus = OrderStatus.confirmed;
    } else {
      deliveryDay = _findNextAvailableDay(schedules, today);
      orderStatus = OrderStatus.pending;
    }

    // Step 6: Create order
    final order = Order(
      customerId: customer.id,
      phoneNumber: normalizedSender,
      type: OrderType.deliver,
      quantity: parsed.quantity ?? 0,
      gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      address: parsed.address,
      status: orderStatus,
      createdAt: now,
      deliveryDay: deliveryDay,
      sourceMessageId: sourceMessageId,
    );

    await _orders.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'New Delivery Order',
      body: '${parsed.quantity} gallon(s) from $sender – $deliveryDay',
      sender: sender,
    );

    // Step 7: Auto-reply
    if (isStaffAway) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(
          queuedDeliveryDay: isBeforeCutoff ? null : deliveryDay,
        ),
        smsSender: smsSender,
      );
    } else if (isBeforeCutoff) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(),
        smsSender: smsSender,
      );
    } else {
      await SmsHandlerUtils.sendReply(
        sender,
        'Order received. Past today\'s cutoff time. '
        'Your order has been queued for $deliveryDay.',
        smsSender: smsSender,
      );
    }
  }

  String? _findNextAvailableDay(List<Schedule> schedules, String currentDay) {
    final allowedDays = schedules.map((s) => s.deliveryDay).toSet();
    final todayIndex = DeliveryDays.days.indexOf(currentDay);
    for (int offset = 1; offset <= 7; offset++) {
      final checkDay = DeliveryDays.days[(todayIndex + offset) % 7];
      if (allowedDays.contains(checkDay)) return checkDay;
    }
    return null;
  }
}
