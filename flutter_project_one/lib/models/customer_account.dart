// ================================================
// CUSTOMER ACCOUNT MODEL
//
// Blueprint for a customer account
// Same pattern as admin_account.dart
// ================================================
class CustomerAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String landmark;
  final String status;
  final String lastLogin;
  final String registeredOn;
  final bool isArchived;
  final bool isDisabled;
  final String? archivedDate;
  final String? disabledDate;
  final String? disableReason;

  CustomerAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.landmark,
    required this.status,
    required this.lastLogin,
    required this.registeredOn,
    this.isArchived = false,
    this.isDisabled = false,
    this.archivedDate,
    this.disabledDate,
    this.disableReason,
  });

  // full name helper
  String get fullName => '$firstName $lastName'.trim();
}

// ================================================
// FAKE CUSTOMER ACCOUNTS DATA
// Replace with real Supabase data later
// ================================================
final List<CustomerAccount> fakeCustomerAccounts = [

  CustomerAccount(
    id: 'cust_001',
    firstName: 'Angel',
    lastName: 'Tuazon',
    email: 'TuazonAngel363@gmail.com',
    phone: '0991606274',
    address: 'Camarin Caloocan City',
    landmark: 'Alday Store',
    status: 'Active',
    lastLogin: '03-03-2026  09:30 am',
    registeredOn: '03-03-2026',
    isArchived: false,
    isDisabled: false,
  ),

  CustomerAccount(
    id: 'cust_002',
    firstName: 'Jay',
    lastName: 'Galang',
    email: 'jaygalang@gmail.com',
    phone: '09171234567',
    address: 'Quezon City',
    landmark: 'Near SM North',
    status: 'Suspended',
    lastLogin: '02-28-2026  02:15 pm',
    registeredOn: '01-15-2026',
    isArchived: false,
    isDisabled: false,
  ),

  CustomerAccount(
    id: 'cust_003',
    firstName: 'Maria',
    lastName: 'Santos',
    email: 'mariasantos@gmail.com',
    phone: '09281112222',
    address: 'Makati City',
    landmark: 'Ayala Mall',
    status: 'Inactive',
    lastLogin: '02-01-2026  10:00 am',
    registeredOn: '12-10-2025',
    isArchived: false,
    isDisabled: false,
  ),

];

// disabled accounts
final List<CustomerAccount> fakeDisabledCustomers = [

  CustomerAccount(
    id: 'cust_disabled_001',
    firstName: 'Angel',
    lastName: 'Tuazon',
    email: 'Angel363@gmail.com',
    phone: '0991606274',
    address: 'Camarin Caloocan City',
    landmark: 'Alday Store',
    status: 'Disabled',
    lastLogin: '03-03-2026  09:30 am',
    registeredOn: '03-03-2026',
    isArchived: false,
    isDisabled: true,
    disabledDate: '2005/03/11',
    disableReason: 'violence',
  ),

];

// archived accounts
final List<CustomerAccount> fakeArchivedCustomers = [

  CustomerAccount(
    id: 'cust_archived_001',
    firstName: 'Angel',
    lastName: 'Tuazon',
    email: 'Angel363@gmail.com',
    phone: '0991606274',
    address: 'Camarin Caloocan City',
    landmark: 'Alday Store',
    status: 'Archived',
    lastLogin: '03-03-2026  09:30 am',
    registeredOn: '03-03-2026',
    isArchived: true,
    isDisabled: false,
    archivedDate: '03-03-2026  09:30 am',
  ),

];