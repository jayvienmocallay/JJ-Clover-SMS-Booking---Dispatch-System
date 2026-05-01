// Task 003 — Customer data model (core entity)
// Task 005 — Added address field per FR-1.2 in SRS
// Task 020 — Added RA 10173 consent metadata for audit trail
/// Represents a registered customer of the water refilling station.
///
/// Each customer belongs to a barangay (which determines their delivery zone)
/// and has a contact number used for SMS-based ordering.
/// The [address] field stores their full delivery address (FR-1.2 in SRS).
class Customer {
  /// Unique database identifier (null for unsaved records)
  final int? id;

  /// Customer's full name
  final String name;

  /// Customer's phone number used for SMS identification
  final String contactNumber;

  /// Full delivery address within the barangay (e.g., 'Purok 4, near chapel')
  final String? address;

  /// Foreign key to barangays table
  final int? barangayId;

  /// Name of the customer's barangay (joined from barangays table)
  final String barangay;

  /// Delivery zone derived from the barangay (e.g., 'Zone A', 'Zone B', 'Zone C')
  final String deliveryZone;

  /// Whether the customer has consented to data collection per RA 10173.
  final bool consentGiven;

  /// ISO8601 timestamp at the moment the customer gave consent.
  final String? consentTimestamp;

  /// How consent was captured: 'app_ui' (staff form) or 'sms' (SMS flow).
  final String? consentChannel;

  /// Version string of the privacy notice the customer agreed to.
  final String? consentVersion;

  Customer({
    this.id,
    required this.name,
    required this.contactNumber,
    this.address,
    this.barangayId,
    required this.barangay,
    required this.deliveryZone,
    this.consentGiven = false,
    this.consentTimestamp,
    this.consentChannel,
    this.consentVersion,
  });

  /// Creates a [Customer] instance from a database row map.
  /// Expects keys from a JOIN query between customers and barangays tables.
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactNumber: map['contact_number'] as String,
      address: map['address'] as String?,
      barangayId: map['barangay_id'] as int?,
      barangay: map['barangay'] as String? ?? '',
      deliveryZone: map['delivery_zone'] as String? ?? '',
      consentGiven: (map['consent_given'] as int? ?? 0) == 1,
      consentTimestamp: map['consent_timestamp'] as String?,
      consentChannel: map['consent_channel'] as String?,
      consentVersion: map['consent_version'] as String?,
    );
  }

  /// Creates a [Customer] instance from a simple row (no JOIN).
  factory Customer.fromSimple(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactNumber: map['contact_number'] as String,
      address: map['address'] as String?,
      barangayId: map['barangay_id'] as int?,
      barangay: '',
      deliveryZone: '',
      consentGiven: (map['consent_given'] as int? ?? 0) == 1,
      consentTimestamp: map['consent_timestamp'] as String?,
      consentChannel: map['consent_channel'] as String?,
      consentVersion: map['consent_version'] as String?,
    );
  }

  /// Converts this customer to a map for database insertion.
  /// Uses barangay_id (FK), not the name strings.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'contact_number': contactNumber,
      if (address != null) 'address': address,
      'barangay_id': barangayId,
      'consent_given': consentGiven ? 1 : 0,
      if (consentTimestamp != null) 'consent_timestamp': consentTimestamp,
      if (consentChannel != null) 'consent_channel': consentChannel,
      if (consentVersion != null) 'consent_version': consentVersion,
    };
  }
}
