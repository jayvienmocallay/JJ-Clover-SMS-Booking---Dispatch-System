// Task 005 — Delivery Log data model (per-household accountability tracking)
/// Records a per-household gallon delivery for accountability and loss tracking.
///
/// Each log entry captures how many gallons were delivered to a specific
/// customer by a specific staff member on a given trip. This supports
/// the Scope & Zone Mapping requirement for per-household delivery logging
/// and inventory reconciliation.
class DeliveryLog {
  /// Unique database identifier (null for unsaved records)
  final int? id;

  /// The order this delivery fulfills (references orders table)
  final int orderId;

  /// The customer who received the delivery (references customers table)
  final int customerId;

  /// The staff member who performed the delivery (references future staff table)
  final int? staffId;

  /// Number of gallons actually delivered to this household
  final int quantityDelivered;

  /// Optional notes about the delivery (e.g., 'left at gate', 'short 1 gallon')
  final String? notes;

  /// Number of empty gallon containers returned by the customer on this trip
  final int? returnedContainers;

  /// Payment method used: 'cash', 'gcash', 'credit', or null if not recorded
  final String? paymentMethod;

  /// Timestamp when the delivery was recorded
  final DateTime deliveredAt;

  DeliveryLog({
    this.id,
    required this.orderId,
    required this.customerId,
    this.staffId,
    required this.quantityDelivered,
    this.notes,
    this.returnedContainers,
    this.paymentMethod,
    required this.deliveredAt,
  });

  /// Creates a [DeliveryLog] instance from a database row map.
  factory DeliveryLog.fromMap(Map<String, dynamic> map) {
    return DeliveryLog(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      customerId: map['customer_id'] as int,
      staffId: map['staff_id'] as int?,
      quantityDelivered: map['quantity_delivered'] as int,
      notes: map['notes'] as String?,
      returnedContainers: map['returned_containers'] as int?,
      paymentMethod: map['payment_method'] as String?,
      // Parse ISO 8601 timestamp string back to DateTime
      deliveredAt: DateTime.parse(map['delivered_at'] as String),
    );
  }

  /// Converts this delivery log to a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'customer_id': customerId,
      if (staffId != null) 'staff_id': staffId,
      'quantity_delivered': quantityDelivered,
      if (notes != null) 'notes': notes,
      if (returnedContainers != null) 'returned_containers': returnedContainers,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      // Store DateTime as ISO 8601 string for consistent parsing
      'delivered_at': deliveredAt.toIso8601String(),
    };
  }
}
