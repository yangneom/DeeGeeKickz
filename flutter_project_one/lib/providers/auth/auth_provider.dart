import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/iprog_sms_service.dart';


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