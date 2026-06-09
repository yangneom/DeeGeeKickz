import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_account.dart';
import '../../services/super/admin_management/admin_account_service.dart';

final adminAccountServiceProvider =
    Provider<AdminAccountService>((ref) {
  return AdminAccountService();
});

final adminAccountsProvider =
    NotifierProvider<AdminAccountNotifier, List<AdminAccount>>(
  AdminAccountNotifier.new,
);

class AdminAccountNotifier
    extends Notifier<List<AdminAccount>> {
  late final AdminAccountService _service;

  @override
  List<AdminAccount> build() {
    _service = ref.read(
      adminAccountServiceProvider,
    );
    return [];
  }

  Future<void> loadAccounts() async {
    state = await _service.getAccounts();
  }

  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) async {
    print('NOTIFIER createAccount()');

    await _service.createAccount(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      role: role,
    );

    await loadAccounts();
  }

Future<void> archiveAccount(String userId) async {
  print('NOTIFIER ARCHIVE = $userId');

  await _service.archiveAccount(userId);

  print('NOTIFIER ARCHIVE DONE');

  await loadAccounts();
}

Future<void> restoreAccount(String userId) async {
  print('RESTORING: $userId');

  await _service.restoreAccount(userId);

  await loadAccounts();
}

Future<void> updateAccount(
  AdminAccount account,
) async {
  await _service.updateAccount(account);

  await loadAccounts();
}

}