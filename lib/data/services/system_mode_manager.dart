import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';

class SystemModeManager extends ChangeNotifier {
  SystemMode _currentMode = SystemMode.operating;

  SystemMode get currentMode => _currentMode;

  void setMode(SystemMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  bool canAcceptDelivery() {
    switch (_currentMode) {
      case SystemMode.operating:
        return true;
      case SystemMode.staffAway:
      case SystemMode.full:
      case SystemMode.maintenance:
        return false;
    }
  }

  bool canAcceptDrop() {
    switch (_currentMode) {
      case SystemMode.operating:
      case SystemMode.staffAway:
      case SystemMode.full:
        return true;
      case SystemMode.maintenance:
        return false;
    }
  }

  String getDeliveryReply() {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Order Confirmed. Delivery is being prepared.';
      case SystemMode.staffAway:
        return 'Order Received. Staff is currently out delivering. '
            'We will process this upon return.';
      case SystemMode.full:
        return 'We are fully booked for today. Please order for the next schedule.';
      case SystemMode.maintenance:
        return 'System under maintenance. We are currently closed.';
    }
  }

  String getDropReply() {
    switch (_currentMode) {
      case SystemMode.operating:
        return 'Order received, staff will assist.';
      case SystemMode.staffAway:
        return 'Order received. Please leave bottles in the designated area. '
            'We will process upon return.';
      case SystemMode.full:
        return 'Order received. Please wait for confirmation.';
      case SystemMode.maintenance:
        return 'System under maintenance. We are currently closed.';
    }
  }
}
