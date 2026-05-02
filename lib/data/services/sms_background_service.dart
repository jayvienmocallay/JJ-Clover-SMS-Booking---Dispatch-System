// Task 004 — SMS Background Service: headless SMS listener and command router
// Task 007 — Pre-book context cache, cutoff time queuing, gallon type passthrough
// Task 008 — Zone-specific validation integration, next-day scheduling
import 'dart:async';
import 'dart:ui';
import 'package:telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number_utils.dart';
import '../repositories/database_runtime_repository.dart';
import '../repositories/incoming_sms_receipt_repository.dart';
import '../repositories/sms_message_repository.dart';
import 'sms_parser.dart';
import 'system_mode_manager.dart';
import 'app_event_bus.dart';
import 'push_notification_service.dart';
import 'pre_book_store.dart';
import 'sms_source_message_id.dart';
import 'command_handlers/sms_handler_utils.dart';
import 'command_handlers/deliver_command_handler.dart';
import 'command_handlers/drop_command_handler.dart';
import 'command_handlers/yes_command_handler.dart';
import 'command_handlers/registration_flow_handler.dart';

const MethodChannel _nativeSmsBackgroundChannel = MethodChannel(
  'com.jjclover.smartrelay/sms_background',
);

final _databaseRuntime = DatabaseRuntimeRepository();

/// Dart entry point started directly by Android's default SMS receiver.
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
    return true;
  });

  await _nativeSmsBackgroundChannel.invokeMethod<void>('initialized');
}

Future<void> _ensureSmsRuntimeReady() async {
  await _databaseRuntime.ensureReady();
}

/// Entry point used by Android when an SMS arrives while Flutter is backgrounded.
@pragma('vm:entry-point')
Future<void> smsBackgroundMessageHandler(SmsMessage msg) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await _ensureSmsRuntimeReady();
  await SmsBackgroundService.instance._processIncomingSms(
    msg,
    smsSender: Telephony.backgroundInstance,
  );
}

/// Thin command router — receives raw SMS, gates on deduplication, then
/// delegates to the appropriate command handler.
///
/// Business logic lives in the handler classes under command_handlers/.
class SmsBackgroundService {
  static final SmsBackgroundService instance = SmsBackgroundService._internal();

  final Telephony _telephony = Telephony.instance;
  final IncomingSmsReceiptRepository _receipts =
      IncomingSmsReceiptRepository();
  final SmsMessageRepository _messages = SmsMessageRepository();
  final SystemModeManager _modeManager = SystemModeManager.instance;

  final _preBookStore = PreBookStore();

  late final DeliverCommandHandler _deliverHandler;
  late final DropCommandHandler _dropHandler;
  late final YesCommandHandler _yesHandler;
  late final RegistrationFlowHandler _registrationHandler;

  bool _isListening = false;

  SmsBackgroundService._internal() {
    _deliverHandler = DeliverCommandHandler(_preBookStore);
    _dropHandler = DropCommandHandler();
    _yesHandler = YesCommandHandler(_preBookStore);
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
        );
      } else {
        debugPrint('Message still processing, skipped: $effectiveSourceMessageId');
      }
      return;
    }

    try {
      debugPrint('SMS received from $sender: $message');
      if (serviceCenterAddress != null && serviceCenterAddress.isNotEmpty) {
        debugPrint('SMS service center: $serviceCenterAddress');
      }

      await _messages.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(sender),
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

      // Refresh persisted mode — background isolate may have a stale singleton
      await _modeManager.loadPersistedMode();

      final parsed = SmsParser.parse(message);

      // Task 020 — privacy / registration takes priority over delivery commands
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
        case SmsCommand.status:
          await SmsHandlerUtils.sendReply(
            sender,
            'Current status: ${_modeManager.currentMode.displayName}',
            smsSender: smsSender,
          );
          break;
        // Registration / privacy commands are handled above; reaching here means
        // the sender is registered and not in an active flow — treat as unknown.
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
            gallonType: SmsHandlerUtils.mapGallonType(parsed.gallonType),
          );
          await SmsHandlerUtils.sendReply(
            sender,
            SmsParser.getUnknownCommandReply(),
            smsSender: smsSender,
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
}
