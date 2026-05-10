import 'package:another_telephony/telephony.dart';
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
        sourceMessageId: sourceMessageId,
      );
      return;
    }

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
        sourceMessageId: sourceMessageId,
      );
      return;
    }

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
        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final customer = Customer.fromMap(customerJoined);
    final schedulesData = await _schedules.getSchedulesForCustomer(
      customer.id!,
    );
    final schedules = schedulesData.map((s) => Schedule.fromMap(s)).toList();
    final today = DeliveryDays.getToday();
    final requestTime = DateTime.now();

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
            scheduledFor: _scheduledDateForDay(
              validation.correctDay!,
              from: requestTime,
            ),
          ),
        );
      }

      await SmsHandlerUtils.sendReply(
        sender,
        validation.message!,
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final now = requestTime;
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

    if (deliveryDay == null) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - No active delivery schedule',
        'Incomplete',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
      );

      await SmsHandlerUtils.sendReply(
        sender,
        'No active delivery schedule found for your account. Please call the station.',
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return;
    }

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
      scheduledFor: _scheduledDateForDay(deliveryDay, from: now),
      sourceMessageId: sourceMessageId,
    );

    final orderId = await _orders.insertOrder(order.toMap());
    if (orderId == 0) {
      await SmsHandlerUtils.sendReply(
        sender,
        'This order was already received. Reply CANCEL to cancel it, or wait 1 hour to reorder.',
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return;
    }

    AppEventBus().notifyOrderReceived();
    await PushNotificationService.showOrderNotification(
      title: 'New Delivery Order',
      body: '${parsed.quantity} gallon(s) from $sender – $deliveryDay',
      sender: sender,
    );

    if (isStaffAway) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(
          queuedDeliveryDay: isBeforeCutoff ? null : deliveryDay,
        ),
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
    } else if (isBeforeCutoff) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(),
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
    } else {
      await SmsHandlerUtils.sendReply(
        sender,
        'Order received. Past today\'s cutoff time. Your order has been queued for $deliveryDay.',
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
    }
  }

  DateTime _scheduledDateForDay(String deliveryDay, {required DateTime from}) {
    final currentIndex = from.weekday - 1;
    final targetIndex = DeliveryDays.days.indexOf(deliveryDay);
    if (targetIndex == -1) return from;
    final offset = (targetIndex - currentIndex) % 7;
    return DateTime(from.year, from.month, from.day)
        .add(Duration(days: offset));
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
