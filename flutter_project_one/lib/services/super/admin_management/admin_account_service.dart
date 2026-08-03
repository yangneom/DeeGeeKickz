import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/admin_account.dart';
import '../activity_log/activity_log_service.dart';

class AdminAccountService {
  AdminAccountService() {
    print('AdminAccountService CREATED');
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  final ActivityLogService _activityLog = ActivityLogService();

  // ================================================
  // GET ALL ACCOUNTS
  // ================================================
  Future<List<AdminAccount>> getAccounts() async {
    final response = await _supabase
        .from('users')
        .select()
        .order('created_at');

    final accounts = (response as List)
        .map((json) => AdminAccount.fromJson(json))
        .toList();

    return accounts;
  }

  // ================================================
  // CREATE ACCOUNT
  // ================================================
  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-admin-user',
        body: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'role': role,
        },
      );

      if (response.data == null) {
        throw Exception('Function returned null');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to create account');
      }

      await _activityLog.log(
        action: 'Added new $role account for $firstName $lastName',
        affectedModule: AffectedModule.adminManagement,
        metadata: {'email': email, 'role': role},
      );
    } catch (e, stackTrace) {
      print('CREATE ACCOUNT ERROR: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // ================================================
  // UPDATE ACCOUNT
  // ================================================
  Future<void> updateAccount(
    AdminAccount account,
  ) async {
    await _supabase
        .from('users')
        .update({
          'first_name': account.firstName,
          'last_name': account.lastName,
          'email': account.email,
          'phone': account.phone,
          'role': account.role,
        })
        .eq('id', account.id);

    await _activityLog.log(
      action:
          'Updated account details for ${account.firstName} ${account.lastName}',
      affectedModule: AffectedModule.adminManagement,
      targetId: account.id,
    );
  }

  // ================================================
  // DISABLE ACCOUNT
  // ================================================
 // ================================================
  // DISABLE ACCOUNT
  // ================================================
  Future<void> disableAccount(
    String userId, {
    String? reason,
  }) async {
    // Guard: can't disable yourself
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == userId) {
      throw Exception('You cannot disable your own account.');
    }

    final target = await _supabase
        .from('users')
        .select('first_name, last_name, role')
        .eq('id', userId)
        .single();

    final targetName =
        '${target['first_name'] ?? ''} ${target['last_name'] ?? ''}'.trim();
    final targetRole = target['role'] as String?;

    // Guard: can't disable the last remaining Super Admin
    if (targetRole == 'Super Admin') {
      final activeSuperAdmins = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'Super Admin')
          .eq('is_disabled', false);

      if ((activeSuperAdmins as List).length <= 1) {
        throw Exception('Cannot disable the last remaining Super Admin.');
      }
    }

    // Call the edge function instead of updating the table directly —
    // this also force-kills their active session, not just flips a flag.
    final response = await _supabase.functions.invoke(
      'disable-account',
      body: {'user_id': userId, 'reason': reason},
    );

    final data = response.data;
    final success = data is Map && data['success'] == true;

    if (!success) {
      final errorMsg = (data is Map ? data['error'] : null) ??
          'Failed to disable account (status ${response.status}).';
      throw Exception(errorMsg);
    }

    await _activityLog.log(
      action: 'Disabled admin account of $targetName',
      affectedModule: AffectedModule.adminManagement,
      targetId: userId,
      metadata: reason != null ? {'reason': reason} : null,
    );
  }

  // ================================================
  // ENABLE ACCOUNT
  // ================================================
  Future<void> enableAccount(
    String userId,
  ) async {
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
      action: 'Enabled admin account of $targetName',
      affectedModule: AffectedModule.adminManagement,
      targetId: userId,
    );
  }
}