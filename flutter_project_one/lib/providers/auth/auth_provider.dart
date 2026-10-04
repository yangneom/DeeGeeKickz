import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/iprog_sms_service.dart';
import '../../main.dart';
import '../../screens/auth/login_screen.dart';


// Creates ONE AuthService for the whole app
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Watches if user is logged in or not
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Tracks if LOGIN is currently loading
class IsLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
}

final isLoadingProvider = NotifierProvider<IsLoadingNotifier, bool>(() {
  return IsLoadingNotifier();
});

// Stores error message when LOGIN fails
class ErrorMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? message) {
    state = message;
  }
}

final errorMessageProvider = NotifierProvider<ErrorMessageNotifier, String?>(() {
  return ErrorMessageNotifier();
});

// Tracks if REGISTER is currently loading
class RegisterIsLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) {
    state = value;
  }
}

final registerIsLoadingProvider =
    NotifierProvider<RegisterIsLoadingNotifier, bool>(() {
  return RegisterIsLoadingNotifier();
});


// Stores error message when REGISTER fails
class RegisterErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? message) {
    state = message;
  }
}

final registerErrorProvider =
    NotifierProvider<RegisterErrorNotifier, String?>(() {
  return RegisterErrorNotifier();
});


final iprogSmsServiceProvider = Provider<IprogSmsService>((ref) {
  return IprogSmsService();
});

// Holds the signup form data between the register screen and the OTP screen,
// since we don't insert the profile row until both OTPs are verified.
class PendingRegistration {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  const PendingRegistration({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });
}

class PendingRegistrationNotifier extends Notifier<PendingRegistration?> {
  @override
  PendingRegistration? build() => null;

  void set(PendingRegistration data) => state = data;
  void clear() => state = null;
}

final pendingRegistrationProvider =
    NotifierProvider<PendingRegistrationNotifier, PendingRegistration?>(() {
  return PendingRegistrationNotifier();
});

// ── OWN PROFILE (Realtime-aware) ──
// Lets a logged-in staff member's own top bar/greeting update
// automatically if their profile is edited elsewhere (e.g. a Super
// Admin editing their name in Admin Management) — without this,
// their already-open session would keep showing the old name until
// they manually refreshed or logged back in.
final ownProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Depends on WHO is logged in. A bare currentUser read inside a
  // never-disposed provider is evaluated once and then cached, so after
  // logout -> login as someone else the new user's top bar kept showing
  // the previous user's name/role. Watching the user id makes this
  // rebuild whenever the account changes (token refreshes keep the same
  // id, so they don't refetch).
  final String? userId = ref.watch(
    authStateProvider.select((a) => a.value?.session?.user.id),
  );
  if (userId == null) return null;
  return await Supabase.instance.client
      .from('users')
      .select('first_name, last_name, email, phone, role')
      .eq('id', userId)
      .maybeSingle();
});

final ownProfileRealtimeProvider = Provider<void>((ref) {
  final supabase = Supabase.instance.client;
  // Same reasoning as ownProfileProvider: follow the logged-in account,
  // so the subscription moves to the new user's row after a
  // logout -> login instead of staying stuck on the previous user.
  final String? userId = ref.watch(
    authStateProvider.select((a) => a.value?.session?.user.id),
  );
  if (userId == null) return;

  final channel = supabase
      .channel('own_profile_changes_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'users',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          ref.invalidate(ownProfileProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });
});

// ── CUSTOMER DISABLED-ACCOUNT WATCHER ──
// Reuses the same postgres_changes + auth.uid() filter pattern as
// ownProfileRealtimeProvider, but reacts instead of just refreshing:
// if is_disabled flips to true while a Customer is actively browsing,
// force sign-out + redirect immediately, rather than waiting for
// their next login attempt to discover it (deleting the server-side
// session alone doesn't invalidate an already-issued access token).
bool _disabledWatcherTriggered = false;

final customerDisabledWatcherProvider = Provider<void>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return;

  _disabledWatcherTriggered = false;

  final channel = supabase
      .channel('customer_disabled_watcher_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'users',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: user.id,
        ),
        callback: (payload) async {
          if (_disabledWatcherTriggered) return;

          final bool isDisabled = payload.newRecord['is_disabled'] == true;
          if (!isDisabled) return;

          _disabledWatcherTriggered = true;

          final String reason = payload.newRecord['disabled_reason'] as String? ??
              'Your account has been suspended.';

          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(reason),
                backgroundColor: const Color(0xFFDC2626),
                duration: const Duration(seconds: 6),
              ),
            );
          }

          await supabase.auth.signOut();

          appNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });
});