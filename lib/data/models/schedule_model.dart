class Schedule {
  final int? id;
  final int customerId;
  final String deliveryDay;
  final String status;

  Schedule({
    this.id,
    required this.customerId,
    required this.deliveryDay,
    required this.status,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      deliveryDay: map['delivery_day'] as String,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'delivery_day': deliveryDay,
      'status': status,
    };
  }
}
