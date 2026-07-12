import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer_account.dart';
import '../../services/super/customer_management/customer_account_service.dart';

final customerAccountServiceProvider =
    Provider<CustomerAccountService>((ref) {
  return CustomerAccountService();
});

final customerAccountsProvider =
    NotifierProvider<CustomerAccountNotifier, List<CustomerAccount>>(
  CustomerAccountNotifier.new,
);

class CustomerAccountNotifier extends Notifier<List<CustomerAccount>> {
  late final CustomerAccountService _service;

  @override
  List<CustomerAccount> build() {
    _service = ref.read(customerAccountServiceProvider);
    return [];
  }

  // loads ALL customers (active + disabled) — screen filters client-side
  Future<void> loadAccounts() async {
    state = await _service.getCustomers();
  }

  Future<void> disableAccount(String userId, {required String reason}) async {
    print('NOTIFIER DISABLE CUSTOMER = $userId');

    await _service.disableAccount(userId, reason: reason);

    print('NOTIFIER DISABLE CUSTOMER DONE');

    await loadAccounts();
  }

  Future<void> enableAccount(String userId) async {
    print('NOTIFIER ENABLE CUSTOMER = $userId');

    await _service.enableAccount(userId);

    await loadAccounts();
  }
}