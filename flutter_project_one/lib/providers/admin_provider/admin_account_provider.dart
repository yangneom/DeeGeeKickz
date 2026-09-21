import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin_account.dart';
import '../../services/super/admin_management/admin_account_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    required String role,
  }) async {

    await _service.createAccount(
      firstName: firstName,
      lastName: lastName,
      email: email,
      role: role,
    );

    await loadAccounts();
  }

Future<void> disableAccount(String userId) async {

  await _service.disableAccount(userId);


  await loadAccounts();
}

Future<void> enableAccount(String userId) async {

  await _service.enableAccount(userId);

  await loadAccounts();
}

Future<void> updateAccount(
  AdminAccount account,
) async {
  await _service.updateAccount(account);

  await loadAccounts();
}

Future<void> resetMfa(String userId) async {
  final response = await Supabase.instance.client.functions.invoke(
    'reset-mfa',
    body: {'target_user_id': userId},
  );

  final data = response.data;
  if (data == null || data['success'] != true) {
    throw Exception(data?['error'] ?? 'Failed to reset 2FA.');
  }
}

}