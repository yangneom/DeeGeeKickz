import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/form_validators.dart';
import 'login_attempt_guard.dart';
import 'password_change_mapping.dart';
import '../../core/utils/password_reminder_snooze.dart';

// The profile dialog reads PasswordChangeResult / PasswordChangeStatus.
export 'password_change_mapping.dart';

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

        final String lower = error.message.toLowerCase();

        // Supabase answers "429" for three DIFFERENT situations, and only one
        // of them is about this customer's own repeated requests. Telling them
        // apart means the message is accurate, not an accusation.
        if (lower.contains('email rate limit') ||
            lower.contains('over_email_send_rate_limit')) {
          // The whole project's hourly cap on emails is used up. Not the
          // customer's doing.
          return 'We couldn\'t send your verification email right now because our email service is busy. Please try again in a few minutes.';
        } else if (lower.contains('security purposes') ||
            (lower.contains('after') && lower.contains('seconds'))) {
          // The same address was asked for a code a moment ago.
          return 'A verification code was already sent to this address recently. Please check your inbox and spam folder, or wait about a minute and try again.';
        } else if (error.statusCode == '429' || lower.contains('rate limit')) {
          // Too many requests from this connection (it may be shared).
          return 'Our servers are receiving a lot of requests from your connection. Please wait a few minutes and try again.';
        } else if (lower.contains('already registered')) {
          return 'An account already exists with this email.';
        } else if (lower.contains('weak password') ||
            lower.contains('password should be')) {
          return 'Password is too weak. Use at least 6 characters.';
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
      final String lower = error.message.toLowerCase();
      if (lower.contains('email rate limit') ||
          lower.contains('over_email_send_rate_limit')) {
        return 'We couldn\'t send a new code right now because our email service is busy. Please try again in a few minutes.';
      }
      if (lower.contains('security purposes') ||
          (lower.contains('after') && lower.contains('seconds'))) {
        return 'Please wait a bit before requesting another code.';
      }
      if (error.statusCode == '429') {
        return 'Our servers are receiving a lot of requests from your connection. Please wait a few minutes and try again.';
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
  // CLIENT-SIDE convenience (see LoginAttemptGuard): after 5 consecutive wrong
  // passwords for this email, no request is sent for 15 minutes. This is NOT
  // what protects the account; Supabase's own rate limits and MFA do. It only
  // stops an honest user from hammering the box, and tells them why.
  final Duration? lockedFor = await LoginAttemptGuard.remainingLock(email);
  if (lockedFor != null) {
    return LoginAttemptGuard.lockedMessage(lockedFor);
  }

  try {

    await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // The password was right: the failed-attempt count starts over.
    await LoginAttemptGuard.recordSuccess(email);

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

      // Signed in, but there is NO profile: sign-up was never finished (the
      // profile is only written after both codes pass). Before this, login
      // simply carried on and the app was left signed in with no role.
      if (profile == null) {
        // The Gmail-only rule would refuse this account's profile anyway, so
        // say so now instead of sending them through the phone step.
        if (FormValidators.gmailEmail(currentUser.email) != null) {
          await _supabase.auth.signOut();
          return 'This account can\'t finish registering because only Gmail addresses (@gmail.com) are accepted. Please sign up again with a Gmail address.';
        }
        // The session is KEPT on purpose: the phone step needs it to send the
        // SMS code and to save the profile. The login form routes them there.
        return incompleteRegistrationMarker;
      }

      final bool isDisabled = profile['is_disabled'] as bool? ?? false;
      if (isDisabled) {
        final String reason = profile['disabled_reason'] as String? ??
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
    final String lower = error.message.toLowerCase();

    // The password was right, but the email was never confirmed (sign-up
    // abandoned at the first code). The form explains how to resume.
    if (lower.contains('email not confirmed')) {
      return unconfirmedEmailMarker;
    }

    // Too many sign-in requests from this connection, which may be shared by
    // many people. Not necessarily this customer's doing.
    if (error.statusCode == '429') {
      return 'Too many login requests are coming from your connection right now. Please wait a few minutes and try again.';
    }

    // A wrong password (Supabase answers the same way for an unknown email, so
    // this reveals nothing about who is registered). Only THIS counts.
    if (lower.contains('invalid login credentials')) {
      final Duration? nowLocked = await LoginAttemptGuard.recordFailure(email);
      if (nowLocked != null) {
        return LoginAttemptGuard.lockedMessage(nowLocked);
      }
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
  // Changes the password of the signed-in person.
  //
  // Order of events (nothing later runs unless the earlier step passed):
  //   1. the CURRENT password is checked, without touching the real session;
  //   2. the real session must be at the two-factor level (aal2); if it is not,
  //      the form asks for an authenticator code, with no navigation;
  //   3. ONE request changes the password. The server applies its own rules
  //      (two-factor level, optional emailed code, optional current-password
  //      check, same password, strength) and success is reported ONLY if it
  //      answers with a success status.
  //
  // WHY this replaced the old version: the old one re-checked the password with
  // signInWithPassword() on the live client. That swaps the session for a new
  // one at the password-only level, which fired the app-wide auth listener (it
  // pushed the MFA screen over everything and wiped the form) and made Supabase
  // refuse the update (it will not change the password of an account with
  // two-factor authentication on a session that is not at that level).
  Future<PasswordChangeResult> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
    String? reauthCode,
  }) async {
    final user = _supabase.auth.currentUser;
    final String? email = user?.email;
    if (user == null || email == null) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgSessionExpired);
    }

    // Deliberately NOT using LoginAttemptGuard here: it is documented as
    // consulted only by login(), and using it here would let wrong current
    // passwords in the profile lock the LOGIN for that email on this device.
    // Wrong guesses are limited by the Auth server's own rate limits (a 429
    // is handled below).

    // Login trims the password, so the current password is trimmed the same way.
    final String current = currentPassword.trim();
    final bool codeSent = reauthCode != null && reauthCode.isNotEmpty;

    try {
      // 1. Is the current password right?
      switch (await _checkCurrentPassword(email, current)) {
        case CurrentPasswordCheck.wrong:
          return const PasswordChangeResult(
            PasswordChangeStatus.wrongCurrentPassword,
            'Current password is incorrect.',
          );
        case CurrentPasswordCheck.rateLimited:
          return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgTooMany);
        case CurrentPasswordCheck.network:
          return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgNetwork);
        case CurrentPasswordCheck.error:
          return const PasswordChangeResult(
            PasswordChangeStatus.failed,
            'We couldn\'t verify your current password. Please try again.',
          );
        case CurrentPasswordCheck.correct:
          break;
      }

      // 2. Is the real session at the two-factor level?
      if (await _sessionNeedsMfa()) {
        return const PasswordChangeResult(PasswordChangeStatus.needsMfa, null);
      }

      // 3. A usable access token, read NOW (so it is the one MFA just raised).
      Session? session = _supabase.auth.currentSession;
      if (session != null && session.isExpired) {
        session = (await _supabase.auth.refreshSession()).session;
      }
      if (session == null) {
        return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgSessionExpired);
      }

      // 4. The change. current_password is always sent: the server checks it when
      // "require current password" is ON and ignores it when it is OFF.
      final AuthHttpResponse response = await _authHttp(
        'PUT',
        '/user',
        bearer: session.accessToken,
        body: <String, dynamic>{
          'password': newPassword,
          'current_password': current,
          if (codeSent) 'nonce': reauthCode,
        },
      );

      final PasswordChangeResult result =
          interpretPasswordUpdate(response, reauthCodeSent: codeSent);

      // The project requires an emailed code for this session: send it now.
      if (result.status == PasswordChangeStatus.needsReauthCode) {
        final String? sendFailure = await sendReauthenticationCode();
        if (sendFailure != null) {
          return PasswordChangeResult(PasswordChangeStatus.failed, sendFailure);
        }
        return result;
      }

      if (result.status != PasswordChangeStatus.success) return result;

      // The password HAS changed. Recording the date is best effort and can
      // never turn a successful change into an error. (A database trigger on
      // auth.users also records it, from the real change.)
      try {
        await _supabase.from('users').update({
          'password_changed_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (_) {}

      return result;
    } on SocketException catch (_) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgNetwork);
    } on TimeoutException catch (_) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgNetwork);
    } on http.ClientException catch (_) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgNetwork);
    } on AuthException catch (_) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgSessionExpired);
    } catch (_) {
      return const PasswordChangeResult(PasswordChangeStatus.failed, kMsgGeneric);
    }
  }

  // True when the account has two-factor authentication but the real session is
  // not at that level yet. If this check itself fails it answers false: the
  // server applies the same rule, and its refusal is handled by the caller.
  Future<bool> _sessionNeedsMfa() async {
    try {
      final aal = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aal.currentLevel == AuthenticatorAssuranceLevels.aal2) return false;
      final factors = await _supabase.auth.mfa.listFactors();
      return factors.totp.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Checks the current password with a plain HTTPS request to the Auth server.
  // The session this creates is closed again straight away (this one only).
  //
  // WHY plain HTTP and not a second Supabase client: on the web every auth
  // client in a browser tab shares one broadcast channel. A second client signing
  // in or out is announced on it, and the real client then ADOPTS that session
  // (dropping its two-factor level) or drops its own. Plain HTTP involves no
  // client, no shared storage and no broadcast, and the token never leaves
  // this method: it is not stored anywhere.
  Future<CurrentPasswordCheck> _checkCurrentPassword(String email, String password) async {
    try {
      final AuthHttpResponse r = await _authHttp(
        'POST',
        '/token?grant_type=password',
        body: <String, dynamic>{'email': email, 'password': password},
      );

      final CurrentPasswordCheck check = interpretPasswordGrant(r);
      if (check == CurrentPasswordCheck.correct) {
        final dynamic token = r.json?['access_token'];
        if (token is String && token.isNotEmpty) {
          try {
            await _authHttp('POST', '/logout?scope=local', bearer: token);
          } catch (_) {
            // If closing it fails, it simply expires on its own.
          }
        }
      }
      return check;
    } on SocketException catch (_) {
      return CurrentPasswordCheck.network;
    } on TimeoutException catch (_) {
      return CurrentPasswordCheck.network;
    } on http.ClientException catch (_) {
      return CurrentPasswordCheck.network;
    } catch (_) {
      return CurrentPasswordCheck.error;
    }
  }

  // One request to the Auth server, with the project's public key. The
  // URL and key come from env.public, the same file main.dart reads.
  Future<AuthHttpResponse> _authHttp(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    final String? base = dotenv.env['SUPABASE_URL'];
    final String? key = dotenv.env['SUPABASE_ANON_KEY'];
    if (base == null || base.isEmpty || key == null || key.isEmpty) {
      throw StateError('Auth configuration is missing.');
    }

    final Uri uri = Uri.parse('$base/auth/v1$path');
    final Map<String, String> headers = <String, String>{
      'apikey': key,
      'Content-Type': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
    final String payload = jsonEncode(body ?? <String, dynamic>{});

    final http.Response response = method == 'PUT'
        ? await http.put(uri, headers: headers, body: payload).timeout(const Duration(seconds: 20))
        : await http.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 20));

    return AuthHttpResponse.fromRaw(response.statusCode, response.body);
  }

  // Asks the project to email a one-time code for the "require reauthentication"
  // setting. Returns null when sent, otherwise a message that is safe to show.
  Future<String?> sendReauthenticationCode() async {
    try {
      await _supabase.auth.reauthenticate();
      return null;
    } on AuthException catch (error) {
      if (error.statusCode == '429') {
        return 'Please wait a moment before asking for another code.';
      }
      return 'We couldn\'t send the code. Please try again.';
    } on SocketException catch (_) {
      return kMsgNetwork;
    } on http.ClientException catch (_) {
      return kMsgNetwork;
    } catch (_) {
      return 'We couldn\'t send the code. Please try again.';
    }
  }

  // ── VERIFY A 6-DIGIT AUTHENTICATOR CODE FOR THE CURRENT SESSION ──
  // Raises the real session to the two-factor level: the verify call returns a
  // new access token at aal2 and the client stores it as the current session,
  // so the next password request is sent with it. (Same check as the MFA screen,
  // including trying every enrolled authenticator.) Returns null on success,
  // otherwise a message that is safe to show.
  Future<String?> verifyMfaCode(String code) async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        return 'Two-factor authentication is not set up for this account.';
      }

      for (final factor in factors.totp) {
        try {
          final challenge =
              await _supabase.auth.mfa.challenge(factorId: factor.id);
          await _supabase.auth.mfa.verify(
            factorId: factor.id,
            challengeId: challenge.id,
            code: code.trim(),
          );
          return null;
        } on AuthException catch (error) {
          if (error.statusCode == '429') {
            return kMsgTooMany;
          }
          continue;
        }
      }
      return 'Incorrect code. Please try again.';
    } on SocketException catch (_) {
      return kMsgNetwork;
    } on http.ClientException catch (_) {
      return kMsgNetwork;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ── CHECK IF PASSWORD CHANGE IS DUE (30-day policy) ──
  Future<bool> isPasswordChangeDue() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // "Later" hides the reminder for 24 hours on this device. It does NOT
      // change the password date.
      if (await PasswordReminderSnooze.isSnoozed(user.id)) return false;

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