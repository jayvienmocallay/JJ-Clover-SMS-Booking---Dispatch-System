// Task 011 — Repository pattern: single point of data access for order operations.
// Providers and UI depend on this interface, not on DatabaseHelper directly.
import '../../database_helper.dart';

class OrderRepository {
  Future<List<Map<String, dynamic>>> getOrders({
    String? where,
    List<Object?>? whereArgs,
  }) {
    return DatabaseHelper.instance.getOrders(
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> insertOrder(Map<String, dynamic> orderData) {
    return DatabaseHelper.instance.insertOrder(orderData);
  }

  Future<int> updateOrderStatus(
    int id,
    String status, {
    String? reason,
    String? notes,
  }) {
    return DatabaseHelper.instance.updateOrderStatus(
      id,
      status,
      reason: reason,
      notes: notes,
    );
  }

  Future<List<Map<String, dynamic>>> getDeliveryLogsForOrder(int orderId) {
    return DatabaseHelper.instance.getDeliveryLogsForOrder(orderId);
  }

  Future<List<Map<String, dynamic>>> getDeliveryLogs() {
    return DatabaseHelper.instance.getDeliveryLogs();
  }

  Future<List<Map<String, dynamic>>> getTodayDeliveryLogs() {
    return DatabaseHelper.instance.getTodayDeliveryLogs();
  }
}
