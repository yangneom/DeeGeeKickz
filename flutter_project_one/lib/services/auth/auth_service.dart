// This imports Firebase Authentication
// Firebase Authentication handles login, register, and logout
import 'package:firebase_auth/firebase_auth.dart';

// This class is responsible for ALL login and logout logic
// Think of this as the "worker" that talks to Firebase
class AuthService {

  // This is our connection to Firebase Authentication
  // We use underscore "_" to mean this is private
  // Private means only THIS file can use _auth directly
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================================================
  // GET CURRENT USER
  // This tells us WHO is currently logged in
  // Returns the User object if someone is logged in
  // Returns null if nobody is logged in
  // ================================================
  User? get currentUser {
    return _auth.currentUser;
  }

  // ================================================
  // AUTH STATE CHANGES
  // This is like a "watcher" 
  // It automatically fires when:
  //   - Someone logs in  → sends User object
  //   - Someone logs out → sends null
  // We use Stream because it keeps watching over time
  // ================================================
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // ================================================
  // LOGIN FUNCTION
  // This function logs in a user with email and password
  // 
  // Returns null    → if login was SUCCESSFUL
  // Returns String  → if login FAILED (the error message)
  // ================================================
  Future<String?> login({
    required String email,
    required String password,
  }) async {

    // "try" means attempt to do something
    // If it fails, "catch" will handle the error
    try {

      // Try to sign in with Firebase
      // .trim() removes any extra spaces the user accidentally typed
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // If we reach this line, login was SUCCESSFUL
      // Return null to mean "no error"
      return null;

    } on FirebaseAuthException catch (error) {

      // If login FAILED, Firebase gives us an error code
      // We convert that error code into a friendly message

      // User typed wrong email
      if (error.code == 'user-not-found') {
        return 'No account found with this email.';
      }

      // User typed wrong password
      else if (error.code == 'wrong-password') {
        return 'Wrong password. Please try again.';
      }

      // Email format is wrong (missing @ for example)
      else if (error.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      }

      // Account was disabled by admin
      else if (error.code == 'user-disabled') {
        return 'This account has been disabled.';
      }

      // Any other error we don't know about
      else {
        return 'Login failed. Please try again.';
      }
    }
  }

  // ================================================
  // LOGOUT FUNCTION
  // This function logs out the current user
  // Very simple - just call Firebase signOut
  // ================================================
  Future<void> logout() async {
    await _auth.signOut();
  }
}