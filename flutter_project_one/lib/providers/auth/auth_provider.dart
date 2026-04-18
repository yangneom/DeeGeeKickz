import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/auth_service.dart';

// Creates ONE AuthService for the whole app
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Watches if user is logged in or not
final authStateProvider = StreamProvider<User?>((ref) {
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

final registerIsLoadingProvider = NotifierProvider<RegisterIsLoadingNotifier, bool>(() {
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

final registerErrorProvider = NotifierProvider<RegisterErrorNotifier, String?>(() {
  return RegisterErrorNotifier();
});