// Task 011 — CustomerProvider: ChangeNotifier wrapping customer queries
// Provides reactive customer state to all screens via Provider
import 'package:flutter/foundation.dart';
import '../../database_helper.dart';

class CustomerProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get customers => _customers;
  bool get isLoading => _isLoading;
  int get count => _customers.length;

  /// Loads all customers with barangay info and notifies listeners
  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      _customers = await db.getCustomersWithBarangay();
    } catch (e) {
      debugPrint('CustomerProvider.loadCustomers error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Inserts a new customer and refreshes the list
  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    await DatabaseHelper.instance.insertCustomer(customerData);
    await loadCustomers();
  }

  /// Returns customer data by ID from cache
  Map<String, dynamic>? getById(int id) {
    try {
      return _customers.firstWhere((c) => c['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
