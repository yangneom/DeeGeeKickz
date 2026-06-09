import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/admin_account.dart';

class AdminAccountService {
  AdminAccountService() {
    print('AdminAccountService CREATED');
  }

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ================================================
  // GET ALL ACCOUNTS
  // ================================================
  Future<List<AdminAccount>> getAccounts() async {
  final response = await _supabase
      .from('users')
      .select()
      .order('created_at');

    print('========== USERS FETCHED ==========');
    print(response);
    print('===================================');

    final accounts = (response as List)
    .map(
      (json) => AdminAccount.fromJson(json),
    )
    .toList();

      print('========== ACCOUNTS PARSED ==========');

      for (final account in accounts) {
        print(
          '${account.email} | '
          '${account.role} | '
          'archived=${account.isArchived}',
        );
      }

      print('=====================================');

      return accounts;
  }
  // ================================================
  // CREATE ACCOUNT
  // ================================================
  Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) async {
    print('SERVICE createAccount()');

    try {
      final response =
          await _supabase.functions.invoke(
        'create-admin-user',
        body: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'role': role,
        },
      );

      print(
        '========== EDGE FUNCTION RESPONSE =========='
      );
      print('Status: ${response.status}');
      print('Data: ${response.data}');
      print(
        '============================================'
      );

      if (response.data == null) {
        throw Exception(
          'Function returned null',
        );
      }

      final data =
          response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(
          data['error'] ??
              'Failed to create account',
        );
      }
    } catch (e, stackTrace) {
      print(
        '========== CREATE ACCOUNT ERROR =========='
      );
      print(e);
      print(stackTrace);
      print(
        '=========================================='
      );
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
  }

  // ================================================
  // ARCHIVE ACCOUNT
  // ================================================
  Future<void> archiveAccount(
      String userId,
    ) async {

      print('SERVICE ARCHIVE = $userId');

      final response = await _supabase
          .from('users')
          .update({
            'is_archived': true,
          })
          .eq('id', userId)
          .select();

      print('ARCHIVE RESPONSE = $response');
    }

  // ================================================
  // RESTORE ACCOUNT
  // ================================================
  Future<void> restoreAccount(
    String userId,
  ) async {
    await _supabase
        .from('users')
        .update({
          'is_archived': false,
        })
        .eq('id', userId);
  }
}