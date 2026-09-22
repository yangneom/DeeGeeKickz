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
  final String? disabledAt;
  final String? disabledReason;

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
    this.disabledAt,
    this.disabledReason,
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
      disabledAt: json['disabled_at']?.toString(),
      disabledReason: json['disabled_reason']?.toString(),
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
    String? disabledAt,
    String? disabledReason,
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
      disabledAt: disabledAt ?? this.disabledAt,
      disabledReason: disabledReason ?? this.disabledReason,
    );
  }
}