// lib/providers/auth/pending_password_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ================================================
// PENDING PASSWORD
//
// WHY THIS EXISTS: while someone is verifying their email, their account does
// not exist yet and nobody is signed in. If they typed their email wrongly,
// the ONLY way to get a code at the corrected address is to sign up again with
// it, and a sign-up needs the password. This keeps the password they just
// typed on the Sign Up form, so the "Edit email" pop-up can ask for ONE thing
// (the new address) instead of asking for the password a second time.
//
// HOW IT IS KEPT SAFE:
//   - IN MEMORY ONLY. It is never written to storage, a file, a log or the
//     network by this code. It already lives in the Sign Up form's own text
//     box in the same memory, so this does not widen where it exists.
//   - It is set only when the verification screen opens, and CLEARED on every
//     way out of it: finishing sign-up, closing the screen, cancelling the
//     sign-up, and starting over.
//   - It is used for exactly one thing: the sign-up request for the corrected
//     address.
// ================================================
class PendingPasswordNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String password) => state = password;
  void clear() => state = null;
}

final pendingPasswordProvider =
    NotifierProvider<PendingPasswordNotifier, String?>(() {
  return PendingPasswordNotifier();
});