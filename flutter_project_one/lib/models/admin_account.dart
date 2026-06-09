class AdminAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool isArchived;

  const AdminAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isArchived,
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
      isArchived: json['is_archived'] ?? false,
    );
  }

  AdminAccount copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? role,
    bool? isArchived,
  }) {
    return AdminAccount(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}