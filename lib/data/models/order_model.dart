enum OrderType { deliver, drop }

enum OrderStatus { pending, confirmed, completed, cancelled }

class Order {
  final int? id;
  final int? customerId;
  final String phoneNumber;
  final OrderType type;
  final int quantity;
  final String? address;
  final OrderStatus status;
  final DateTime createdAt;
  final String? deliveryDay;
  final bool isPreBook;

  Order({
    this.id,
    this.customerId,
    required this.phoneNumber,
    required this.type,
    required this.quantity,
    this.address,
    required this.status,
    required this.createdAt,
    this.deliveryDay,
    this.isPreBook = false,
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      phoneNumber: map['phone_number'] as String,
      type: map['type'] == 'deliver' ? OrderType.deliver : OrderType.drop,
      quantity: map['quantity'] as int,
      address: map['address'] as String?,
      status: _parseStatus(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      deliveryDay: map['delivery_day'] as String?,
      isPreBook: (map['is_pre_book'] as int?) == 1,
    );
  }

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
      default:
        return OrderStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      'phone_number': phoneNumber,
      'type': type == OrderType.deliver ? 'deliver' : 'drop',
      'quantity': quantity,
      if (address != null) 'address': address,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (deliveryDay != null) 'delivery_day': deliveryDay,
      'is_pre_book': isPreBook ? 1 : 0,
    };
  }
}
