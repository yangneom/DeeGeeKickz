class AdminAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool isDisabled;
  final String lastLogin;
  final String registeredOn;

  const AdminAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isDisabled,
    this.lastLogin = '-',
    this.registeredOn = '-',
  });

  factory AdminAccount.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminAccount(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      isDisabled: json['is_disabled'] ?? false,
      lastLogin: json['last_login']?.toString() ?? '-',
      registeredOn: json['registered_date']?.toString() ?? '-',
    );
  }

  AdminAccount copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? role,
    bool? isDisabled,
    String? lastLogin,
    String? registeredOn,
  }) {
    return AdminAccount(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isDisabled: isDisabled ?? this.isDisabled,
      lastLogin: lastLogin ?? this.lastLogin,
      registeredOn: registeredOn ?? this.registeredOn,
    );
  }
}