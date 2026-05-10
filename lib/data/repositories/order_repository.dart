// Task 011 — Repository pattern: single point of data access for order operations.
// Providers and UI depend on this interface, not on DatabaseHelper directly.
import '../../database_helper.dart';
import '../../core/utils/phone_number_utils.dart';

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

  Future<List<Map<String, dynamic>>> getTodayOrders() {
    return DatabaseHelper.instance.getTodayOrders();
  }

  Future<List<Map<String, dynamic>>> getOrderHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? type,
    String? search,
  }) {
    return DatabaseHelper.instance.getOrderHistory(
      startDate: startDate,
      endDate: endDate,
      status: status,
      type: type,
      search: search,
    );
  }

  Future<List<Map<String, dynamic>>> getCustomerOrderHistory(
    String phoneNumber,
  ) {
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    return DatabaseHelper.instance.getOrders(
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
    );
  }

  Future<List<Map<String, dynamic>>> getInvalidSmsOrders() {
    return DatabaseHelper.instance.getOrders(
      where: 'type = ?',
      whereArgs: ['unrecognized'],
    );
  }

  Future<List<Map<String, dynamic>>> getOrdersNeedingReview() {
    return DatabaseHelper.instance.getOrders(
      where: 'type = ? OR status IN (?, ?)',
      whereArgs: ['unrecognized', 'cancelled', 'rejected'],
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

  Future<int> assignStaffToOrder(int id, int staffId) async {
    final db = await DatabaseHelper.instance.database;
    return db.update(
      'orders',
      {'staff_id': staffId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> recordDeliveryIssue(
    int id, {
    required String note,
    required bool keepForRedispatch,
  }) {
    return updateOrderStatus(
      id,
      keepForRedispatch ? 'confirmed' : 'rejected',
      reason: note,
    );
  }

  Future<int> completeOrder(
    int id, {
    int? quantityDelivered,
    int? returnedContainers,
    bool cashCollected = false,
    String? notes,
    int? staffId,
  }) {
    return DatabaseHelper.instance.completeOrder(
      id,
      quantityDelivered: quantityDelivered,
      returnedContainers: returnedContainers,
      cashCollected: cashCollected,
      notes: notes,
      staffId: staffId,
    );
  }

  Future<List<Map<String, dynamic>>> getDeliveryLogsForOrder(int orderId) {
    return DatabaseHelper.instance.getDeliveryLogsForOrder(orderId);
  }
}
