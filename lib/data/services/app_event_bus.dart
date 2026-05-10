import 'dart:async';

class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();

  factory AppEventBus() => _instance;

  AppEventBus._internal();

  final _messageReceivedController = StreamController<void>.broadcast();
  final _orderReceivedController = StreamController<void>.broadcast();

  Stream<void> get onMessageReceived => _messageReceivedController.stream;
  Stream<void> get onOrderReceived => _orderReceivedController.stream;

  void notifyMessageReceived() {
    if (_messageReceivedController.isClosed) return;
    try {
      _messageReceivedController.add(null);
    } catch (_) {
      // Event delivery must never break SMS processing or auto-replies.
    }
  }

  void notifyOrderReceived() {
    if (_orderReceivedController.isClosed) return;
    try {
      _orderReceivedController.add(null);
    } catch (_) {
      // Event delivery must never break SMS processing or order creation.
    }
  }

  void dispose() {
    if (!_messageReceivedController.isClosed) {
      _messageReceivedController.close();
    }
    if (!_orderReceivedController.isClosed) {
      _orderReceivedController.close();
    }
  }
}
