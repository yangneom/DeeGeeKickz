import 'package:flutter/material.dart';

/// Order progress timeline.
///
/// [currentStep] is the 0-based index into [steps] of the stage the order is at.
/// [timestamps] has one entry per step; a null entry shows NO date. This widget
/// never makes a date up: it prints exactly what it is given.
/// [notes] is optional: a short line under a step (for example "Your payment has
/// not been confirmed yet"). Same length as [steps], or empty.
///
/// WHAT CHANGED
///   The old tracker was one horizontal Row whose step columns were as wide as
///   their widest text. On a 320px phone that was about 40px too wide
///   (overflow), on a 390px phone the connector lines were about 6px long, and
///   it used 8 to 9px text. Now:
///     - narrow (under 560px of room): a VERTICAL timeline, 13px labels, 12px
///       dates, a line joining the dots down the left side.
///     - wide: the horizontal timeline, but every step gets an equal share of
///       the width, so labels, dates and lines can never collide, and text wraps
///       instead of overflowing.
///   The three states are told apart by SHAPE as well as colour:
///     done = filled dot with a tick, current = ring with a dot inside (and the
///     word CURRENT on the vertical layout), upcoming = hollow dot.
///   "Upcoming" labels use a darker grey (5.9:1 on white, was 1.7:1).
///   The old "Est. soon" text under the last step is gone: it was an estimate
///   with no data behind it.
class OrderTrackingTimeline extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final List<String?> timestamps;
  final List<String?> notes;

  const OrderTrackingTimeline({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.timestamps,
    this.notes = const <String?>[],
  });

  /// Below this much width the horizontal layout does not fit comfortably.
  static const double _horizontalMinWidth = 560;

  static const Color _line      = Color(0xFFCFC4C5);
  static const Color _hollow    = Color(0xFF7E7576);
  static const Color _upcoming  = Color(0xFF656464);

  _StepState _stateOf(int i) {
    final bool isFinal = i == steps.length - 1;
    if (i < currentStep) return _StepState.done;
    if (i == currentStep) {
      // The last step, once reached, is finished, not "in progress".
      return isFinal ? _StepState.done : _StepState.current;
    }
    return _StepState.upcoming;
  }

  String? _ts(int i) =>
      i < timestamps.length && (timestamps[i] ?? '').isNotEmpty
          ? timestamps[i]
          : null;

  String? _note(int i) =>
      i < notes.length && (notes[i] ?? '').isNotEmpty ? notes[i] : null;

  String _spoken(int i) {
    final _StepState s = _stateOf(i);
    final String state = s == _StepState.done
        ? 'completed'
        : (s == _StepState.current ? 'current step' : 'upcoming');
    final String? ts = _ts(i);
    final String? note = _note(i);
    return '${steps[i]}, $state'
        '${ts != null ? ', $ts' : ''}'
        '${note != null ? '. $note' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Order progress',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool horizontal = constraints.maxWidth >= _horizontalMinWidth;
          return horizontal ? _buildHorizontal() : _buildVertical();
        },
      ),
    );
  }

  // ───────────────────────── dots ─────────────────────────

  Widget _dot(_StepState s, {required double size}) {
    switch (s) {
      case _StepState.done:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          child: Icon(Icons.check, size: size * 0.64, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2.5),
          ),
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
          ),
        );
      case _StepState.upcoming:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: _hollow, width: 1.5),
          ),
        );
    }
  }

  // ───────────────────────── vertical (phones) ─────────────────────────

  Widget _buildVertical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(steps.length, (int i) {
        final _StepState s = _stateOf(i);
        final bool isLast = i == steps.length - 1;
        final String? ts = _ts(i);
        final String? note = _note(i);
        // The line BELOW a step is solid only once that step is finished.
        final bool lineDone = i < currentStep;

        return Semantics(
          label: _spoken(i),
          excludeSemantics: true,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      _dot(s, size: 24),
                      if (!isLast)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 2,
                              color: lineDone ? Colors.black : _line,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Aligns the first text line with the middle of the dot.
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              steps[i].toUpperCase(),
                              style: TextStyle(
                                fontFamily:    'Inter',
                                fontSize:      13,
                                fontWeight:    s == _StepState.upcoming
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                letterSpacing: 0.5,
                                color: s == _StepState.upcoming
                                    ? _upcoming
                                    : Colors.black,
                              ),
                            ),
                            if (s == _StepState.current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontFamily:    'Inter',
                                    fontSize:      10,
                                    fontWeight:    FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color:         Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (ts != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            ts,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              color:      _upcoming,
                            ),
                          ),
                        ],
                        if (note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize:   12,
                              height:     1.4,
                              color:      _upcoming,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ───────────────────────── horizontal (wide) ─────────────────────────

  Widget _buildHorizontal() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(steps.length, (int i) {
        final _StepState s = _stateOf(i);
        final bool isFirst = i == 0;
        final bool isLast = i == steps.length - 1;
        final String? ts = _ts(i);
        final String? note = _note(i);
        // Left line: solid once this step has been reached.
        // Right line: solid once this step is finished.
        final bool leftDone = i <= currentStep;
        final bool rightDone = i < currentStep;

        return Expanded(
          child: Semantics(
            label: _spoken(i),
            excludeSemantics: true,
            child: Column(
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isFirst
                              ? Colors.transparent
                              : (leftDone ? Colors.black : _line),
                        ),
                      ),
                      _dot(s, size: 24),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isLast
                              ? Colors.transparent
                              : (rightDone ? Colors.black : _line),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    steps[i].toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily:    'Inter',
                      fontSize:      11,
                      fontWeight:    s == _StepState.upcoming
                          ? FontWeight.w500
                          : FontWeight.w700,
                      letterSpacing: 0.4,
                      color: s == _StepState.upcoming
                          ? _upcoming
                          : Colors.black,
                    ),
                  ),
                ),
                if (ts != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
                    child: Text(
                      ts,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   11,
                        color:      _upcoming,
                      ),
                    ),
                  ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize:   11,
                        height:     1.35,
                        color:      _upcoming,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

enum _StepState { done, current, upcoming }