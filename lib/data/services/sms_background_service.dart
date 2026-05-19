// Task 004 — SMS Background Service: headless SMS listener and command router
// Task 007 — Pre-book context cache, cutoff time queuing, gallon type passthrough
// Task 008 — Zone-specific validation integration, next-day scheduling
import 'dart:async';
import 'dart:ui';
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
import 'native_sms_sender.dart';
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

const MethodChannel _nativeSmsForegroundChannel = MethodChannel(
  'com.jjclover.smartrelay/sms_foreground',
);

final _databaseRuntime = DatabaseRuntimeRepository();
const int _maxIncomingReceiptAttempts = 3;
const Duration _staleIncomingReceiptAfter = Duration(minutes: 10);

@pragma('vm:entry-point')
Future<void> smsNativeBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NativeSmsSender.ensureStatusMonitoring();

  _nativeSmsBackgroundChannel.setMethodCallHandler((call) async {
    if (call.method != 'processSms') {
      throw MissingPluginException('Unknown native SMS method: ${call.method}');
    }

    final args = _coerceSmsPayload(call.arguments);
    try {
      await _ensureSmsRuntimeReady();
      await SmsBackgroundService.instance._processIncomingSmsPayload(
        sender: args.sender,
        message: args.message,
        timestamp: args.timestamp,
        subscriptionId: args.subscriptionId,
        serviceCenterAddress: args.serviceCenterAddress,
        sourceMessageId: args.sourceMessageId,
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

class SmsBackgroundService {
  static final SmsBackgroundService instance = SmsBackgroundService._internal();

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
  bool _foregroundChannelReady = false;
  bool _isRetryingReceipts = false;

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
    await _preBookStore.loadFromDb();
    await NativeSmsSender.ensureStatusMonitoring();
    await _startForegroundChannel();

    if (_isListening) return;

    // This app is the default SMS app and receives SMS_DELIVER through
    // DefaultSmsReceiver. Do not also register another_telephony.listenIncomingSms;
    // that creates duplicate processors for one physical SMS.
    _isListening = true;
    unawaited(
      _retryPendingReceipts().catchError((Object e, StackTrace st) {
        debugPrint('SMS receipt retry failed: $e');
        debugPrintStack(stackTrace: st);
        return 0;
      }),
    );
    debugPrint('SMS native receiver bridge started');
  }

  Future<void> _startForegroundChannel() async {
    if (_foregroundChannelReady) return;
    _nativeSmsForegroundChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'processSms':
          final args = _coerceSmsPayload(call.arguments);
          await _guardForegroundSmsProcessing(
            _processIncomingSmsPayload(
              sender: args.sender,
              message: args.message,
              timestamp: args.timestamp,
              subscriptionId: args.subscriptionId,
              serviceCenterAddress: args.serviceCenterAddress,
              sourceMessageId: args.sourceMessageId,
            ),
          );
          return true;
        case 'smsDataChanged':
          AppEventBus().notifyMessageReceived();
          AppEventBus().notifyOrderReceived();
          return true;
        default:
          throw MissingPluginException(
            'Unknown foreground SMS method: ${call.method}',
          );
      }
    });
    _foregroundChannelReady = true;
    try {
      await _nativeSmsForegroundChannel.invokeMethod<void>(
        'setForegroundReady',
        true,
      );
    } catch (e) {
      debugPrint('Unable to mark foreground SMS channel ready: $e');
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    if (_foregroundChannelReady) {
      try {
        await _nativeSmsForegroundChannel.invokeMethod<void>(
          'setForegroundReady',
          false,
        );
      } catch (e) {
        debugPrint('Unable to mark foreground SMS channel stopped: $e');
      }
    }
    debugPrint('SMS native receiver bridge stopped');
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

  Future<void> _processIncomingSmsPayload({
    required String sender,
    required String message,
    int? timestamp,
    int? subscriptionId,
    String? serviceCenterAddress,
    String? sourceMessageId,
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
        unawaited(
          SmsHandlerUtils.sendReply(
            sender,
            'Nadawat na kining order. Tubaga ug CANCEL para kanselar, o hulat ug 1 ka oras para mo-order pag-usab.',
            sourceMessageId: effectiveSourceMessageId,
          ).catchError((Object e, StackTrace st) {
            debugPrint('Queued reply failed: $e');
            debugPrintStack(stackTrace: st);
          }),
        );
      } else {
        debugPrint(
          'Message still processing, skipped: $effectiveSourceMessageId',
        );
        AppEventBus().notifyMessageReceived();
        AppEventBus().notifyOrderReceived();
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

      if (await _isBlockedOrSpam(normalizedSender)) {
        debugPrint('SMS ignored from blocked/spam contact: $normalizedSender');
        await _receipts.complete(effectiveSourceMessageId);
        return;
      }

      await PushNotificationService.showMessageNotification(
        title: 'Bag-ong Mensahe',
        body: 'Mensahe gikan $sender',
        sender: sender,
      );

      final parsed = SmsParser.parse(message);

      await _modeManager.loadPersistedMode();

      final handledByFirstContact = await _handleFirstContactIfNeeded(
        sender: sender,
        parsed: parsed,
        sourceMessageId: effectiveSourceMessageId,
      );
      if (handledByFirstContact) {
        await _receipts.complete(effectiveSourceMessageId);
        return;
      }

      final handledByPrivacyFlow = await _registrationHandler.handle(
        sender: sender,
        parsed: parsed,
        sourceMessageId: effectiveSourceMessageId,
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
          );
          break;
        case SmsCommand.drop:
          await _dropHandler.handle(
            sender,
            parsed,
            sourceMessageId: effectiveSourceMessageId,
          );
          break;
        case SmsCommand.yes:
          await _yesHandler.handle(
            sender,
            sourceMessageId: effectiveSourceMessageId,
          );
          break;
        case SmsCommand.cancel:
          await _cancelHandler.handle(
            sender,
            sourceMessageId: effectiveSourceMessageId,
          );
          break;
        case SmsCommand.status:
          unawaited(
            SmsHandlerUtils.sendReply(
              sender,
              'Karon nga status: ${_smsModeLabel(_modeManager.currentMode)}',
              sourceMessageId: effectiveSourceMessageId,
            ).catchError((Object e, StackTrace st) {
              debugPrint('Queued reply failed: $e');
              debugPrintStack(stackTrace: st);
            }),
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
          unawaited(
            SmsHandlerUtils.sendReply(
              sender,
              SmsParser.getUnknownCommandReply(),
              sourceMessageId: effectiveSourceMessageId,
            ).catchError((Object e, StackTrace st) {
              debugPrint('Queued reply failed: $e');
              debugPrintStack(stackTrace: st);
            }),
          );
          break;
      }

      await _receipts.complete(effectiveSourceMessageId);
    } catch (e) {
      await _receipts.fail(effectiveSourceMessageId, e);
      rethrow;
    }
  }

  Future<int> _retryPendingReceipts() async {
    if (_isRetryingReceipts) return 0;
    _isRetryingReceipts = true;

    try {
      await _receipts.failExhaustedStaleProcessing(
        maxAttempts: _maxIncomingReceiptAttempts,
        staleAfter: _staleIncomingReceiptAfter,
      );

      final rows = await _receipts.getRetryable(
        maxAttempts: _maxIncomingReceiptAttempts,
        staleAfter: _staleIncomingReceiptAfter,
      );
      var retried = 0;

      for (final row in rows) {
        final messageId = row['message_id']?.toString();
        final sender = row['phone_number']?.toString();
        final message = row['message']?.toString();
        if (messageId == null ||
            messageId.isEmpty ||
            sender == null ||
            sender.isEmpty ||
            message == null ||
            message.isEmpty) {
          continue;
        }

        try {
          await _processIncomingSmsPayload(
            sender: sender,
            message: message,
            timestamp: _asInt(row['sms_timestamp']),
            sourceMessageId: messageId,
          );
          retried += 1;
        } catch (e, st) {
          debugPrint('Retry failed for SMS receipt $messageId: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      return retried;
    } finally {
      _isRetryingReceipts = false;
    }
  }

  Future<bool> _isBlockedOrSpam(String phoneNumber) async {
    final customer = await _customers.getCustomerByPhone(phoneNumber);
    return (customer?['is_blocked'] as int? ?? 0) == 1 ||
        (customer?['is_spam'] as int? ?? 0) == 1;
  }

  String _smsModeLabel(SystemMode mode) {
    switch (mode) {
      case SystemMode.operating:
        return 'NAG-OPERATE';
      case SystemMode.staffAway:
        return 'WALA ANG STAFF';
      case SystemMode.full:
        return 'PUNO / BUSY';
      case SystemMode.maintenance:
        return 'MAINTENANCE';
    }
  }

  @visibleForTesting
  Future<int> retryPendingReceiptsForTesting() {
    return _retryPendingReceipts();
  }

  @visibleForTesting
  Future<void> processIncomingSmsPayloadForTesting({
    required String sender,
    required String message,
    int? timestamp,
    int? subscriptionId,
    String? serviceCenterAddress,
    String? sourceMessageId,
  }) {
    return _processIncomingSmsPayload(
      sender: sender,
      message: message,
      timestamp: timestamp,
      subscriptionId: subscriptionId,
      serviceCenterAddress: serviceCenterAddress,
      sourceMessageId: sourceMessageId,
    );
  }

  Future<bool> _handleFirstContactIfNeeded({
    required String sender,
    required ParsedSms parsed,
    String? sourceMessageId,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final alreadyNotified = await DatabaseHelper.instance
        .isFirstContactNotified(normalizedSender);
    if (alreadyNotified) return false;

    final customerData = await _customers.getCustomerByPhone(normalizedSender);
    final firstContactMessage = customerData == null
        ? '${SmsRegistrationCopy.firstContactWelcome}\n\n${SmsRegistrationCopy.firstContactPrivacyNotice}'
        : SmsRegistrationCopy.firstContactWelcome;

    unawaited(
      SmsHandlerUtils.sendReply(
        sender,
        firstContactMessage,
        sourceMessageId: sourceMessageId,
      ).catchError((Object e, StackTrace st) {
        debugPrint('Queued reply failed: $e');
        debugPrintStack(stackTrace: st);
      }),
    );

    await DatabaseHelper.instance.markFirstContactNotified(normalizedSender);
    debugPrint('First-contact automated reply sent to $normalizedSender');

    if (parsed.command == SmsCommand.drop) {
      return false;
    }

    return true;
  }
}

_SmsPayloadArgs _coerceSmsPayload(Object? rawArgs) {
  if (rawArgs is! Map) {
    throw ArgumentError('Native SMS payload must be a map.');
  }
  final args = Map<Object?, Object?>.from(rawArgs);
  final rawTimestamp = args['timestamp'];
  final rawSubscriptionId = args['subscriptionId'];
  return _SmsPayloadArgs(
    sourceMessageId: args['sourceMessageId']?.toString(),
    sender: args['sender']?.toString() ?? '',
    message: args['message']?.toString() ?? '',
    timestamp: rawTimestamp is int
        ? rawTimestamp
        : int.tryParse(rawTimestamp?.toString() ?? ''),
    subscriptionId: rawSubscriptionId is int
        ? rawSubscriptionId
        : int.tryParse(rawSubscriptionId?.toString() ?? ''),
    serviceCenterAddress: args['serviceCenterAddress']?.toString(),
  );
}

class _SmsPayloadArgs {
  final String? sourceMessageId;
  final String sender;
  final String message;
  final int? timestamp;
  final int? subscriptionId;
  final String? serviceCenterAddress;

  const _SmsPayloadArgs({
    required this.sourceMessageId,
    required this.sender,
    required this.message,
    required this.timestamp,
    required this.subscriptionId,
    required this.serviceCenterAddress,
  });
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
