// ================================================
// CUSTOMER ADDRESS MODEL
//
// Matches the real Supabase `address` table:
//   address_id, user_id, street, barangay, city,
//   province, region, zip_code, landmark,
//   is_default, created_at
//
// userName and userPhone are NOT stored here —
// they come from the users table and are passed
// in separately for display purposes only.
// ================================================
class CustomerAddress {
  final String id;
  final String street;
  final String barangay;
  final String city;
  final String province;
  final String region;
  final String zipCode;
  final String landmark;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.region,
    required this.zipCode,
    required this.landmark,
    this.isDefault = false,
  });

  // Display helper — full address as one line
  String get fullAddress {
    final List<String> parts = [street, barangay, city, province, zipCode]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  CustomerAddress copyWith({
    String? id,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? region,
    String? zipCode,
    String? landmark,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id:        id        ?? this.id,
      street:    street    ?? this.street,
      barangay:  barangay  ?? this.barangay,
      city:      city      ?? this.city,
      province:  province  ?? this.province,
      region:    region    ?? this.region,
      zipCode:   zipCode   ?? this.zipCode,
      landmark:  landmark  ?? this.landmark,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

// ================================================
// MOCK SAVED ADDRESSES
// Temporary — replace with real Supabase data later
// ================================================
final List<CustomerAddress> mockSavedAddresses = [
  const CustomerAddress(
    id:        'addr_001',
    street:    '123 Performance Way',
    barangay:  'Barangay Bel-Air',
    city:      'Makati',
    province:  'Metro Manila',
    region:    'NCR – National Capital Region',
    zipCode:   '1200',
    landmark:  'Near Ayala MRT',
    isDefault: true,
  ),
  const CustomerAddress(
    id:        'addr_002',
    street:    '456 Bonifacio Ave',
    barangay:  'Barangay Fort Bonifacio',
    city:      'Taguig',
    province:  'Metro Manila',
    region:    'NCR – National Capital Region',
    zipCode:   '1634',
    landmark:  'Near SM Aura',
    isDefault: false,
  ),
];