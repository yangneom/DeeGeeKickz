// lib/widgets/auth/recovery_steps.dart
import 'package:flutter/material.dart';

// ================================================
// FORGOT-PASSWORD STEPS
//
// Shows the person where they are in "forgot password":
//   1. Email code        (the code we emailed)
//   2. Authenticator     (the code from their authenticator app, or setting one
//                         up; only accounts that need it see this step)
//   3. New password
//
// RecoveryStepper   the three (or two) labelled dots with a line between them.
// RecoveryStepFrame puts the stepper and one line of instruction ABOVE an
//                   existing full screen (the MFA code screen or the enrolment
//                   screen). Those screens are wrapped, not edited, so the login
//                   uses of them are untouched.
//
// Colours match the other auth screens (black, soft greys). Nothing here talks to
// Supabase, so it can be tested on its own.
// ================================================

class RecoveryStepper extends StatelessWidget {
  /// The steps shown, in order.
  final List<String> labels;

  /// The current step, counting from 1. Steps before it show a tick.
  final int active;

  const RecoveryStepper({super.key, required this.labels, required this.active});

  /// Accounts that use an authenticator (or must set one up): three steps.
  static const List<String> withAuthenticator = <String>[
    'Email code',
    'Authenticator',
    'New password',
  ];

  /// Accounts that don't (customers): two steps.
  static const List<String> emailOnly = <String>[
    'Email code',
    'New password',
  ];

  static const Color _black = Color(0xFF111827);
  static const Color _grey = Color(0xFF9CA3AF);
  static const Color _line = Color(0xFFE5E7EB);
  static const double _dot = 28;

  @override
  Widget build(BuildContext context) {
    final int n = labels.length;
    final int current = active.clamp(1, n);

    return Semantics(
      container: true,
      label: 'Step $current of $n: ${labels[current - 1]}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = box.maxWidth.isFinite ? box.maxWidth : 320;
            final double slot = width / n;
            final double lineStart = slot / 2;
            final double lineLength = width - slot;
            final double done = n <= 1 ? 0 : lineLength * (current - 1) / (n - 1);

            return SizedBox(
              width: width,
              child: Stack(
                children: [
                  // the grey track, and the black part that is already done
                  Positioned(
                    left: lineStart,
                    top: _dot / 2 - 1,
                    width: lineLength,
                    height: 2,
                    child: const ColoredBox(color: _line),
                  ),
                  Positioned(
                    left: lineStart,
                    top: _dot / 2 - 1,
                    width: done,
                    height: 2,
                    child: const ColoredBox(color: _black),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < n; i++)
                        Expanded(child: _step(i + 1, labels[i], current)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _step(int number, String label, int current) {
    final bool isDone = number < current;
    final bool isActive = number == current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDone || isActive) ? _black : Colors.white,
            border: Border.all(color: (isDone || isActive) ? _black : _line, width: 2),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : _grey,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? _black : _grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// A full screen with the stepper and one line of instruction above [child].
/// [child] is itself a full screen (it has its own Scaffold), so it fills the rest.
class RecoveryStepFrame extends StatelessWidget {
  final List<String> labels;
  final int active;
  final String instruction;
  final Widget child;

  const RecoveryStepFrame({
    super.key,
    required this.labels,
    required this.active,
    required this.instruction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RecoveryStepper(labels: labels, active: active),
                      const SizedBox(height: 14),
                      Text(
                        instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}