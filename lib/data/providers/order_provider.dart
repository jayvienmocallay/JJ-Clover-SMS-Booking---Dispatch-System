// Task 011 — OrderProvider: ChangeNotifier wrapping order queries
// Provides reactive order state to all screens via Provider
import 'package:flutter/foundation.dart';
import '../../database_helper.dart';

class OrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _todayOrders = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get todayOrders => _todayOrders;
  bool get isLoading => _isLoading;

  /// Stats computed from today's orders
  int get totalGallons =>
      _todayOrders.fold(0, (sum, o) => sum + ((o['quantity'] as int?) ?? 0));
  int get pendingCount =>
      _todayOrders.where((o) => o['status'] == 'pending').length;
  int get confirmedCount =>
      _todayOrders.where((o) => o['status'] == 'confirmed').length;

  /// Loads today's orders from the database and notifies listeners
  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      _todayOrders = await db.getTodayOrders();
    } catch (e) {
      debugPrint('OrderProvider.loadOrders error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Updates an order's status and refreshes the list
  Future<void> updateStatus(int orderId, String newStatus) async {
    await DatabaseHelper.instance.updateOrderStatus(orderId, newStatus);
    await loadOrders();
  }

  /// Inserts a new order and refreshes the list
  Future<void> addOrder(Map<String, dynamic> orderData) async {
    await DatabaseHelper.instance.insertOrder(orderData);
    await loadOrders();
  }
}
