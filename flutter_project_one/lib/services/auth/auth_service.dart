import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  final SupabaseClient _supabase = Supabase.instance.client;

  // ── GET CURRENT USER ──
  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // ── AUTH STATE CHANGES ──
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }

  // ── GET USER ROLE ──
  Future<String?> getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        print('getUserRole: No current user found');
        return null;
      }

      print('getUserRole: Looking up UID ${user.id}');

      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      print('getUserRole: response = $response');

      final role = response['role'] as String?;
      print('getUserRole: Found role = $role');
      return role;

    } catch (error) {
      print('getUserRole error: $error');
      return null;
    }
  }

  // ── LOGIN ──
  Future<String?> login({
  required String email,
  required String password,
}) async {
  try {

    await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final currentUser = _supabase.auth.currentUser;

    print('===================================');
    print('LOGGED IN USER UID = ${currentUser?.id}');
    print('LOGGED IN USER EMAIL = ${currentUser?.email}');
    print('===================================');

    print('Login successful for ${email.trim()}');
    return null;

  } on AuthException catch (error) {
    print('LOGIN ERROR = ${error.message}');
    return error.message;
  }
}

  // ── REGISTER ──
  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      final user = response.user;
      if (user == null) {
        return 'Registration failed. Please try again.';
      }

      print('Register: Created auth user with UID ${user.id}');

      // Save user profile to users table
      await _supabase.from('users').upsert({
        'id': user.id,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': 'Customer',
      });

      print('Register: Saved user profile to Supabase');
      return null;

    } on AuthException catch (error) {
      print('Register AuthException: ${error.message}');

      if (error.message.contains('already registered')) {
        return 'An account already exists with this email.';
      } else if (error.message.contains('weak password') ||
          error.message.contains('Password should be')) {
        return 'Password is too weak. Use at least 6 characters.';
      } else {
        return 'Registration failed: ${error.message}';
      }

    } catch (error) {
      print('Register unknown error: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  // ── LOGOUT ──
  Future<void> logout() async {
    await _supabase.auth.signOut();
    print('User logged out');
  }

  // ── GET USER PROFILE ──
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return response;

    } catch (error) {
      print('getUserProfile error: $error');
      return null;
    }
  }
}