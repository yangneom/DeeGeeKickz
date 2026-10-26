import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../providers/auth/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import 'staff_device_rules.dart';
import 'staff_mfa_gate.dart';


// ================================================
// STAFF DEVICE GATE
//
// Wraps the Admin, Super Admin and Cashier layouts. Whatever path brought a
// staff session here (the login form, the global listener, a saved session at
// app start, the Set Password or MFA screens, a refresh), this is the last
// check before any staff screen is built.
//
// - Decided ONCE, on the first build. Resizing the window later does not sign
//   a desktop user out.
// - If the device is not allowed, the staff screens are NEVER built (so they
//   never start loading data); the person is signed out and sent to the login
//   screen, which shows the reason.
// - If the device is allowed, this widget is invisible: it just returns the
//   layout it was given.
// ================================================
class StaffDeviceGate extends ConsumerStatefulWidget {
  final Widget child;

  const StaffDeviceGate({super.key, required this.child});

  @override
  ConsumerState<StaffDeviceGate> createState() => _StaffDeviceGateState();
}

class _StaffDeviceGateState extends ConsumerState<StaffDeviceGate> {
  StaffDeviceBlock? _block;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final StaffDeviceBlock? block = StaffDeviceGuard.blockForThisDevice(
      width: MediaQuery.of(context).size.width,
    );
    _block = block;

    if (block != null) {
      // Captured now: this widget is replaced by navigation below.
      final ErrorMessageNotifier errorNotifier =
          ref.read(errorMessageProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _leave(block, errorNotifier);
      });
    }
  }

  Future<void> _leave(
    StaffDeviceBlock block,
    ErrorMessageNotifier errorNotifier,
  ) async {
    errorNotifier.setError(block.messageFor(null));

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Even if signing out fails (for example no connection), leave the
      // staff screens. The app-start check and this gate both run again the
      // next time the session is used, so it cannot get through later.
    }

    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_block != null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
      );
    }
    // The device is allowed. The last check before any staff screen is built is the
    // MFA gate: it asks the SERVER for the account's current authenticators first and
    // the session level second, and fails closed.
    return StaffMfaGate(child: widget.child);
  }
}