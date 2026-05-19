// Task 011 — CustomerProvider: ChangeNotifier wrapping customer queries
// Provides reactive customer state to all screens via Provider
import 'package:flutter/foundation.dart';
import '../repositories/customer_repository.dart';

class CustomerProvider extends ChangeNotifier {
  CustomerProvider(this._repository);

  final CustomerRepository _repository;

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<Map<String, dynamic>> get customers => _customers;
  bool get isLoading => _isLoading;
  int get count => _customers.length;
  String? get error => _error;

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  /// Loads all customers with barangay info and notifies listeners
  Future<void> loadCustomers() async {
    if (_disposed) return;
    _isLoading = true;
    _error = null;
    _notifyIfActive();

    try {
      _customers = await _repository.getCustomersWithBarangay();
    } catch (e) {
      debugPrint('CustomerProvider.loadCustomers error: $e');
      _error = e.toString();
    }

    if (_disposed) return;
    _isLoading = false;
    _notifyIfActive();
  }

  /// Inserts a new customer and refreshes the list
  Future<bool> addCustomer(Map<String, dynamic> customerData) async {
    _error = null;
    try {
      final insertedId = await _repository.insertCustomer(customerData);
      _ensureRowsChanged(insertedId, 'Customer was not created.');
      await loadCustomers();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  /// Deletes a customer by ID
  Future<bool> deleteCustomer(int customerId) async {
    _error = null;
    try {
      final deleted = await _repository.deleteCustomer(customerId);
      _ensureRowsChanged(deleted, 'No customer was deleted.');
      await loadCustomers();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  /// Updates customer information
  Future<bool> updateCustomer(
    int customerId,
    Map<String, dynamic> customerData,
  ) async {
    _error = null;
    try {
      final updated = await _repository.updateCustomer(
        customerId,
        customerData,
      );
      _ensureRowsChanged(updated, 'No customer was updated.');
      await loadCustomers();
      return _error == null;
    } catch (e) {
      _error = _errorMessage(e);
      _notifyIfActive();
      return false;
    }
  }

  /// Returns customer data by ID from cache
  Map<String, dynamic>? getById(int id) {
    try {
      return _customers.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    _notifyIfActive();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
