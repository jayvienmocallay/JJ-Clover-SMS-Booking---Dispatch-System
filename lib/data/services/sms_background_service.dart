// Task 004 — SMS Background Service: headless SMS listener and command router
// Task 007 — Pre-book context cache, cutoff time queuing, gallon type passthrough
// Task 008 — Zone-specific validation integration, next-day scheduling
import 'dart:async';
import 'dart:ui';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../database_helper.dart';
import '../repositories/customer_repository.dart';
import '../repositories/database_runtime_repository.dart';
import '../repositories/incoming_sms_receipt_repository.dart';
import '../repositories/sms_message_repository.dart';
import 'sms_parser.dart';
import 'system_mode_manager.dart';
import 'app_event_bus.dart';
import 'push_notification_service.dart';
import 'pre_book_store.dart';
import 'sms_registration_copy.dart';
import 'sms_source_message_id.dart';
import 'command_handlers/sms_handler_utils.dart';
import 'command_handlers/cancel_command_handler.dart';
import 'command_handlers/deliver_command_handler.dart';
import 'command_handlers/drop_command_handler.dart';
import 'command_handlers/yes_command_handler.dart';
import 'command_handlers/registration_flow_handler.dart';

const MethodChannel _nativeSmsBackgroundChannel = MethodChannel(
  'com.jjclover.smartrelay/sms_background',
);

final _databaseRuntime = DatabaseRuntimeRepository();

@pragma('vm:entry-point')
Future<void> smsNativeBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  _nativeSmsBackgroundChannel.setMethodCallHandler((call) async {
    if (call.method != 'processSms') {
      throw MissingPluginException('Unknown native SMS method: ${call.method}');
    }

    final rawArgs = call.arguments;
    if (rawArgs is! Map) {
      throw ArgumentError('Native SMS payload must be a map.');
    }

    final args = Map<Object?, Object?>.from(rawArgs);
    final sender = args['sender']?.toString() ?? '';
    final message = args['message']?.toString() ?? '';
    final rawTimestamp = args['timestamp'];
    final timestamp = rawTimestamp is int
        ? rawTimestamp
        : int.tryParse(rawTimestamp?.toString() ?? '');
    final rawSubscriptionId = args['subscriptionId'];
    final subscriptionId = rawSubscriptionId is int
        ? rawSubscriptionId
        : int.tryParse(rawSubscriptionId?.toString() ?? '');
    final sourceMessageId = args['sourceMessageId']?.toString();

    try {
      await _ensureSmsRuntimeReady();
      await SmsBackgroundService.instance._processIncomingSmsPayload(
        sender: sender,
        message: message,
        timestamp: timestamp,
        subscriptionId: subscriptionId,
        serviceCenterAddress: args['serviceCenterAddress']?.toString(),
        sourceMessageId: sourceMessageId,
        smsSender: Telephony.backgroundInstance,
      );
    } catch (e, st) {
      debugPrint('smsNativeBackgroundMain processing error: $e\n$st');
    }
    return true;
  });

  await _nativeSmsBackgroundChannel.invokeMethod<void>('initialized');
}

Future<void> _ensureSmsRuntimeReady() async {
  await _databaseRuntime.ensureReady();
}

@pragma('vm:entry-point')
Future<void> smsBackgroundMessageHandler(SmsMessage msg) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await _ensureSmsRuntimeReady();
    await SmsBackgroundService.instance._processIncomingSms(
      msg,
      smsSender: Telephony.backgroundInstance,
    );
  } catch (e, st) {
    debugPrint('smsBackgroundMessageHandler error: $e\n$st');
  }
}

class SmsBackgroundService {
  static final SmsBackgroundService instance = SmsBackgroundService._internal();

  final Telephony _telephony = Telephony.instance;
  final IncomingSmsReceiptRepository _receipts = IncomingSmsReceiptRepository();
  final SmsMessageRepository _messages = SmsMessageRepository();
  final CustomerRepository _customers = CustomerRepository();
  final SystemModeManager _modeManager = SystemModeManager.instance;

  final _preBookStore = PreBookStore();

  late final DeliverCommandHandler _deliverHandler;
  late final DropCommandHandler _dropHandler;
  late final YesCommandHandler _yesHandler;
  late final CancelCommandHandler _cancelHandler;
  late final RegistrationFlowHandler _registrationHandler;

  bool _isListening = false;

  SmsBackgroundService._internal() {
    _deliverHandler = DeliverCommandHandler(_preBookStore);
    _dropHandler = DropCommandHandler();
    _yesHandler = YesCommandHandler(_preBookStore);
    _cancelHandler = CancelCommandHandler(_preBookStore);
    _registrationHandler = RegistrationFlowHandler();
  }

  bool get isListening => _isListening;

  SystemMode get currentMode => _modeManager.currentMode;

  void setMode(SystemMode mode) => _modeManager.setMode(mode);

  Future<void> startListening() async {
    if (_isListening) return;

    await _preBookStore.loadFromDb();

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) {
        unawaited(_guardForegroundSmsProcessing(_processIncomingSms(msg)));
      },
      onBackgroundMessage: smsBackgroundMessageHandler,
    );

    _isListening = true;
    debugPrint('SMS Background Service started');
  }

  void stopListening() {
    _isListening = false;
    debugPrint('SMS Background Service stopped');
  }

  @visibleForTesting
  Future<void> guardForegroundSmsProcessingForTesting(Future<void> processing) {
    return _guardForegroundSmsProcessing(processing);
  }

  Future<void> _guardForegroundSmsProcessing(Future<void> processing) async {
    try {
      await processing;
    } catch (error, stackTrace) {
      debugPrint('Foreground SMS processing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _processIncomingSms(
    SmsMessage msg, {
    Telephony? smsSender,
  }) async {
    await _processIncomingSmsPayload(
      sender: msg.address ?? '',
      message: msg.body ?? '',
      timestamp: msg.date,
      subscriptionId: msg.subscriptionId,
      serviceCenterAddress: msg.serviceCenterAddress,
      smsSender: smsSender,
    );
  }

  Future<void> _processIncomingSmsPayload({
    required String sender,
    required String message,
    int? timestamp,
    int? subscriptionId,
    String? serviceCenterAddress,
    String? sourceMessageId,
    Telephony? smsSender,
  }) async {
    if (sender.isEmpty) return;
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    if (normalizedSender.isEmpty) return;

    final effectiveSourceMessageId =
        sourceMessageId ??
        SmsSourceMessageId.build(
          sender: sender,
          message: message,
          timestamp: timestamp,
          subscriptionId: subscriptionId,
        );

    final claimResult = await _receipts.claim(
      messageId: effectiveSourceMessageId,
      phoneNumber: sender,
      message: message,
      smsTimestamp: timestamp,
    );

    if (!claimResult.claimed) {
      if (claimResult.isDuplicate) {
        debugPrint('Duplicate order within 1 hour: $effectiveSourceMessageId');
        await SmsHandlerUtils.sendReply(
          sender,
          'This order was already received. Reply CANCEL to cancel it, or wait 1 hour to reorder.',
          smsSender: smsSender,
          sourceMessageId: effectiveSourceMessageId,
        );
      } else {
        debugPrint(
          'Message still processing, skipped: $effectiveSourceMessageId',
        );
      }
      return;
    }

    try {
      debugPrint('SMS received from $sender: $message');
      if (serviceCenterAddress != null && serviceCenterAddress.isNotEmpty) {
        debugPrint('SMS service center: $serviceCenterAddress');
      }

      await _messages.insertSmsMessage({
        'phone_number': normalizedSender,
        'message': message,
        'direction': 'incoming',
        'source_message_id': effectiveSourceMessageId,
        'sent_at': DateTime.now().toIso8601String(),
      });
      AppEventBus().notifyMessageReceived();
      await PushNotificationService.showMessageNotification(
        title: 'New Message',
        body: 'Message from $sender',
        sender: sender,
      );

      await _modeManager.loadPersistedMode();

      await _sendFirstContactRepliesIfNeeded(
        sender: sender,
        smsSender: smsSender,
        sourceMessageId: effectiveSourceMessageId,
      );

      final parsed = SmsParser.parse(message);

      final handledByPrivacyFlow = await _registrationHandler.handle(
        sender: sender,
        parsed: parsed,
        sourceMessageId: effectiveSourceMessageId,
        smsSender: smsSender,
      );
      if (handledByPrivacyFlow) {
        await _receipts.complete(effectiveSourceMessageId);
        return;
      }

      switch (parsed.command) {
        case SmsCommand.deliver:
          await _deliverHandler.handle(
            sender,
            parsed,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.drop:
          await _dropHandler.handle(
            sender,
            parsed,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.yes:
          await _yesHandler.handle(
            sender,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.cancel:
          await _cancelHandler.handle(
            sender,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.status:
          await SmsHandlerUtils.sendReply(
            sender,
            'Current status: ${_modeManager.currentMode.displayName}',
            smsSender: smsSender,
            sourceMessageId: effectiveSourceMessageId,
          );
          break;
        case SmsCommand.register:
        case SmsCommand.agree:
        case SmsCommand.stop:
        case SmsCommand.barangay:
        case SmsCommand.address:
        case SmsCommand.myData:
        case SmsCommand.deleteData:
        case SmsCommand.confirmDelete:
        case SmsCommand.optOut:
        case SmsCommand.unknown:
          await SmsHandlerUtils.saveUnrecognized(
            sender,
            message,
            'Unrecognized',
            sourceMessageId: effectiveSourceMessageId,
            quantity: parsed.quantity ?? 0,
          );
          await SmsHandlerUtils.sendReply(
            sender,
            SmsParser.getUnknownCommandReply(),
            smsSender: smsSender,
            sourceMessageId: effectiveSourceMessageId,
          );
          break;
      }

      await _receipts.complete(effectiveSourceMessageId);
    } catch (e) {
      await _receipts.fail(effectiveSourceMessageId, e);
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> processIncomingSmsPayloadForTesting({
    required String sender,
    required String message,
    int? timestamp,
    int? subscriptionId,
    String? serviceCenterAddress,
    String? sourceMessageId,
    Telephony? smsSender,
  }) {
    return _processIncomingSmsPayload(
      sender: sender,
      message: message,
      timestamp: timestamp,
      subscriptionId: subscriptionId,
      serviceCenterAddress: serviceCenterAddress,
      sourceMessageId: sourceMessageId,
      smsSender: smsSender,
    );
  }

  Future<void> _sendFirstContactRepliesIfNeeded({
    required String sender,
    Telephony? smsSender,
    String? sourceMessageId,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final alreadyNotified = await DatabaseHelper.instance
        .isFirstContactNotified(normalizedSender);
    if (alreadyNotified) return;

    final customerData = await _customers.getCustomerByPhone(normalizedSender);
    if (customerData == null) {
      debugPrint(
        'First-contact registration prompt skipped for unregistered $normalizedSender',
      );
      return;
    }

    await SmsHandlerUtils.sendReply(
      sender,
      SmsRegistrationCopy.firstContactWelcome,
      smsSender: smsSender,
      sourceMessageId: sourceMessageId,
    );

    await DatabaseHelper.instance.markFirstContactNotified(normalizedSender);
    debugPrint('First-contact automated reply sent to $normalizedSender');
  }
}
