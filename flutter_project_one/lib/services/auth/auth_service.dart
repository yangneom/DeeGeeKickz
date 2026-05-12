// Firebase Authentication import
// Handles login, register, logout, and email verification
import 'package:firebase_auth/firebase_auth.dart';

// Firestore import
// Handles saving user profile data to the database
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser {
    return _auth.currentUser;
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  Future<String?> getUserRole() async {
    try {
      User? user = _auth.currentUser;

      if (user == null) {
        print('getUserRole: No current user found');
        return null;
      }

      print('getUserRole: Looking up UID ${user.uid}');

      DocumentSnapshot doc = await _firestore
          .collection('user')
          .doc(user.uid)
          .get();

      // ✅ NEW DEBUG LINES
      print('getUserRole: doc.exists = ${doc.exists}');
      print('getUserRole: doc.id = ${doc.id}');
      print('getUserRole: doc.data() = ${doc.data()}');

      if (doc.exists) {
        final role = doc.get('role') as String?;
        print('getUserRole: Found role = $role');
        return role;
      }

      print('getUserRole: Document does not exist for UID ${user.uid}');
      return null;

    } catch (error) {
      print('getUserRole error: $error');
      return null;
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {

    try {

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      print('Login successful for ${email.trim()}');
      return null;

    } on FirebaseAuthException catch (error) {

      print('FirebaseAuthException code: ${error.code}');
      print('FirebaseAuthException message: ${error.message}');

      if (error.code == 'user-not-found') {
        return 'No account found with this email.';
      } else if (error.code == 'wrong-password') {
        return 'Wrong password. Please try again.';
      } else if (error.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      } else if (error.code == 'user-disabled') {
        return 'This account has been disabled.';
      } else if (error.code == 'invalid-credential') {
        return 'Incorrect email or password. Please try again.';
      } else if (error.code == 'too-many-requests') {
        return 'Too many failed attempts. Please try again later.';
      } else {
        return 'Login failed (${error.code}). Please try again.';
      }
    }
  }

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {

    try {

      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User newUser = credential.user!;
      print('Register: Created auth user with UID ${newUser.uid}');

      await _firestore
          .collection('user')
          .doc(newUser.uid)
          .set({
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'role': 'customer',
          });

      print('Register: Saved user profile to Firestore');

      await newUser.sendEmailVerification();
      print('Register: Verification email sent');

      return null;

    } on FirebaseAuthException catch (error) {

      print('Register FirebaseAuthException code: ${error.code}');

      if (error.code == 'email-already-in-use') {
        return 'An account already exists with this email.';
      } else if (error.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      } else if (error.code == 'weak-password') {
        return 'Password is too weak. Use at least 6 characters.';
      } else {
        return 'Registration failed (${error.code}). Please try again.';
      }

    } catch (error) {
      print('Register unknown error: $error');
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    print('User logged out');
  }
}