import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
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


      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();


      final role = response['role'] as String?;
      return role;

    } catch (error) {
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
      // Checked via a SECURITY DEFINER RPC, not a direct table query —
      // RLS only allows reading your OWN row, and no session exists
      // yet at this point in registration, so a plain .select() here
      // would silently return nothing every time instead of catching
      // real duplicates.
            final bool phoneTaken = await _supabase.rpc(
        'is_phone_taken',
        params: {'p_phone': phone.trim()},
      );
      if (phoneTaken) {
        return 'An account already exists with this phone number.';
      }

      final bool emailTaken = await _supabase.rpc(
        'is_email_taken',
        params: {'p_email': email.trim()},
      );
      if (emailTaken) {
        return 'An account already exists with this email.';
      }

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        },
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

        if (error.statusCode == '429') {
          return 'Too many account creation attempts. Please wait a few minutes and try again.';
        } else if (error.message.contains('already registered')) {
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
      return null;
    } on AuthException catch (error) {
      if (error.statusCode == '429') {
        return 'Too many attempts. Please wait a few minutes and try again.';
      }
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
      return null;
   } on AuthException catch (error) {
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
// ── LOGIN ──
  // Special case: if this account exists but never finished email/phone
  // verification (customer closed the app mid-signup), Supabase blocks
  // login with an "Email not confirmed" error. Rather than showing that
  // raw message, we return a distinct marker string so the UI can point
  // the customer back to Sign Up — re-submitting the same email there
  // resends the confirmation code instead of erroring, so it acts as a
  // resume path.
  static const String unconfirmedEmailMarker = 'UNCONFIRMED_EMAIL';
  static const String incompleteRegistrationMarker = 'INCOMPLETE_REGISTRATION';


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


    if (currentUser != null) {
      // Auto-clear a temporary suspension if its time has passed —
      // makes tier-2/3 suspensions self-healing, no cron job needed.
      try {
        await _supabase.rpc('check_and_clear_expired_suspension', params: {
          'p_user_id': currentUser.id,
        });
      } catch (e) {
        print('check_and_clear_expired_suspension error: $e');
      }

      // Re-check AFTER the auto-clear above — this is what actually
      // blocks a still-suspended/banned account from logging back in
      // with a correct password.
      final profile = await _supabase
          .from('users')
          .select('is_disabled, disabled_reason')
          .eq('id', currentUser.id)
          .maybeSingle();

      final bool isDisabled = profile?['is_disabled'] as bool? ?? false;
      if (isDisabled) {
        final String reason = profile?['disabled_reason'] as String? ??
            'Your account has been suspended.';
        await _supabase.auth.signOut();
        return reason;
      }

      // Record this login — nothing previously wrote to last_login,
      // which is why every account table showed "-" for every row.
      await _supabase
          .from('users')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('id', currentUser.id);
    }


    return null;

    } on AuthException catch (error) {
    print('LOGIN ERROR = ${error.message}');
    if (error.statusCode == '429') {
      return 'Too many login attempts. Please wait a few minutes and try again.';
    }
    return error.message;
  } on SocketException catch (_) {
    // Device has no route to the internet at all (DNS failure,
    // airplane mode, no signal) — distinct from a wrong password,
    // which throws AuthException instead and is handled above.
    return 'Unable to connect to the server. Please check your internet connection and try again.';
  } on http.ClientException catch (_) {
    return 'Unable to connect to the server. Please check your internet connection and try again.';
  }
}

  // ── LOGOUT ──

  // ── LOGOUT ──
  // ── SEND PASSWORD RESET EMAIL ──
  // ── SEND PASSWORD RESET EMAIL ──
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      rethrow;
    }
  }

  // ── VERIFY PASSWORD RESET OTP ──
  // Verifying this code establishes a temporary authenticated session,
  // which ResetPasswordForm then uses to call updateUser(password: ...).
    Future<String?> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: token.trim(),
      );
      return null;
    } on AuthException catch (error) {
      if (error.statusCode == '429') {
        return 'Too many attempts. Please wait a few minutes and try again.';
      }
      return error.message;
    } catch (error) {
      return 'Something went wrong. Please try again.';
    }
  }

// ── CHANGE OWN PASSWORD (self-service, requires current password) ──
  // Re-authenticates first — updateUser() alone doesn't verify the caller
  // actually knows the current password, so without this step anyone
  // with an already-open session could silently change it.
  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        return 'Session expired. Please log in again.';
      }

      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      await _supabase.from('users').update({
        'password_changed_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      return null;
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('invalid login credentials')) {
        return 'Current password is incorrect.';
      }
      if (error.message.toLowerCase().contains('weak password') ||
          error.message.toLowerCase().contains('password should be')) {
        return 'New password is too weak. Use at least 8 characters.';
      }
      return error.message;
    } catch (error) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── CHECK IF PASSWORD CHANGE IS DUE (30-day policy) ──
  Future<bool> isPasswordChangeDue() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('users')
          .select('password_changed_at')
          .eq('id', user.id)
          .single();

      final changedAtRaw = response['password_changed_at'] as String?;
      if (changedAtRaw == null) return true; // never recorded — treat as due

      final changedAt = DateTime.parse(changedAtRaw);
      final daysSince = DateTime.now().difference(changedAt).inDays;
      return daysSince >= 30;
    } catch (error) {
      return false; // fail safe — don't nag if the check itself breaks
    }
  }
  // ── LOGOUT ──
  Future<void> logout() async {
    await _supabase.auth.signOut();
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
      return null;
    }
  }
}