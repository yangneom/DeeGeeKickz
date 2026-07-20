import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/auth/login_screen.dart';

/// Call this instead of Navigator.push whenever a screen should be
/// gated behind login (checkout, chat, profile, notifications, write review).
///
/// - Logged in  → pushes [destination] directly.
/// - Guest      → pushes LoginScreen instead. LoginForm already redirects
///                to HomeScreen on success, so the guest lands on Home,
///                not back on the page they were trying to reach.
void requireAuth(BuildContext context, Widget destination) {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => destination),
  );
}