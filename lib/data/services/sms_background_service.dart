import 'dart:async';
import 'package:telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import '../../database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../models/customer_model.dart';
import '../models/schedule_model.dart';
import '../models/order_model.dart';
import 'sms_parser.dart';
import 'zone_validator.dart';
import 'system_mode_manager.dart';

class SmsBackgroundService {
  static final SmsBackgroundService instance = SmsBackgroundService._internal();

  final Telephony _telephony = Telephony.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SystemModeManager _modeManager = SystemModeManager();

  bool _isListening = false;

  SmsBackgroundService._internal();

  bool get isListening => _isListening;

  Future<void> startListening() async {
    if (_isListening) return;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) {
        _processIncomingSms(msg);
      },
    );

    _isListening = true;
    debugPrint('SMS Background Service started');
  }

  void stopListening() {
    _isListening = false;
    debugPrint('SMS Background Service stopped');
  }

  void setMode(SystemMode mode) {
    _modeManager.setMode(mode);
  }

  SystemMode get currentMode => _modeManager.currentMode;

  Future<void> _processIncomingSms(SmsMessage msg) async {
    final sender = msg.address ?? '';
    final message = msg.body ?? '';

    if (sender.isEmpty) return;

    debugPrint('SMS received from $sender: $message');

    final parsed = SmsParser.parse(message);

    switch (parsed.command) {
      case SmsCommand.deliver:
        await _handleDeliver(sender, parsed);
        break;
      case SmsCommand.drop:
        await _handleDrop(sender, parsed);
        break;
      case SmsCommand.yes:
        await _handleYes(sender);
        break;
      case SmsCommand.status:
        await _handleStatus(sender);
        break;
      case SmsCommand.unknown:
        await _sendReply(sender, SmsParser.getUnknownCommandReply());
        break;
    }
  }

  Future<void> _handleDeliver(String sender, ParsedSms parsed) async {
    if (!_modeManager.canAcceptDelivery()) {
      await _sendReply(sender, _modeManager.getDeliveryReply());
      return;
    }

    final customerData = await _db.getCustomerByPhone(sender);
    if (customerData == null) {
      await _sendReply(
        sender,
        'Unknown number. Please register first or call the station.',
      );
      return;
    }

    final customer = Customer.fromMap(customerData);
    final schedulesData = await _db.getSchedules();
    final schedules = schedulesData.map((s) => Schedule.fromMap(s)).toList();
    final today = DeliveryDays.getToday();

    final validation = ZoneValidator.validate(
      customer: customer,
      schedules: schedules,
      currentDay: today,
    );

    if (validation.result == ValidationResult.unregistered) {
      await _sendReply(sender, validation.message!);
      return;
    }

    if (validation.result == ValidationResult.invalidDay) {
      await _sendReply(sender, validation.message!);
      return;
    }

    final now = DateTime.now();
    final isBeforeCutoff =
        now.hour < AppConstants.orderCutOffHour ||
        (now.hour == AppConstants.orderCutOffHour &&
            now.minute < AppConstants.orderCutOffMinute);

    final order = Order(
      customerId: customer.id,
      phoneNumber: sender,
      type: OrderType.deliver,
      quantity: parsed.quantity ?? 0,
      address: parsed.address,
      status: OrderStatus.confirmed,
      createdAt: now,
      deliveryDay: isBeforeCutoff ? today : null,
    );

    await _db.insertOrder(order.toMap());

    final reply = _modeManager.getDeliveryReply();
    await _sendReply(sender, reply);
  }

  Future<void> _handleDrop(String sender, ParsedSms parsed) async {
    if (!_modeManager.canAcceptDrop()) {
      await _sendReply(sender, _modeManager.getDropReply());
      return;
    }

    final customerData = await _db.getCustomerByPhone(sender);
    final customerId = customerData?['id'] as int?;

    final order = Order(
      customerId: customerId,
      phoneNumber: sender,
      type: OrderType.drop,
      quantity: parsed.quantity ?? 0,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );

    await _db.insertOrder(order.toMap());

    final reply = _modeManager.getDropReply();
    await _sendReply(sender, reply);
  }

  Future<void> _handleYes(String sender) async {
    await _sendReply(
      sender,
      'Pre-book confirmed! We will deliver on your scheduled day.',
    );
  }

  Future<void> _handleStatus(String sender) async {
    final mode = _modeManager.currentMode;
    await _sendReply(sender, 'Current status: ${mode.displayName}');
  }

  Future<void> _sendReply(String phoneNumber, String message) async {
    try {
      await _telephony.sendSms(to: phoneNumber, message: message);
      debugPrint('Reply sent to $phoneNumber: $message');
    } catch (e) {
      debugPrint('Failed to send reply: $e');
    }
  }
}
