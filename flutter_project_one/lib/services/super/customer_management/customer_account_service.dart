import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/customer_account.dart';
import '../activity_log/activity_log_service.dart';

class CustomerAccountService {
  CustomerAccountService() {
    print('CustomerAccountService CREATED');
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  // ================================================
  // GET ALL CUSTOMER ACCOUNTS
  // ================================================
  Future<List<CustomerAccount>> getCustomers() async {
    final response = await _supabase
        .from('users')
        .select('*, address(*)')
        .eq('role', 'Customer')
        .order('registered_date');

    return (response as List)
        .map((json) => CustomerAccount.fromJson(json))
        .toList();
  }

  // ================================================
  // GET ACTIVE CUSTOMERS ONLY
  // ================================================
  Future<List<CustomerAccount>> getActiveCustomers() async {
    final response = await _supabase
        .from('users')
        .select('*, address(*)')
        .eq('role', 'Customer')
        .eq('is_disabled', false)
        .order('registered_date');

    return (response as List)
        .map((json) => CustomerAccount.fromJson(json))
        .toList();
  }

  // ================================================
  // GET DISABLED CUSTOMERS ONLY
  // ================================================
  Future<List<CustomerAccount>> getDisabledCustomers() async {
    final response = await _supabase
        .from('users')
        .select('*, address(*)')
        .eq('role', 'Customer')
        .eq('is_disabled', true)
        .order('disabled_at');

    return (response as List)
        .map((json) => CustomerAccount.fromJson(json))
        .toList();
  }

  // ================================================
  // DISABLE ACCOUNT
  // ================================================
  Future<void> disableAccount(String userId, {required String reason}) async {
    final target = await _supabase
        .from('users')
        .select('first_name, last_name')
        .eq('id', userId)
        .single();

    final targetName =
        '${target['first_name'] ?? ''} ${target['last_name'] ?? ''}'.trim();

    await _supabase
        .from('users')
        .update({
          'is_disabled': true,
          'disabled_reason': reason,
          'disabled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select();

    await _activityLog.log(
      action: 'Disabled customer account of $targetName',
      affectedModule: AffectedModule.customerManagement,
      targetId: userId,
      metadata: {'reason': reason},
    );
  }

  // ================================================
  // ENABLE (ACTIVATE) ACCOUNT
  // ================================================
  Future<void> enableAccount(String userId) async {
    final target = await _supabase
        .from('users')
        .select('first_name, last_name')
        .eq('id', userId)
        .single();

    final targetName =
        '${target['first_name'] ?? ''} ${target['last_name'] ?? ''}'.trim();

    await _supabase
        .from('users')
        .update({
          'is_disabled': false,
          'disabled_reason': null,
          'disabled_at': null,
        })
        .eq('id', userId);

    await _activityLog.log(
      action: 'Enabled customer account of $targetName',
      affectedModule: AffectedModule.customerManagement,
      targetId: userId,
    );
  }
}