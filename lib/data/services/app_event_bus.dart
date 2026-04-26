import 'dart:async';

class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();

  factory AppEventBus() => _instance;

  AppEventBus._internal();

  final _messageReceivedController = StreamController<void>.broadcast();
  final _orderReceivedController = StreamController<void>.broadcast();

  Stream<void> get onMessageReceived => _messageReceivedController.stream;
  Stream<void> get onOrderReceived => _orderReceivedController.stream;

  void notifyMessageReceived() => _messageReceivedController.add(null);
  void notifyOrderReceived() => _orderReceivedController.add(null);

  void dispose() {
    _messageReceivedController.close();
    _orderReceivedController.close();
  }
}
