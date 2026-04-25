// Task 003 — Order data model (core entity)
// Task 005 — Added GallonType enum, gallonType field, and staffId field
/// The type of order: delivery to customer or walk-in drop-off at station
enum OrderType { deliver, drop, unrecognized }

/// Tracks the lifecycle of an order from creation to completion
enum OrderStatus { pending, confirmed, completed, cancelled, rejected }

/// Classifies gallons to prevent mixing between household and store use.
/// Based on Scope & Zone Mapping document business rule:
/// - [newGallon]: For household delivery (sealed, new water)
/// - [oldGallon]: For store/refill use only
enum GallonType { newGallon, oldGallon }

/// Represents a customer order placed via SMS or walk-in.
///
/// Orders are created by the background SMS service when a valid
/// DELIVER or DROP command is received and validated.
class Order {
  /// Unique database identifier (null for unsaved records)
  final int? id;

  /// References the customer who placed the order (null if unregistered)
  final int? customerId;

  /// The phone number that sent the SMS order
  final String phoneNumber;

  /// Whether this is a delivery or walk-in drop-off
  final OrderType type;

  /// Number of gallons requested
  final int quantity;

  /// Classification of gallons: new (household) or old (store use)
  final GallonType? gallonType;

  /// Optional delivery address (only for DELIVER commands with address)
  final String? address;

  /// Current status in the order lifecycle
  final OrderStatus status;

  /// Timestamp when the order was created
  final DateTime createdAt;

  /// The scheduled delivery day (e.g., 'Monday'), null if not yet assigned
  final String? deliveryDay;

  /// Whether this order was pre-booked for a future delivery day
  final bool isPreBook;

  /// The staff member assigned to fulfill this order (null if unassigned)
  final int? staffId;

  /// Reason for cancellation (set when order is rejected)
  final String? cancelReason;

  Order({
    this.id,
    this.customerId,
    required this.phoneNumber,
    required this.type,
    required this.quantity,
    this.gallonType,
    this.address,
    required this.status,
    required this.createdAt,
    this.deliveryDay,
    this.isPreBook = false,
    this.staffId,
    this.cancelReason,
  });

  /// Creates an [Order] instance from a database row map.
  /// Handles type conversions: strings to enums, integers to booleans.
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      phoneNumber: map['phone_number'] as String,
      // Map string 'deliver'/'drop'/'unrecognized' back to the OrderType enum
      type: _parseType(map['type'] as String?),
      quantity: map['quantity'] as int,
      // Map string 'new'/'old' back to GallonType enum, null if not set
      gallonType: _parseGallonType(map['gallon_type'] as String?),
      address: map['address'] as String?,
      // Map string status back to OrderStatus enum
      status: _parseStatus(map['status'] as String),
      // Parse ISO 8601 date string back to DateTime
      createdAt: DateTime.parse(map['created_at'] as String),
      deliveryDay: map['delivery_day'] as String?,
      // SQLite stores booleans as 0/1 integers
      isPreBook: (map['is_pre_book'] as int?) == 1,
      staffId: map['staff_id'] as int?,
      cancelReason: map['cancel_reason'] as String?,
    );
  }

  /// Converts a type string from the database to an [OrderType] enum.
  static OrderType _parseType(String? type) {
    switch (type) {
      case 'deliver':
        return OrderType.deliver;
      case 'drop':
        return OrderType.drop;
      case 'unrecognized':
        return OrderType.unrecognized;
      default:
        return OrderType.unrecognized;
    }
  }

  /// Converts a status string from the database to an [OrderStatus] enum.
  /// Defaults to [OrderStatus.pending] if the string is unrecognized.
  static OrderStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        // Fallback for any unexpected status value
        return OrderStatus.pending;
    }
  }

  /// Converts a gallon type string from the database to a [GallonType] enum.
  /// Returns null if the value is not set or unrecognized.
  static GallonType? _parseGallonType(String? gallonType) {
    switch (gallonType) {
      case 'new':
        return GallonType.newGallon;
      case 'old':
        return GallonType.oldGallon;
      default:
        // null or unrecognized — gallon type not specified
        return null;
    }
  }

  /// Converts this order to a map for database insertion.
  /// Enum values are stored as readable strings, booleans as 0/1 integers.
  Map<String, dynamic> toMap() {
    String typeStr;
    switch (type) {
      case OrderType.deliver:
        typeStr = 'deliver';
        break;
      case OrderType.drop:
        typeStr = 'drop';
        break;
      case OrderType.unrecognized:
        typeStr = 'unrecognized';
        break;
    }

    String statusStr;
    switch (status) {
      case OrderStatus.pending:
        statusStr = 'pending';
        break;
      case OrderStatus.confirmed:
        statusStr = 'confirmed';
        break;
      case OrderStatus.completed:
        statusStr = 'completed';
        break;
      case OrderStatus.cancelled:
        statusStr = 'cancelled';
        break;
      case OrderStatus.rejected:
        statusStr = 'rejected';
        break;
    }

    return {
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      'phone_number': phoneNumber,
      'type': typeStr,
      'quantity': quantity,
      // Store gallon type as 'new' or 'old', omit if null
      if (gallonType != null)
        'gallon_type': gallonType == GallonType.newGallon ? 'new' : 'old',
      if (address != null) 'address': address,
      'status': statusStr,
      // Store DateTime as ISO 8601 string for consistent parsing
      'created_at': createdAt.toIso8601String(),
      if (deliveryDay != null) 'delivery_day': deliveryDay,
      // Store boolean as integer: 1 = true, 0 = false
      'is_pre_book': isPreBook ? 1 : 0,
      if (staffId != null) 'staff_id': staffId,
      if (cancelReason != null) 'cancel_reason': cancelReason,
    };
  }
}
