// ================================================
// CUSTOMER ACCOUNT MODEL
//
// Backed by Supabase `users` table (role = 'Customer'),
// joined with `address` for the default address.
// Same pattern as admin_account.dart — no archive,
// disable only.
// ================================================
class CustomerAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String landmark;
  final String lastLogin;
  final String registeredOn;
  final bool isDisabled;
  final String? disabledDate;
  final String? disableReason;

  const CustomerAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.landmark,
    required this.lastLogin,
    required this.registeredOn,
    this.isDisabled = false,
    this.disabledDate,
    this.disableReason,
  });

  // full name helper
  String get fullName => '$firstName $lastName'.trim();

  // derived status label for the badge
  String get status => isDisabled ? 'Disabled' : 'Active';

  // ================================================
  // FROM JSON
  // Expects a `users` row, optionally with a nested
  // `address` list (via `.select('*, address(*)')`).
  // Picks the default address if present, else the
  // first one, else falls back to blank.
  // ================================================
  factory CustomerAccount.fromJson(Map<String, dynamic> json) {
    String addressLine = '';
    String landmark = '';

    final addressList = json['address'];
    if (addressList is List && addressList.isNotEmpty) {
      Map<String, dynamic> chosen = addressList.first;
      for (final a in addressList) {
        if (a is Map<String, dynamic> && a['is_default'] == true) {
          chosen = a;
          break;
        }
      }

      final street = chosen['street'] ?? '';
      final barangay = chosen['barangay'] ?? '';
      final city = chosen['city'] ?? '';
      final province = chosen['province'] ?? '';

      addressLine = [street, barangay, city, province]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .join(', ');

      landmark = chosen['landmark']?.toString() ?? '';
    }

    return CustomerAccount(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: addressLine,
      landmark: landmark,
      lastLogin: json['last_login']?.toString() ?? '-',
      registeredOn: json['registered_date']?.toString() ?? '-',
      isDisabled: json['is_disabled'] ?? false,
      disabledDate: json['disabled_at']?.toString(),
      disableReason: json['disabled_reason']?.toString(),
    );
  }
}