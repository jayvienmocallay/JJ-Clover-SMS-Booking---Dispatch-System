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
  List<Map<String, dynamic>> _upcomingPreBookOrders = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _orderEventSubscription;
  bool _disposed = false;

  List<Map<String, dynamic>> get todayOrders => _todayOrders;
  List<Map<String, dynamic>> get upcomingPreBookOrders =>
      _upcomingPreBookOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _subscribeToOrderEvents() {
    _orderEventSubscription = AppEventBus().onOrderReceived.listen((_) {
      loadOrders();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _orderEventSubscription?.cancel();
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
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
    if (_disposed) return;

    _isLoading = true;
    _error = null;
    _notifyIfActive();

    try {
      final results = await Future.wait([
        _repository.getTodayOrders(),
        _repository.getUpcomingPreBookOrders(),
      ]);
      if (_disposed) return;
      _todayOrders = results[0];
      _upcomingPreBookOrders = results[1];
    } catch (e) {
      if (_disposed) return;
      debugPrint('OrderProvider.loadOrders error: $e');
      _error = e.toString();
    }

    _isLoading = false;
    _notifyIfActive();
  }

  /// Updates an order's status and refreshes the list
  Future<bool> updateStatus(
    int orderId,
    String newStatus, {
    String? reason,
    String? notes,
  }) async {
    _error = null;
    try {
      final updated = await _repository.updateOrderStatus(
        orderId,
        newStatus,
        reason: reason,
        notes: notes,
      );
      _ensureRowsChanged(updated, 'No order was updated.');
      await loadOrders();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  Future<bool> assignStaffToOrder(int orderId, int staffId) async {
    _error = null;
    try {
      final updated = await _repository.assignStaffToOrder(orderId, staffId);
      _ensureRowsChanged(updated, 'No order was updated.');
      await loadOrders();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  Future<bool> recordDeliveryIssue(
    int orderId, {
    required String note,
    required bool keepForRedispatch,
  }) async {
    _error = null;
    try {
      final updated = await _repository.recordDeliveryIssue(
        orderId,
        note: note,
        keepForRedispatch: keepForRedispatch,
      );
      _ensureRowsChanged(updated, 'No order was updated.');
      await loadOrders();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  Future<bool> completeOrder(
    int orderId, {
    int? quantityDelivered,
    int? returnedContainers,
    bool cashCollected = false,
    String? notes,
    int? staffId,
  }) async {
    _error = null;
    try {
      final updated = await _repository.completeOrder(
        orderId,
        quantityDelivered: quantityDelivered,
        returnedContainers: returnedContainers,
        cashCollected: cashCollected,
        notes: notes,
        staffId: staffId,
      );
      _ensureRowsChanged(updated, 'No order was updated.');
      await loadOrders();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  /// Inserts a new order and refreshes the list
  Future<bool> addOrder(Map<String, dynamic> orderData) async {
    _error = null;
    try {
      final insertedId = await _repository.insertOrder(orderData);
      _ensureRowsChanged(insertedId, 'Order was not created.');
      await loadOrders();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  void clearError() {
    _error = null;
    _notifyIfActive();
  }

  void _ensureRowsChanged(int result, String message) {
    if (result == 0) {
      throw StateError(message);
    }
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }
}
