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

  /// Classification of gallons delivered: 'new' (household) or 'old' (store)
  final String? gallonType;

  /// Optional notes about the delivery (e.g., 'left at gate', 'short 1 gallon')
  final String? notes;

  /// Timestamp when the delivery was recorded
  final DateTime deliveredAt;

  DeliveryLog({
    this.id,
    required this.orderId,
    required this.customerId,
    this.staffId,
    required this.quantityDelivered,
    this.gallonType,
    this.notes,
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
      gallonType: map['gallon_type'] as String?,
      notes: map['notes'] as String?,
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
      if (gallonType != null) 'gallon_type': gallonType,
      if (notes != null) 'notes': notes,
      // Store DateTime as ISO 8601 string for consistent parsing
      'delivered_at': deliveredAt.toIso8601String(),
    };
  }
}
