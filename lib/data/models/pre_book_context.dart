/// Holds the context of a pending pre-book offer for a specific customer.
///
/// When a DELIVER command is rejected due to a wrong day, we store the
/// order details here so that when the customer replies YES, we can
/// create the pre-booked order with the correct information.
class PreBookContext {
  final int customerId;
  final String phoneNumber;
  final int quantity;
  final String? gallonType;
  final String? address;
  final String deliveryDay;
  final DateTime createdAt;

  static const expirationHours = 48;

  PreBookContext({
    required this.customerId,
    required this.phoneNumber,
    required this.quantity,
    this.gallonType,
    this.address,
    required this.deliveryDay,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt).inHours > expirationHours;
}
