import 'package:flutter/material.dart';

/// Shared progress indicator for the 3-step checkout flow.
/// step: 1 = Shipping, 2 = Review, 3 = Payment
///
/// WHAT CHANGED
///   - It no longer overflows on narrow phones. The old bar was a Row of three
///     chips with fixed 24px gaps, about 314px wide: too wide for a 320px
///     phone once the page padding is taken off.
///   - On phones the labels sit UNDER the dots and the steps are joined by thin
///     lines, so the bar is short, always fits, and still shows every label.
///   - Finished steps show a tick, the current step is a solid dot with a bold
///     label, and upcoming steps are an outline with a grey label (the old bar
///     faded them with 40% opacity, which made them hard to read).
///   - A finished step can be tapped to go back to it ([onStepTap]). Nothing the
///     customer entered is cleared by that; the checkout screen keeps it all.
class CheckoutProgressBar extends StatelessWidget {
  final int currentStep;

  /// Called with the step number when a FINISHED step is tapped. The current
  /// and upcoming steps are not tappable.
  final ValueChanged<int>? onStepTap;

  const CheckoutProgressBar({
    super.key,
    required this.currentStep,
    this.onStepTap,
  });

  static const List<String> _labels = ['Shipping', 'Review', 'Payment'];

  @override
  Widget build(BuildContext context) {
    final int currentIndex =
        (currentStep - 1).clamp(0, _labels.length - 1).toInt();

    return Semantics(
      container: true,
      label: 'Checkout progress. Step ${currentIndex + 1} of '
          '${_labels.length}: ${_labels[currentIndex]}',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 480;

          final List<Widget> children = <Widget>[];
          for (int i = 0; i < _labels.length; i++) {
            final int stepNumber = i + 1;
            final _StepState state = stepNumber < currentStep
                ? _StepState.done
                : (stepNumber == currentStep
                    ? _StepState.current
                    : _StepState.upcoming);

            children.add(
              _Step(
                number: stepNumber,
                label: _labels[i],
                state: state,
                compact: compact,
                onTap: (state == _StepState.done && onStepTap != null)
                    ? () => onStepTap!(stepNumber)
                    : null,
              ),
            );

            if (i < _labels.length - 1) {
              children.add(
                Expanded(
                  child: _Connector(
                    done: stepNumber < currentStep,
                    compact: compact,
                  ),
                ),
              );
            }
          }

          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFCFC4C5), width: 1),
              ),
            ),
            padding: EdgeInsets.only(bottom: compact ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
        },
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _Step extends StatelessWidget {
  final int number;
  final String label;
  final _StepState state;
  final bool compact;
  final VoidCallback? onTap;

  const _Step({
    required this.number,
    required this.label,
    required this.state,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = state == _StepState.done;
    final bool isCurrent = state == _StepState.current;
    final bool isFilled = isDone || isCurrent;
    final double dotSize = compact ? 24 : 26;

    final Widget dot = Container(
      width: dotSize,
      height: dotSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled ? Colors.black : Colors.transparent,
        shape: BoxShape.circle,
        border: isFilled
            ? null
            : Border.all(color: const Color(0xFF7E7576), width: 1.5),
      ),
      child: isDone
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : Text(
              '$number',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.white : const Color(0xFF7E7576),
              ),
            ),
    );

    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: compact ? 11 : 14,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: compact ? 0.3 : 0.7,
        color: isFilled ? Colors.black : const Color(0xFF7E7576),
      ),
    );

    final Widget content = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [dot, const SizedBox(height: 4), text],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [dot, const SizedBox(width: 8), text],
          );

    final String status =
        isDone ? 'completed' : (isCurrent ? 'current step' : 'upcoming');

    // A fixed 44px tall box keeps the touch target comfortable and keeps the
    // dot's centre at a known height, so the connector lines line up with it.
    final Widget box = SizedBox(
      height: 44,
      child: Align(
        alignment: compact ? Alignment.topCenter : Alignment.centerLeft,
        child: content,
      ),
    );

    return Semantics(
      label: 'Step $number: $label, $status',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? box
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: box,
            ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool done;
  final bool compact;

  const _Connector({required this.done, required this.compact});

  @override
  Widget build(BuildContext context) {
    // Vertically centred on the dots: the dot centre is 12px down in the phone
    // layout (dots at the top of the box) and 22px down in the wide layout
    // (dots centred in the 44px box). The line is 1.5px tall.
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 11.25 : 21.25,
        left: 8,
        right: 8,
      ),
      child: Container(
        height: 1.5,
        color: done ? Colors.black : const Color(0xFFCFC4C5),
      ),
    );
  }
}