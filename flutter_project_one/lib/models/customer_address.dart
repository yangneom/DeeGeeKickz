/// Represents a saved shipping address for a customer.
/// Mock/fake data only — no Supabase integration yet.
/// Supabase-ready: wire to a customer_addresses table when ready.
class CustomerAddress {
  final String id;
  final String firstName;
  final String lastName;
  final String street;
  final String city;
  final String postal;
  final String country;
  final String phone;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.street,
    required this.city,
    required this.postal,
    required this.country,
    required this.phone,
    this.isDefault = false,
  });

  String get fullName => '$firstName $lastName';
  String get fullAddress => '$street, $city, $postal, $country';

  CustomerAddress copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? street,
    String? city,
    String? postal,
    String? country,
    String? phone,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      street: street ?? this.street,
      city: city ?? this.city,
      postal: postal ?? this.postal,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

// ─────────────────────────────────────────────
// MOCK SAVED ADDRESSES
// ─────────────────────────────────────────────

final List<CustomerAddress> mockSavedAddresses = [
  const CustomerAddress(
    id: 'addr_001',
    firstName: 'John',
    lastName: 'Doe',
    street: '123 Performance Way',
    city: 'Makati',
    postal: '1200',
    country: 'Philippines',
    phone: '+63 917 123 4567',
    isDefault: true,
  ),
  const CustomerAddress(
    id: 'addr_002',
    firstName: 'Jane',
    lastName: 'Doe',
    street: '456 Bonifacio Ave',
    city: 'BGC',
    postal: '1634',
    country: 'Philippines',
    phone: '+63 918 765 4321',
    isDefault: false,
  ),
];