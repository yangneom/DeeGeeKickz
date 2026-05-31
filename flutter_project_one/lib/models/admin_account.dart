// ================================================
// ADMIN ACCOUNT MODEL
//
// Blueprint for an admin account
// Same pattern as product.dart and order.dart
// ================================================
class AdminAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String status;
  final String lastLogin;
  final String? phone;
  final bool isArchived;
  final String? archivedDate;

  AdminAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    required this.lastLogin,
    this.phone,
    this.isArchived = false,
    this.archivedDate,
  });

  // full name helper
  String get fullName => '$firstName $lastName'.trim();
}

// ================================================
// FAKE ADMIN ACCOUNTS DATA
// Replace with real Supabase data later
// ================================================
final List<AdminAccount> fakeAdminAccounts = [

  AdminAccount(
    id: 'admin_001',
    firstName: 'Angel',
    lastName: 'Tuazon',
    email: 'TuazonAngel363@gmail.com',
    role: 'Cashier',
    status: 'Active',
    lastLogin: '03-03-2026  09:30 am',
    phone: '0991606274',
    isArchived: false,
  ),

  AdminAccount(
    id: 'admin_002',
    firstName: 'Jay',
    lastName: 'Galang',
    email: 'jaygalang@gmail.com',
    role: 'Admin',
    status: 'Active',
    lastLogin: '03-02-2026  02:15 pm',
    phone: '09171234567',
    isArchived: false,
  ),

  AdminAccount(
    id: 'admin_003',
    firstName: 'Maria',
    lastName: 'Santos',
    email: 'mariasantos@gmail.com',
    role: 'Cashier',
    status: 'Inactive',
    lastLogin: '02-28-2026  10:00 am',
    phone: '09281112222',
    isArchived: false,
  ),

];

// archived accounts
final List<AdminAccount> fakeArchivedAccounts = [

  AdminAccount(
    id: 'admin_archived_001',
    firstName: 'Angel',
    lastName: 'Tuazon',
    email: 'Angel363@gmail.com',
    role: 'Cashier',
    status: 'Archived',
    lastLogin: '03-03-2026  09:30 am',
    phone: '09991506274',
    isArchived: true,
    archivedDate: '03-03-2026  09:30 am',
  ),

];