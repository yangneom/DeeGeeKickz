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

  // ── REGISTER (step 1: create auth user only, no profile insert yet) ──
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
      // NOTE: we no longer upsert into 'users' here.
      // RLS requires an active session (auth.uid()), which doesn't exist
      // until the email OTP is verified. Profile insert happens in
      // completeRegistration() after both OTPs pass.
      return null;

    } on AuthException catch (error) {
        print('Register AuthException: ${error.message}');

        if (error.message.contains('already registered')) {
          return 'An account already exists with this email.';
        } else if (error.message.contains('weak password') ||
            error.message.contains('Password should be')) {
          return 'Password is too weak. Use at least 6 characters.';
        } else if (error.message.contains('security purposes') ||
            error.message.contains('after') && error.message.contains('seconds')) {
          return 'A code was already sent recently. Please check your inbox, or wait a moment before trying again.';
        } else {
          return 'Registration failed: ${error.message}';
        }

    } catch (error) {
      print('Register unknown error: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  // ── VERIFY EMAIL OTP (step 2: this establishes the session) ──
  Future<String?> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: token.trim(),
      );
      print('Email OTP verified. Session UID = ${_supabase.auth.currentUser?.id}');
      return null;
    } on AuthException catch (error) {
      print('verifyEmailOtp error: ${error.message}');
      return error.message;
    }
  }


  // ── RESEND EMAIL OTP (used by the "Resend code" button on the email step) ──
  Future<String?> resendEmailOtp({
    required String email,
  }) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      print('Resent email OTP to $email');
      return null;
   } on AuthException catch (error) {
      print('resendEmailOtp error: ${error.message}');
      if (error.message.contains('security purposes') ||
          (error.message.contains('after') && error.message.contains('seconds'))) {
        return 'Please wait a bit before requesting another code.';
      }
      return error.message;
    }
  }



  // ── COMPLETE REGISTRATION (step 3: insert profile row, now RLS-safe) ──
  Future<String?> completeRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return 'Session expired. Please try verifying your email again.';
      }

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
    } catch (error) {
      print('completeRegistration error: $error');
      return 'Something went wrong saving your profile.';
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

      // ── Check if account is disabled ──
      // (Archive was removed — disable is now the single lockout mechanism
      // for both staff and customer accounts.)
      final profile = await _supabase
          .from('users')
          .select('is_disabled, disabled_reason, role')
          .eq('id', currentUser!.id)
          .single();

      final isDisabled = profile['is_disabled'] as bool? ?? false;

      if (isDisabled) {
        await _supabase.auth.signOut(); // force sign out immediately
        return 'Your account has been disabled. Please contact support.';
      }

      print('Login successful for ${email.trim()}');
      return null;

    } on AuthException catch (error) {
      print('LOGIN ERROR = ${error.message}');
      return error.message;
    } catch (error) {
      print('Login unknown error: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  // ── LOGOUT ──
  // ── SEND PASSWORD RESET EMAIL ──
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      print('Password reset email sent to $email');
    } catch (error) {
      print('sendPasswordResetEmail error: $error');
      rethrow;
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