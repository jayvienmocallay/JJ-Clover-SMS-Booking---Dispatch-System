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
  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    _error = null;
    try {
      await _repository.insertCustomer(customerData);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      _notifyIfActive();
    }
  }

  /// Deletes a customer by ID
  Future<void> deleteCustomer(int customerId) async {
    _error = null;
    try {
      await _repository.deleteCustomer(customerId);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      _notifyIfActive();
    }
  }

  /// Updates customer information
  Future<void> updateCustomer(
    int customerId,
    Map<String, dynamic> customerData,
  ) async {
    _error = null;
    try {
      await _repository.updateCustomer(customerId, customerData);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      _notifyIfActive();
      rethrow;
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
}
