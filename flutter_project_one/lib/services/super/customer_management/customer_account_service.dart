import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/customer_account.dart';
import '../activity_log/activity_log_service.dart';

class CustomerFlagSummary {
  final int cancelledOrdersCount;
  final int failedPaymentCount;
  final int flaggedFeedbackCount;

  const CustomerFlagSummary({
    required this.cancelledOrdersCount,
    required this.failedPaymentCount,
    required this.flaggedFeedbackCount,
  });

  bool get hasAnyFlags =>
      cancelledOrdersCount > 0 ||
      failedPaymentCount > 0 ||
      flaggedFeedbackCount > 0;
}

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
  // GET CUSTOMER FLAG SUMMARY
  // Read-only evidence pulled together for the disable dialog,
  // so admin isn't disabling an account on a blind dropdown guess.
  // Pulls: cancelled orders (30d), failed/refunded payments,
  // and feedback this customer left that's currently Flagged.
  // ================================================
  Future<CustomerFlagSummary> getCustomerFlagSummary(String userId) async {
    final DateTime thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30));

    // cancelled orders in the last 30 days
    final List<dynamic> cancelledOrders = await _supabase
        .from('orders')
        .select('order_id')
        .eq('user_id', userId)
        .eq('order_status', 'Cancelled')
        .gte('created_at', thirtyDaysAgo.toIso8601String());

    // this customer's order ids, to check payment failures against
    final List<dynamic> allOrderRows = await _supabase
        .from('orders')
        .select('order_id')
        .eq('user_id', userId);

    final List<int> orderIds = allOrderRows
        .map((row) => (row['order_id'] as num).toInt())
        .toList();

    int failedPaymentCount = 0;
    if (orderIds.isNotEmpty) {
      final List<dynamic> failedPayments = await _supabase
          .from('payment')
          .select('order_id, payment_status')
          .inFilter('order_id', orderIds)
          .inFilter('payment_status', ['Failed', 'Refunded', 'Refund Failed']);
      failedPaymentCount = failedPayments.length;
    }

    // flagged feedback left by this customer — confirmed via
    // feedback_service.dart: table is 'feedback', linked by user_id,
    // status column uses 'Flagged'
    final List<dynamic> flaggedFeedback = await _supabase
        .from('feedback')
        .select('feedback_id')
        .eq('user_id', userId)
        .eq('status', 'Flagged');

    return CustomerFlagSummary(
      cancelledOrdersCount: cancelledOrders.length,
      failedPaymentCount: failedPaymentCount,
      flaggedFeedbackCount: flaggedFeedback.length,
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