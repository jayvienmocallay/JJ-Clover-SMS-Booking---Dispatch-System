// Task 014 — Local push notifications for SMS orders and alerts
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for OS-level push notifications.
///
/// Handles notification channel creation and display of heads-up banners
/// for order events and SMS messages. Works from both foreground and
/// background isolates by using the platform-agnostic plugin API.
/// Deduplicates notifications per sender to avoid spam from multiple orders.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  static PushNotificationService get instance => _instance;

  /// Flutter local notifications plugin instance
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Maps phone numbers to their last notification type and time
  /// Used to deduplicate rapid-fire notifications from the same sender
  /// Key: phone number, Value: (notificationType, timestamp)
  static final Map<String, (String, DateTime)> _lastNotificationPerSender = {};

  /// Rate limit for notifications per sender (milliseconds)
  /// Prevents notification spam from the same sender within this window
  static const int _notificationRateLimitMs = 5000; // 5 seconds


  /// Whether the service has been initialized
  static bool _isInitialized = false;

  PushNotificationService._internal();

  /// Initializes the notification service with Android channels.
  /// Must be called once at app startup (main.dart).
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings);

    // Create notification channels for Android 8.0+
    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('Push Notification Service initialized');
  }

  /// Creates Android notification channels with different importance levels.
  ///
  /// orders_channel (high): DELIVER, DROP, YES, pre-book orders
  /// messages_channel (default): unrecognized/rejected SMS
  static Future<void> _createNotificationChannels() async {
    const ordersChannel = AndroidNotificationChannel(
      'orders_channel',
      'Order Notifications',
      description: 'Notifications for new delivery orders and updates',
      importance: Importance.high,
    );

    const messagesChannel = AndroidNotificationChannel(
      'messages_channel',
      'Message Notifications',
      description: 'Notifications for unrecognized or rejected SMS messages',
      importance: Importance.defaultImportance,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(ordersChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);

    debugPrint('Notification channels created');
  }

  /// Displays a high-priority notification for order events.
  /// Deduplicates rapid notifications from the same sender.
  /// Safe to call from background isolates.
  static Future<void> showOrderNotification({
    required String title,
    required String body,
    String? sender,
  }) async {
    // Extract phone number from body if sender not provided
    final phoneNumber = sender ?? _extractPhoneFromBody(body);

    if (_shouldShowNotification(phoneNumber, 'order')) {
      await _showNotification(
        title: title,
        body: body,
        channelId: 'orders_channel',
        sender: phoneNumber,
        notificationType: 'order',
      );
    }
  }

  /// Displays a default-priority notification for message events.
  /// Deduplicates rapid notifications from the same sender.
  /// Safe to call from background isolates.
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? sender,
  }) async {
    // Extract phone number from body if sender not provided
    final phoneNumber = sender ?? _extractPhoneFromBody(body);

    if (_shouldShowNotification(phoneNumber, 'message')) {
      await _showNotification(
        title: title,
        body: body,
        channelId: 'messages_channel',
        sender: phoneNumber,
        notificationType: 'message',
      );
    }
  }

  /// Checks if a notification should be shown based on rate limiting.
  /// Returns false if the same sender sent a notification within the rate limit window.
  static bool _shouldShowNotification(String? sender, String notificationType) {
    if (sender == null || sender.isEmpty) {
      return true; // Show if we can't identify sender
    }

    final key = sender;
    final lastNotification = _lastNotificationPerSender[key];
    final now = DateTime.now();

    // If no previous notification, show it
    if (lastNotification == null) {
      return true;
    }

    final (lastType, lastTime) = lastNotification;
    final timeSinceLastMs = now.difference(lastTime).inMilliseconds;

    // If same notification type and within rate limit, skip it
    if (lastType == notificationType &&
        timeSinceLastMs < _notificationRateLimitMs) {
      debugPrint(
        'Notification rate limited for $sender: '
        '${timeSinceLastMs}ms since last $notificationType notification'
      );
      return false;
    }

    return true;
  }

  /// Extracts a phone number from the notification body text.
  /// Looks for patterns like "from +1234567890" or "from 1234567890".
  static String? _extractPhoneFromBody(String body) {
    final regex = RegExp(r'from\s+([\+\d\s\-\(\)]+?)(?:\s|–|$)');
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.replaceAll(RegExp(r'\s|\(|\)|-'), '');
    }
    return null;
  }

  /// Internal method to display a notification.
  /// Works from both foreground and background isolates.
  static Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
    String? sender,
    String? notificationType,
  }) async {
    try {
      // Generate a notification ID per sender to consolidate their notifications
      final notificationId = _getNotificationIdForSender(sender);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'orders_channel'
            ? 'Order Notifications'
            : 'Message Notifications',
        priority: channelId == 'orders_channel'
            ? Priority.high
            : Priority.defaultPriority,
        importance: channelId == 'orders_channel'
            ? Importance.high
            : Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _plugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );

      // Track this notification for rate limiting
      if (sender != null && notificationType != null) {
        _lastNotificationPerSender[sender] = (notificationType, DateTime.now());
      }

      debugPrint('Notification shown: $title – $body');
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Gets a consistent notification ID for a sender.
  /// This consolidates multiple notifications from the same sender.
  static int _getNotificationIdForSender(String? sender) {
    if (sender == null || sender.isEmpty) {
      return 1000; // Default ID for unknown senders
    }

    // Use sender's hash to generate a consistent ID
    // This ensures notifications from the same sender replace previous ones
    return sender.hashCode.abs() % 10000 + 1000;
  }
}
