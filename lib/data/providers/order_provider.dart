// Task 011 — OrderProvider: ChangeNotifier wrapping order queries
// Provides reactive order state to all screens via Provider
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';
import '../services/app_event_bus.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider(this._repository) {
    _subscribeToOrderEvents();
  }

  final OrderRepository _repository;

  List<Map<String, dynamic>> _todayOrders = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _orderEventSubscription;

  List<Map<String, dynamic>> get todayOrders => _todayOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _subscribeToOrderEvents() {
    _orderEventSubscription = AppEventBus().onOrderReceived.listen((_) {
      loadOrders();
    });
  }

  @override
  void dispose() {
    _orderEventSubscription?.cancel();
    super.dispose();
  }

  /// Stats computed from today's orders
  Iterable<Map<String, dynamic>> get _operationalOrders =>
      _todayOrders.where((o) => o['type'] != 'unrecognized');

  int get totalGallons => _operationalOrders
      .where((o) {
        final s = o['status'] as String? ?? '';
        return s != 'cancelled' && s != 'rejected';
      })
      .fold(0, (sum, o) => sum + ((o['quantity'] as int?) ?? 0));
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
      _todayOrders = await _repository.getOrders();
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
      await _repository.updateOrderStatus(
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
      await _repository.insertOrder(orderData);
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
