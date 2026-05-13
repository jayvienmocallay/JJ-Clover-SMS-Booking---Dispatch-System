/// Holds the context of a pending pre-book offer for a specific customer.
class PreBookContext {
  final int customerId;
  final String phoneNumber;
  final int quantity;
  final String? address;
  final String deliveryDay;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final int? pendingOrderId;

  static const expirationHours = 48;

  PreBookContext({
    required this.customerId,
    required this.phoneNumber,
    required this.quantity,
    this.address,
    required this.deliveryDay,
    DateTime? scheduledFor,
    DateTime? createdAt,
    this.pendingOrderId,
  }) : scheduledFor = scheduledFor ?? createdAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt).inHours > expirationHours;
}
