// Task 014 — Local push notifications for SMS orders and alerts
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for OS-level push notifications.
///
/// Handles notification channel creation and display of heads-up banners
/// for order events and SMS messages. Safe to call from background isolates.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  static PushNotificationService get instance => _instance;

  /// Flutter local notifications plugin instance
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Counter for unique notification IDs
  int _notificationId = 0;

  /// Whether the service has been initialized
  bool _isInitialized = false;

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
  Future<void> _createNotificationChannels() async {
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
  /// Safe to call from background isolates.
  static Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {
    return _instance._showNotification(
      title: title,
      body: body,
      channelId: 'orders_channel',
    );
  }

  /// Displays a default-priority notification for message events.
  /// Safe to call from background isolates.
  static Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    return _instance._showNotification(
      title: title,
      body: body,
      channelId: 'messages_channel',
    );
  }

  /// Internal method to display a notification.
  Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
  }) async {
    try {
      final notificationId = _notificationId++;

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

      debugPrint('Notification shown: $title – $body');
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
