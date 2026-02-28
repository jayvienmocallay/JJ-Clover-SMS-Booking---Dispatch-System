class Customer {
  final int? id;
  final String name;
  final String contactNumber;
  final String barangay;
  final String deliveryZone;

  Customer({
    this.id,
    required this.name,
    required this.contactNumber,
    required this.barangay,
    required this.deliveryZone,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactNumber: map['contact_number'] as String,
      barangay: map['barangay'] as String,
      deliveryZone: map['delivery_zone'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'contact_number': contactNumber,
      'barangay': barangay,
      'delivery_zone': deliveryZone,
    };
  }
}
