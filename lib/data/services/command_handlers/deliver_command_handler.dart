import '../../../core/constants/app_constants.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../models/pre_book_context.dart';
import '../../models/schedule_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/settings_repository.dart';
import '../app_event_bus.dart';
import '../order_creation_service.dart';
import '../pre_book_store.dart';
import '../push_notification_service.dart';
import '../sms_parser.dart';
import '../sms_registration_copy.dart';
import '../system_mode_manager.dart';
import '../zone_validator.dart';
import 'sms_handler_utils.dart';

/// Handles the DELIVER command end-to-end:
///   mode gate → customer lookup → zone validation →
///   cutoff check → order creation → auto-reply.
class DeliverCommandHandler {
  DeliverCommandHandler(this._preBookStore);

  final PreBookStore _preBookStore;

  final _customers = CustomerRepository();
  final _schedules = ScheduleRepository();
  final _settings = SettingsRepository();
  final _orderCreation = OrderCreationService();
  final _modeManager = SystemModeManager.instance;

  Future<void> handle(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final currentMode = _modeManager.currentMode;
    final isStaffAway = currentMode == SystemMode.staffAway;
    final isFull = currentMode == SystemMode.full;

    if (!_modeManager.canAcceptDelivery()) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Rejected: ${_modeManager.getDeliveryReply()}',
        'rejected',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
      );
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(),

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
      );
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.unknownNumberPrompt,

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
      );
      await SmsHandlerUtils.sendReply(
        sender,
        'Kulang ang profile sa customer. Palihug tawagi ang estasyon.',

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
      final pendingOrderId = await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Wrong Day (${validation.message})',
        'prebook',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
      );

      if (validation.correctDay != null) {
        await _preBookStore.put(
          normalizedSender,
          PreBookContext(
            customerId: customer.id!,
            phoneNumber: normalizedSender,
            quantity: parsed.quantity ?? 0,
            address: parsed.address,
            deliveryDay: validation.correctDay!,
            scheduledFor: _scheduledDateForDay(
              validation.correctDay!,
              from: requestTime,
            ),
            pendingOrderId: pendingOrderId == 0 ? null : pendingOrderId,
          ),
        );
      }

      await SmsHandlerUtils.sendReply(
        sender,
        isStaffAway
            ? _staffAwayPreBookReply(validation.message)
            : validation.message!,

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

    _ScheduledDeliverySlot? scheduledSlot;
    OrderStatus orderStatus;

    if (isFull) {
      scheduledSlot = _findNextAvailableSlot(schedules, from: now);
      orderStatus = OrderStatus.pending;
    } else if (isStaffAway) {
      scheduledSlot = isBeforeCutoff
          ? _ScheduledDeliverySlot(
              deliveryDay: today,
              scheduledFor: _scheduledDateForDay(today, from: now),
            )
          : _findNextAvailableSlot(schedules, from: now);
      orderStatus = OrderStatus.pending;
    } else if (isBeforeCutoff) {
      scheduledSlot = _ScheduledDeliverySlot(
        deliveryDay: today,
        scheduledFor: _scheduledDateForDay(today, from: now),
      );
      orderStatus = OrderStatus.confirmed;
    } else {
      scheduledSlot = _findNextAvailableSlot(schedules, from: now);
      orderStatus = OrderStatus.pending;
    }

    if (scheduledSlot == null) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - No active delivery schedule',
        'Incomplete',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
      );

      await SmsHandlerUtils.sendReply(
        sender,
        'Walay aktibong schedule sa delivery para sa imong account. Palihug tawagi ang estasyon.',

        sourceMessageId: sourceMessageId,
      );
      return;
    }

    final order = Order(
      customerId: customer.id,
      phoneNumber: normalizedSender,
      type: OrderType.deliver,
      quantity: parsed.quantity ?? 0,
      address: parsed.address,
      status: orderStatus,
      createdAt: now,
      deliveryDay: scheduledSlot.deliveryDay,
      scheduledFor: scheduledSlot.scheduledFor,
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
      title: 'Bag-ong Delivery Order',
      body:
          '${parsed.quantity} galon gikan $sender - ${scheduledSlot.deliveryDay}',
      sender: sender,
    );

    if (isFull) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(
          queuedDeliveryDay: scheduledSlot.deliveryDay,
        ),

        sourceMessageId: sourceMessageId,
      );
    } else if (isStaffAway) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(
          queuedDeliveryDay: isBeforeCutoff ? null : scheduledSlot.deliveryDay,
        ),

        sourceMessageId: sourceMessageId,
      );
    } else if (isBeforeCutoff) {
      await SmsHandlerUtils.sendReply(
        sender,
        _modeManager.getDeliveryReply(),

        sourceMessageId: sourceMessageId,
      );
    } else {
      await SmsHandlerUtils.sendReply(
        sender,
        'Nadawat ang order. Lapas na sa cutoff time karon. '
        'Gi-queue ang imong order para sa ${scheduledSlot.deliveryDay}.',

        sourceMessageId: sourceMessageId,
      );
    }
  }

  String _staffAwayPreBookReply(String? scheduleMessage) {
    const staffAwayNotice =
        'Nadawat ang imong mensahe. Ang staff naa pa sa delivery. '
        'Iproseso namo pagbalik.';
    if (scheduleMessage == null || scheduleMessage.isEmpty) {
      return staffAwayNotice;
    }
    return '$staffAwayNotice $scheduleMessage';
  }

  DateTime _scheduledDateForDay(String deliveryDay, {required DateTime from}) {
    final currentIndex = from.weekday - 1;
    final targetIndex = DeliveryDays.days.indexOf(deliveryDay);
    if (targetIndex == -1) return from;
    final offset = (targetIndex - currentIndex) % 7;
    return DateTime(
      from.year,
      from.month,
      from.day,
    ).add(Duration(days: offset));
  }

  _ScheduledDeliverySlot? _findNextAvailableSlot(
    List<Schedule> schedules, {
    required DateTime from,
  }) {
    final allowedDays = schedules.map((s) => s.deliveryDay).toSet();
    final todayIndex = from.weekday - 1;
    for (int offset = 1; offset <= 7; offset++) {
      final checkDay = DeliveryDays.days[(todayIndex + offset) % 7];
      if (!allowedDays.contains(checkDay)) continue;
      final scheduledFor = DateTime(
        from.year,
        from.month,
        from.day,
      ).add(Duration(days: offset));
      return _ScheduledDeliverySlot(
        deliveryDay: checkDay,
        scheduledFor: scheduledFor,
      );
    }
    return null;
  }
}

class _ScheduledDeliverySlot {
  final String deliveryDay;
  final DateTime scheduledFor;

  const _ScheduledDeliverySlot({
    required this.deliveryDay,
    required this.scheduledFor,
  });
}
