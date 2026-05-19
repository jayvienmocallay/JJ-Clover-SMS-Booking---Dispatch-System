// Task 011 — Repository pattern: single point of data access for customer operations.
// Providers and UI depend on this interface, not on DatabaseHelper directly.
import '../../database_helper.dart';
export '../../database_helper.dart'
    show
        CustomerPhoneAlreadyExistsException,
        CustomerPhoneIdentityMigrationException;

class CustomerRepository {
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() {
    return DatabaseHelper.instance.getCustomersWithBarangay();
  }

  Future<List<Map<String, dynamic>>> getCustomers() {
    return DatabaseHelper.instance.getCustomers();
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phoneNumber) {
    return DatabaseHelper.instance.getCustomerByPhone(phoneNumber);
  }

  Future<Map<String, dynamic>?> getCustomerWithBarangayByPhone(
    String phoneNumber,
  ) {
    return DatabaseHelper.instance.getCustomerWithBarangayByPhone(phoneNumber);
  }

  Future<int> insertCustomer(Map<String, dynamic> customerData) {
    return DatabaseHelper.instance.insertCustomer(customerData);
  }

  Future<int> deleteCustomer(int id) {
    return DatabaseHelper.instance.deleteCustomer(id);
  }

  Future<bool> deleteCustomerByPhone(String phoneNumber) {
    return DatabaseHelper.instance.deleteCustomerByPhone(phoneNumber);
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> data) {
    return DatabaseHelper.instance.updateCustomer(id, data);
  }

  Future<int> updateCustomerContactFlags(
    int id, {
    bool? isMuted,
    bool? isBlocked,
    bool? isSpam,
  }) {
    return DatabaseHelper.instance.updateCustomerContactFlags(
      id,
      isMuted: isMuted,
      isBlocked: isBlocked,
      isSpam: isSpam,
    );
  }
}
