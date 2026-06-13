import 'package:flutter/material.dart';

/// Shared progress indicator for the 3-step checkout flow.
/// step: 1 = Shipping, 2 = Review, 3 = Payment
class CheckoutProgressBar extends StatelessWidget {
  final int currentStep;

  const CheckoutProgressBar({super.key, required this.currentStep});

  static const List<String> _labels = ['Shipping', 'Review', 'Payment'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFCFC4C5), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final stepNumber = i + 1;
          final isActive = stepNumber == currentStep;
          final isCompleted = stepNumber < currentStep;

          return Padding(
            padding: EdgeInsets.only(right: i < _labels.length - 1 ? 24 : 0),
            child: _StepChip(
              number: '$stepNumber',
              label: _labels[i],
              isActive: isActive,
              isCompleted: isCompleted,
            ),
          );
        }),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String number;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepChip({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (isActive || isCompleted) ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: isActive
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2),
                ),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? Colors.black
                    : Colors.transparent,
                border: isCompleted || isActive
                    ? null
                    : Border.all(color: const Color(0xFF7E7576)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : Text(
                      number,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF7E7576),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.7,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}