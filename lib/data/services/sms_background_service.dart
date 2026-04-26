// Task 004 — SMS Background Service: headless SMS listener and command router
// Task 007 — Pre-book context cache, cutoff time queuing, gallon type passthrough
// Task 008 — Zone-specific validation integration, next-day scheduling
import 'dart:async';
import 'dart:ui';
import 'package:telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_number_utils.dart';
import '../models/customer_model.dart';
import '../models/schedule_model.dart';
import '../models/order_model.dart';
import 'sms_parser.dart';
import 'zone_validator.dart';
import 'system_mode_manager.dart';
import 'alarm_service.dart';
import 'sms_source_message_id.dart';
import 'app_event_bus.dart';

const MethodChannel _nativeSmsBackgroundChannel = MethodChannel(
  'com.jjclover.smartrelay/sms_background',
);

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
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.ensureSchedulesSeeded();
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

/// Background SMS service that listens for incoming messages and processes
/// them as commands (DELIVER, DROP, YES, STATUS).
///
/// This is the "Background Isolate" in the system architecture — it runs
/// headlessly, parsing SMS via regex, validating zones, and writing orders
/// to the encrypted database. The UI reads from the same database.
///
/// Architecture: SMS → SmsParser → ZoneValidator → DatabaseHelper → Auto-Reply
class SmsBackgroundService {
  // --- Singleton pattern: ensures only one instance listens for SMS ---
  static final SmsBackgroundService instance = SmsBackgroundService._internal();

  /// Telephony API for sending/receiving SMS
  final Telephony _telephony = Telephony.instance;

  /// Database helper for all CRUD operations
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Manages system modes (Operating, Staff Away, Full, Maintenance)
  /// Task 013 — Uses singleton so UI mode toggles are reflected in SMS replies
  final SystemModeManager _modeManager = SystemModeManager.instance;

  /// Tracks whether the SMS listener is currently active
  bool _isListening = false;

  /// Stores pre-book context: maps a phone number to the delivery day
  /// that was offered in the "Wrong Day" reply. When the customer replies
  /// YES, we look up this map to know which day to create the pre-book for.
  /// Key: phone number (String), Value: offered delivery day (String)
  final Map<String, _PreBookContext> _preBookPending = {};

  /// Private constructor — use [instance] to access
  SmsBackgroundService._internal();

  /// Whether the service is currently listening for incoming SMS
  bool get isListening => _isListening;

  /// Starts listening for incoming SMS messages.
  /// Registers [_processIncomingSms] as the callback for new messages.
  /// Does nothing if already listening (prevents duplicate listeners).
  Future<void> startListening() async {
    // Guard: don't register the listener twice
    if (_isListening) return;

    // Load persisted pre-books from database
    await _loadPreBooksFromDb();

    // Register the SMS listener callback with the Telephony API
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) {
        unawaited(_guardForegroundSmsProcessing(_processIncomingSms(msg)));
      },
      onBackgroundMessage: smsBackgroundMessageHandler,
    );

    _isListening = true;
    debugPrint('SMS Background Service started');
  }

  Future<void> _loadPreBooksFromDb() async {
    try {
      final pending = await _db.getPreBookPending();
      final now = DateTime.now();
      for (final entry in pending.entries) {
        final v = entry.value;
        final timestamp = v['timestamp'] as int? ?? 0;
        final createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        // Only load if not expired (48 hours)
        if (now.difference(createdAt).inHours <= 48) {
          _preBookPending[entry.key] = _PreBookContext(
            customerId: v['customerId'] as int,
            phoneNumber: v['phoneNumber'] as String,
            quantity: v['quantity'] as int,
            gallonType: v['gallonType'] as String?,
            address: v['address'] as String?,
            deliveryDay: v['deliveryDay'] as String,
            createdAt: createdAt,
          );
        }
      }
      debugPrint('Loaded ${_preBookPending.length} pre-books from database');
    } catch (e) {
      debugPrint('Failed to load pre-books: $e');
    }
  }

  Future<void> _savePreBooksToDb() async {
    try {
      final Map<String, Map<String, dynamic>> data = {};
      for (final entry in _preBookPending.entries) {
        final c = entry.value;
        data[entry.key] = {
          'customerId': c.customerId,
          'phoneNumber': c.phoneNumber,
          'quantity': c.quantity,
          'gallonType': c.gallonType,
          'address': c.address,
          'deliveryDay': c.deliveryDay,
          'timestamp': c.createdAt.millisecondsSinceEpoch,
        };
      }
      await _db.setPreBookPending(data);
    } catch (e) {
      debugPrint('Failed to save pre-books: $e');
    }
  }

  /// Stops the SMS listener gracefully.
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

  /// Changes the system operational mode.
  /// This affects how the system responds to DELIVER and DROP commands.
  void setMode(SystemMode mode) {
    _modeManager.setMode(mode);
  }

  /// Returns the current system mode (Operating, Staff Away, Full, Maintenance)
  SystemMode get currentMode => _modeManager.currentMode;

  /// Main entry point for processing an incoming SMS message.
  ///
  /// Flow: Extract sender/body → Parse command → Route to handler
  /// Each handler is responsible for validation, DB operations, and auto-reply.
  Future<void> _processIncomingSms(
    SmsMessage msg, {
    Telephony? smsSender,
  }) async {
    // Extract the sender phone number and message body from the SMS
    final sender = msg.address ?? '';
    final message = msg.body ?? '';

    await _processIncomingSmsPayload(
      sender: sender,
      message: message,
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
    // Ignore messages with no sender (can't reply without a phone number)
    if (sender.isEmpty) return;

    final effectiveSourceMessageId =
        sourceMessageId ??
        SmsSourceMessageId.build(
          sender: sender,
          message: message,
          timestamp: timestamp,
          subscriptionId: subscriptionId,
        );

    final claimed = await _db.claimIncomingSmsReceipt(
      messageId: effectiveSourceMessageId,
      phoneNumber: sender,
      message: message,
      smsTimestamp: timestamp,
    );
    if (!claimed) {
      debugPrint('Duplicate message skipped: $effectiveSourceMessageId');
      return;
    }

    try {
      debugPrint('SMS received from $sender: $message');
      if (serviceCenterAddress != null && serviceCenterAddress.isNotEmpty) {
        debugPrint('SMS service center: $serviceCenterAddress');
      }

      // Log incoming SMS for history
      await _db.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(sender),
        'message': message,
        'direction': 'incoming',
        'source_message_id': effectiveSourceMessageId,
        'sent_at': DateTime.now().toIso8601String(),
      });
      AppEventBus().notifyMessageReceived();

      // The background SMS callback can run in a separate Dart isolate, so the
      // singleton's in-memory mode may be stale. Refresh from the shared database
      // before checking delivery/drop gates or replying to STATUS.
      await _modeManager.loadPersistedMode();

      // Parse the raw message into a structured command object
      final parsed = SmsParser.parse(message);

      // Route to the appropriate handler based on the parsed command type
      switch (parsed.command) {
        case SmsCommand.deliver:
          await _handleDeliver(
            sender,
            parsed,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.drop:
          await _handleDrop(
            sender,
            parsed,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.yes:
          await _handleYes(
            sender,
            sourceMessageId: effectiveSourceMessageId,
            smsSender: smsSender,
          );
          break;
        case SmsCommand.status:
          await _handleStatus(sender, smsSender: smsSender);
          break;
        case SmsCommand.unknown:
          // Save unrecognized message as an order record for visibility in Messages tab
          await _saveUnrecognizedMessage(
            sender,
            message,
            'Unrecognized',
            sourceMessageId: effectiveSourceMessageId,
            quantity: parsed.quantity ?? 0,
            gallonType: _mapGallonType(parsed.gallonType),
          );
          // Send help text for unrecognized commands
          await _sendReply(
            sender,
            SmsParser.getUnknownCommandReply(),
            smsSender: smsSender,
          );
          break;
      }

      await _db.completeIncomingSmsReceipt(effectiveSourceMessageId);
    } catch (e) {
      await _db.failIncomingSmsReceipt(effectiveSourceMessageId, e);
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

  /// Handles the DELIVER command — the core order processing flow.
  ///
  /// Full pipeline per Logic Flowchart:
  /// 1. Check system mode — can we accept deliveries?
  /// 2. Look up customer by phone number
  /// 3. Validate zone/schedule for today
  /// 4. Check order cutoff time (before/after 7:00 AM)
  /// 5. Create order with appropriate status and delivery day
  /// 6. Send auto-reply
  Future<void> _handleDeliver(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);

    // Step 1: Mode gate — check if deliveries are accepted in current mode
    // Operating and staff-away modes accept deliveries; other modes reject.
    if (!_modeManager.canAcceptDelivery()) {
      await _saveUnrecognizedMessage(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Rejected: ${_modeManager.getDeliveryReply()}',
        'rejected',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: _mapGallonType(parsed.gallonType),
      );
      await _sendReply(
        sender,
        _modeManager.getDeliveryReply(),
        smsSender: smsSender,
      );
      return;
    }

    // Step 2: Customer lookup — find the sender in the customer database
    final customerData = await _db.getCustomerByPhone(normalizedSender);
    if (customerData == null) {
      // Save unrecognized message for visibility
      await _saveUnrecognizedMessage(
        sender,
        parsed.rawMessage,
        'Unregistered',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: _mapGallonType(parsed.gallonType),
      );
      // Phone number not registered — prompt them to register
      await _sendReply(
        sender,
        'Unknown number. Please register first or call the station.',
        smsSender: smsSender,
      );
      return;
    }

    // Step 3: Build customer object and fetch their active schedules
    // We use getCustomersWithBarangay to get the joined barangay data
    // needed for the Customer.fromMap() factory
    final customerJoined = await _db.getCustomerWithBarangayByPhone(
      normalizedSender,
    );
    if (customerJoined == null) {
      await _saveUnrecognizedMessage(
        sender,
        parsed.rawMessage,
        'Incomplete',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: _mapGallonType(parsed.gallonType),
      );
      await _sendReply(
        sender,
        'Customer profile is incomplete. Please call the station.',
        smsSender: smsSender,
      );
      return;
    }
    final customer = Customer.fromMap(customerJoined);

    // Fetch this customer's active schedule records from the database
    final schedulesData = await _db.getSchedulesForCustomer(customer.id!);
    // Convert raw maps to Schedule model objects for the validator
    final schedules = schedulesData.map((s) => Schedule.fromMap(s)).toList();
    // Get today's day name (e.g., 'Monday') for schedule comparison
    final today = DeliveryDays.getToday();

    // Step 4: Zone validation — is this customer's zone scheduled for today?
    final validation = ZoneValidator.validate(
      customer: customer,
      schedules: schedules,
      currentDay: today,
    );

    // If the customer's zone doesn't match today's schedule
    if (validation.result == ValidationResult.invalidDay) {
      // Save the pre-book offer for visibility
      await _saveUnrecognizedMessage(
        sender,
        'DELIVER ${parsed.quantity ?? 0} - Wrong Day (${validation.message})',
        'prebook',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
        gallonType: _mapGallonType(parsed.gallonType),
      );
      // Store the pre-book context so _handleYes knows the details
      // when the customer replies YES to the pre-book offer
      if (validation.correctDay != null) {
        final now = DateTime.now();
        _preBookPending[normalizedSender] = _PreBookContext(
          customerId: customer.id!,
          phoneNumber: normalizedSender,
          quantity: parsed.quantity ?? 0,
          gallonType: parsed.gallonType,
          address: parsed.address,
          deliveryDay: validation.correctDay!,
          createdAt: now,
        );
        await _savePreBooksToDb();
      }
      // Send the "Wrong Day" reply with pre-book offer
      await _sendReply(sender, validation.message!, smsSender: smsSender);
      return;
    }

    // Step 5: Cutoff time check — determine if order is for today or queued
    final now = DateTime.now();
    final cutoffHour = await _db.getCutoffHour();
    final cutoffMinute = await _db.getCutoffMinute();
    final isBeforeCutoff =
        now.hour < cutoffHour ||
        (now.hour == cutoffHour && now.minute < cutoffMinute);

    // Determine delivery day and status based on cutoff
    String? deliveryDay;
    OrderStatus orderStatus;
    final isStaffAway = _modeManager.currentMode == SystemMode.staffAway;

    if (isStaffAway) {
      deliveryDay = isBeforeCutoff
          ? today
          : _findNextAvailableDay(schedules, today);
      orderStatus = OrderStatus.pending;
    } else if (isBeforeCutoff) {
      // Before 7:00 AM → add to Today's Dispatch Manifest (FR-4.2)
      deliveryDay = today;
      orderStatus = OrderStatus.confirmed;
    } else {
      // After 7:00 AM → queue for PM trip or next scheduled day (FR-4.3)
      // Find the next delivery day for this customer's zone
      deliveryDay = _findNextAvailableDay(schedules, today);
      orderStatus = OrderStatus.pending;
    }

    // Step 6: Create the order in the database
    final order = Order(
      customerId: customer.id,
      phoneNumber: normalizedSender,
      type: OrderType.deliver,
      quantity: parsed.quantity ?? 0,
      // Pass through the gallon type from the parsed SMS (null if not specified)
      gallonType: _mapGallonType(parsed.gallonType),
      address: parsed.address,
      status: orderStatus,
      createdAt: now,
      deliveryDay: deliveryDay,
      sourceMessageId: sourceMessageId,
    );

    await _db.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();

    // Step 7: Send the appropriate auto-reply based on cutoff status
    if (isStaffAway) {
      await _sendReply(
        sender,
        _modeManager.getDeliveryReply(
          queuedDeliveryDay: isBeforeCutoff ? null : deliveryDay,
        ),
        smsSender: smsSender,
      );
    } else if (isBeforeCutoff) {
      // Order confirmed for today
      await _sendReply(
        sender,
        _modeManager.getDeliveryReply(),
        smsSender: smsSender,
      );
    } else {
      // Order queued — inform customer of the scheduled delivery day
      await _sendReply(
        sender,
        'Order received. Past today\'s cutoff time. '
        'Your order has been queued for $deliveryDay.',
        smsSender: smsSender,
      );
    }
  }

  /// Handles the DROP command — walk-in/drop-off at the station.
  ///
  /// DROP bypasses the Zone Validator entirely (per Logic Flowchart Section 4)
  /// because the customer is physically present at the station.
  /// The priority action is logging the order and (future) triggering the alarm.
  Future<void> _handleDrop(
    String sender,
    ParsedSms parsed, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);

    // Step 1: Mode gate — check if drop-offs are accepted
    // Only MAINTENANCE mode rejects drop-offs; all others allow them
    if (!_modeManager.canAcceptDrop()) {
      await _sendReply(
        sender,
        _modeManager.getDropReply(),
        smsSender: smsSender,
      );
      return;
    }

    // Step 2: Look up the customer (optional — drop-offs can be unregistered)
    final customerData = await _db.getCustomerByPhone(normalizedSender);
    final customerId = customerData?['id'] as int?;

    // Step 3: Create the drop-off order in the database
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

    // Step 4: Send the mode-appropriate auto-reply
    // (e.g., "Staff will assist" or "Leave bottles at designated area")
    final reply = _modeManager.getDropReply();
    await _sendReply(sender, reply, smsSender: smsSender);

    // Task 012 — Trigger loud alarm for walk-in customer
    await AlarmService.instance.trigger(
      phone: sender,
      qty: parsed.quantity ?? 0,
    );
  }

  /// Handles the YES command — confirms a pre-booking offer.
  ///
  /// When a customer gets a "Wrong Day" reply with a pre-book offer and
  /// responds YES, we create a pre-booked order for their correct delivery day.
  /// The pre-book context (quantity, day, etc.) was saved in [_preBookPending]
  /// when the original DELIVER command was processed.
  Future<void> _handleYes(
    String sender, {
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);

    // Look up the pre-book context for this phone number
    final context = _preBookPending[normalizedSender];

    if (context == null) {
      await _sendReply(
        sender,
        'No pending pre-book found. Please send a DELIVER command first.',
        smsSender: smsSender,
      );
      return;
    }

    // Check if pre-book has expired
    if (context.isExpired) {
      _preBookPending.remove(normalizedSender);
      await _sendReply(
        sender,
        'Pre-book offer has expired. Please send a new DELIVER command.',
        smsSender: smsSender,
      );
      return;
    }

    // Create the pre-booked order with the saved context
    final order = Order(
      customerId: context.customerId,
      phoneNumber: context.phoneNumber,
      type: OrderType.deliver,
      quantity: context.quantity,
      gallonType: _mapGallonType(context.gallonType),
      address: context.address,
      // Pre-booked orders start as pending until the delivery day arrives
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      // Set the delivery day to the correct scheduled day
      deliveryDay: context.deliveryDay,
      // Flag this as a pre-booked order for filtering/display
      isPreBook: true,
      sourceMessageId: sourceMessageId,
    );

    // Insert the pre-booked order into the database
    await _db.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();

    // Remove the pending context — each YES is a one-time confirmation
    _preBookPending.remove(normalizedSender);
    await _savePreBooksToDb();

    // Confirm the pre-booking to the customer
    await _sendReply(
      sender,
      'Pre-book confirmed! Your order of ${context.quantity} gallon(s) '
      'is scheduled for ${context.deliveryDay}.',
      smsSender: smsSender,
    );
  }

  /// Handles the STATUS command — returns the current system mode.
  Future<void> _handleStatus(String sender, {Telephony? smsSender}) async {
    final mode = _modeManager.currentMode;
    // Send the display name of the current mode (e.g., 'OPERATING', 'STAFF AWAY')
    await _sendReply(
      sender,
      'Current status: ${mode.displayName}',
      smsSender: smsSender,
    );
  }

  /// Sends an SMS reply to the specified phone number.
  /// Wraps the Telephony API call with error handling to prevent
  /// crashes if SMS sending fails (e.g., no signal, permission denied).
  Future<void> _sendReply(
    String phoneNumber,
    String message, {
    Telephony? smsSender,
  }) async {
    try {
      await (smsSender ?? _telephony).sendSms(
        to: phoneNumber,
        message: message,
      );
      debugPrint('Reply sent to $phoneNumber: $message');

      // Log outgoing SMS for history
      await _db.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'sent',
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log the failure but don't crash — the background service must stay alive
      debugPrint('Failed to send reply: $e');

      // Log failed SMS
      await _db.insertSmsMessage({
        'phone_number': PhoneNumberUtils.normalize(phoneNumber),
        'message': message,
        'direction': 'outgoing',
        'status': 'failed',
        'sent_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Finds the next available delivery day for a customer based on their schedules.
  ///
  /// Used when an order arrives after the cutoff time — the order is queued
  /// for the next scheduled day instead of today.
  /// Searches forward through the week starting from tomorrow.
  String _findNextAvailableDay(List<Schedule> schedules, String currentDay) {
    // Extract all allowed delivery days from the customer's schedules
    final allowedDays = schedules.map((s) => s.deliveryDay).toSet();

    // Get today's index in the week (0=Monday, 6=Sunday)
    final todayIndex = DeliveryDays.days.indexOf(currentDay);

    // Search forward starting from tomorrow, wrapping around the week
    for (int offset = 1; offset <= 7; offset++) {
      final checkIndex = (todayIndex + offset) % 7;
      final checkDay = DeliveryDays.days[checkIndex];
      // Return the first day that's in the customer's schedule
      if (allowedDays.contains(checkDay)) {
        return checkDay;
      }
    }

    // Fallback — shouldn't reach here if customer has at least one schedule
    return currentDay;
  }

  /// Maps a gallon type string from the SMS parser to the [GallonType] enum.
  ///
  /// The parser outputs lowercase strings ('new', 'old') or null.
  /// This converts them to the model's enum type for database storage.
  GallonType? _mapGallonType(String? gallonTypeStr) {
    switch (gallonTypeStr) {
      case 'new':
        return GallonType.newGallon;
      case 'old':
        return GallonType.oldGallon;
      default:
        // Not specified in the SMS — gallon type is optional
        return null;
    }
  }

  /// Saves an unrecognized/invalid message as an order record for visibility in Messages tab
  Future<void> _saveUnrecognizedMessage(
    String sender,
    String message,
    String status, {
    String? sourceMessageId,
    int quantity = 0,
    GallonType? gallonType,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final customerData = await _db.getCustomerByPhone(normalizedSender);
    final customerId = customerData?['id'] as int?;

    OrderStatus orderStatus;
    switch (status) {
      case 'rejected':
        orderStatus = OrderStatus.rejected;
        break;
      case 'Unregistered':
      case 'Incomplete':
      case 'prebook':
        orderStatus = OrderStatus.pending;
        break;
      default:
        orderStatus = OrderStatus.rejected;
    }

    final order = Order(
      customerId: customerId,
      phoneNumber: normalizedSender,
      type: OrderType.unrecognized,
      quantity: quantity,
      gallonType: gallonType,
      cancelReason: message,
      status: orderStatus,
      createdAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
    );
    await _db.insertOrder(order.toMap());
    AppEventBus().notifyOrderReceived();
    debugPrint('Saved message from $normalizedSender: $status');
  }
}

/// Holds the context of a pending pre-book offer for a specific customer.
///
/// When a DELIVER command is rejected due to a wrong day, we store the
/// order details here so that when the customer replies YES, we can
/// create the pre-booked order with the correct information.
class _PreBookContext {
  /// The customer's database ID
  final int customerId;

  /// The phone number that sent the original DELIVER command
  final String phoneNumber;

  /// The requested quantity from the original DELIVER command
  final int quantity;

  /// The gallon type from the original DELIVER command (null if not specified)
  final String? gallonType;

  /// The delivery address from the original DELIVER command
  final String? address;

  /// The correct delivery day offered in the "Wrong Day" reply
  final String deliveryDay;

  /// Timestamp when pre-book was created (for expiration)
  final DateTime createdAt;

  static const expirationHours = 48;

  _PreBookContext({
    required this.customerId,
    required this.phoneNumber,
    required this.quantity,
    this.gallonType,
    this.address,
    required this.deliveryDay,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    return DateTime.now().difference(createdAt).inHours > expirationHours;
  }
}
