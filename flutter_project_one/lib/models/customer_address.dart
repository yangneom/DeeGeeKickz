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
// FIX #22: sentinel used by copyWith below so it can distinguish
// "this parameter wasn't passed, leave the field unchanged" from
// "this parameter was explicitly passed as null, clear the field" —
// the plain `lat ?? this.lat` pattern couldn't tell those apart.
class _Unset {
  const _Unset();
}

const Object _unset = _Unset();

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

  // NEW — official PSGC codes, captured once the Region/Province/
  // City/Barangay fields become dropdowns instead of free text.
  // Nullable: older addresses saved before this feature won't have
  // them, and that must not break reading/displaying those rows.
  final String? cityPsgcCode;
  final String? barangayPsgcCode;

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
    this.cityPsgcCode,
    this.barangayPsgcCode,
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
    // FIX #22: lat/lng default to the _unset sentinel instead of
    // null, so copyWith(lat: null) actually clears the field instead
    // of silently keeping the old value. Same sentinel pattern
    // applied to the two new PSGC code fields for the same reason.
    Object? lat = _unset,
    Object? lng = _unset,
    Object? cityPsgcCode = _unset,
    Object? barangayPsgcCode = _unset,
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
      lat:       identical(lat, _unset) ? this.lat : lat as double?,
      lng:       identical(lng, _unset) ? this.lng : lng as double?,
      cityPsgcCode: identical(cityPsgcCode, _unset)
          ? this.cityPsgcCode
          : cityPsgcCode as String?,
      barangayPsgcCode: identical(barangayPsgcCode, _unset)
          ? this.barangayPsgcCode
          : barangayPsgcCode as String?,
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
      cityPsgcCode: json['city_psgc_code'] as String?,
      barangayPsgcCode: json['barangay_psgc_code'] as String?,
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
      'city_psgc_code': cityPsgcCode,
      'barangay_psgc_code': barangayPsgcCode,
    };
  }
}