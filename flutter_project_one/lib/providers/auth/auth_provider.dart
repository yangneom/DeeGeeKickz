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

// Tracks if login is currently loading
// Using Notifier instead of StateProvider (new Riverpod 3.x way)
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

// Stores error message when login fails
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