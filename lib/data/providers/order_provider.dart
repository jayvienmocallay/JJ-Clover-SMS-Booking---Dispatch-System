// Task 011 — OrderProvider: ChangeNotifier wrapping order queries
// Provides reactive order state to all screens via Provider
import 'package:flutter/foundation.dart';
import '../../database_helper.dart';

class OrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _todayOrders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get todayOrders => _todayOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stats computed from today's orders
  Iterable<Map<String, dynamic>> get _operationalOrders =>
      _todayOrders.where((o) => o['type'] != 'unrecognized');

  int get totalGallons => _operationalOrders.fold(
    0,
    (sum, o) => sum + ((o['quantity'] as int?) ?? 0),
  );
  int get pendingCount =>
      _operationalOrders.where((o) => o['status'] == 'pending').length;
  int get confirmedCount =>
      _operationalOrders.where((o) => o['status'] == 'confirmed').length;

  /// Loads today's orders from the database and notifies listeners
  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      _todayOrders = await db.getTodayOrders();
    } catch (e) {
      debugPrint('OrderProvider.loadOrders error: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Updates an order's status and refreshes the list
  Future<void> updateStatus(
    int orderId,
    String newStatus, {
    String? reason,
    String? notes,
  }) async {
    _error = null;
    try {
      await DatabaseHelper.instance.updateOrderStatus(
        orderId,
        newStatus,
        reason: reason,
        notes: notes,
      );
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Inserts a new order and refreshes the list
  Future<void> addOrder(Map<String, dynamic> orderData) async {
    _error = null;
    try {
      await DatabaseHelper.instance.insertOrder(orderData);
      await loadOrders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
