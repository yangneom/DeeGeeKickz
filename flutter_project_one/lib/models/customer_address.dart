// ================================================
// CUSTOMER ADDRESS MODEL
//
// Matches the real Supabase `address` table:
//   address_id, user_id, street, barangay, city,
//   province, region, zip_code, landmark,
//   is_default, lat, lng, created_at
//
// UPDATE: added nullable lat/lng — populated by
// geocoding when the address is saved (see
// AddressBottomSheet._save()). Nullable because:
//   - Older addresses saved before this feature
//     existed won't have coordinates yet.
//   - Geocoding can fail (bad/incomplete address),
//     and we don't want that to block saving the
//     address entirely — just means Lalamove
//     delivery can't be quoted for it until fixed.
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
  final double? lat;
  final double? lng;

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
    this.lat,
    this.lng,
  });

  /// True once this address has coordinates and can be used
  /// for a Lalamove quotation. Check this before calling
  /// get-delivery-quote at checkout.
  bool get hasCoordinates => lat != null && lng != null;

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
    double? lat,
    double? lng,
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
      lat:       lat       ?? this.lat,
      lng:       lng       ?? this.lng,
    );
  }

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: (json['address_id'] as num).toString(),
      street: json['street'] as String? ?? '',
      barangay: json['barangay'] as String? ?? '',
      city: json['city'] as String? ?? '',
      province: json['province'] as String? ?? '',
      region: json['region'] as String? ?? '',
      zipCode: json['zip_code'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson({required String userId}) {
    return {
      'user_id': userId,
      'street': street,
      'barangay': barangay,
      'city': city,
      'province': province,
      'region': region,
      'zip_code': zipCode,
      'landmark': landmark,
      'is_default': isDefault,
      'lat': lat,
      'lng': lng,
    };
  }
}