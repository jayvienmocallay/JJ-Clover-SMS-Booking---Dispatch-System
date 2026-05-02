// Task 011 — Repository pattern: single point of data access for delivery log operations.
import '../../database_helper.dart';

class DeliveryLogRepository {
  Future<List<Map<String, dynamic>>> getDeliveryLogs() {
    return DatabaseHelper.instance.getDeliveryLogs();
  }

  Future<List<Map<String, dynamic>>> getDeliveryLogsForOrder(int orderId) {
    return DatabaseHelper.instance.getDeliveryLogsForOrder(orderId);
  }

  Future<List<Map<String, dynamic>>> getDeliveryLogsForCustomer(
    int customerId,
  ) {
    return DatabaseHelper.instance.getDeliveryLogsForCustomer(customerId);
  }

  Future<List<Map<String, dynamic>>> getTodayDeliveryLogs() {
    return DatabaseHelper.instance.getTodayDeliveryLogs();
  }
}
