import 'package:flutter/material.dart';

/// Full horizontal order progress timeline.
/// Matches the mockup: dots connected by lines, step label + timestamp below.
///
/// [currentStep] is 0-based index into [steps].
/// [timestamps] is optional — same length as [steps], null entries show nothing.
class OrderTrackingTimeline extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final List<String?> timestamps;

  const OrderTrackingTimeline({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.timestamps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        // Odd indices = connector lines between dots
        if (i.isOdd) {
          final stepIndex = (i - 1) ~/ 2;
          final isDone    = stepIndex < currentStep;
          return Expanded(
            child: Padding(
              // Align line vertically with dot centre (~10px down from top)
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                height: 2,
                color: isDone ? Colors.black : const Color(0xFFCFC4C5),
              ),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone    = stepIndex <= currentStep;
        final isCurrent = stepIndex == currentStep;
        final isFuture  = stepIndex > currentStep;
        final ts        = stepIndex < timestamps.length
            ? timestamps[stepIndex]
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Dot ───────────────────────────────────────────────
            Container(
              width: isCurrent ? 20 : 16,
              height: isCurrent ? 20 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? Colors.black
                    : Colors.white,
                border: Border.all(
                  color: isFuture
                      ? const Color(0xFFCFC4C5)
                      : Colors.black,
                  width: isCurrent ? 2.5 : 1.5,
                ),
              ),
              child: isCurrent
                  ? null
                  : isDone
                      ? const Icon(Icons.check,
                          size: 10, color: Colors.white)
                      : null,
            ),

            const SizedBox(height: 6),

            // ── Step label ─────────────────────────────────────────
            Text(
              steps[stepIndex].toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight:
                    isCurrent ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.4,
                color: isFuture
                    ? const Color(0xFFCFC4C5)
                    : Colors.black,
              ),
            ),

            const SizedBox(height: 3),

            // ── Timestamp ──────────────────────────────────────────
            if (ts != null)
              Text(
                ts,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 8,
                  color: Color(0xFF656464),
                ),
              )
            else if (stepIndex == steps.length - 1 && isFuture)
              Text(
                'Est. soon',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 8,
                  color: Color(0xFFCFC4C5),
                ),
              ),
          ],
        );
      }),
    );
  }
}