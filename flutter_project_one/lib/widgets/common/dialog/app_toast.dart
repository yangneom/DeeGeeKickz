import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ================================================
// APP TOAST — the ONE toast notification for the whole app.
//
// Replaces every snackbar. A small floating white card with a colored
// accent bar on the left, a status icon, and a clear message:
//
//   AppToast.success(context, 'Your name has been updated.');
//   AppToast.error(context, 'We could not save your changes.',
//       title: 'Save failed');
//   AppToast.warning(context, 'Only 2 pairs are left in this size.');
//   AppToast.info(context, 'There is no data to export.');
//
// Colors:  green = success · red = error · amber = warning · blue = info
// Where:   top-CENTER of the screen on every screen size, sliding down
//          from the top. 380px wide on desktop and tablet; on narrow
//          screens it shrinks to fit, always leaving a 16px margin on
//          both sides.
// Timing:  success 3.5s · info 4s · warning 5.5s · error 7s, plus extra
//          reading time for long messages (max 14s). Hovering with a mouse
//          pauses the timer. Every toast has a close (x) button.
// Layering: ALWAYS on top, including above dialogs and modals (even ones
//          that open after the toast appeared). This works because the
//          toasts are drawn by AppToastLayer, which wraps the whole
//          navigator in MaterialApp.builder (see AppToastLayer below). The
//          close button stays clickable while a modal is open, and toasts
//          keep showing while the app navigates (e.g. after a forced
//          logout). If the layer is not installed, toasts fall back to the
//          root overlay and are brought to the front each time one is shown.
// Stacking: at most 3 at once, and an identical toast that is already on
//          screen is ignored (double taps don't pile up).
//
// RULES
//   - Field validation errors stay INLINE under their input. Never toast
//     one per field.
//   - Use readable wording. Never pass raw exception text; say what
//     happened and what to do next.
//   - Questions ("Are you sure?") use showConfirmDialog. Things the user
//     must acknowledge before continuing may use showAppPopup.
// ================================================

enum AppToastType { success, error, warning, info }

class _ToastItem {
  final int id;
  final AppToastType type;
  final String? title;
  final String message;
  final Duration duration;

  const _ToastItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
  });
}

class AppToast {
  AppToast._();

  static final ValueNotifier<List<_ToastItem>> _items =
      ValueNotifier<List<_ToastItem>>(<_ToastItem>[]);
  static OverlayEntry? _entry;
  static int _nextId = 0;
  static const int _maxVisible = 3;
  // How many AppToastLayer widgets are mounted (0 = fallback mode).
  static int _layerCount = 0;

  static void success(BuildContext context, String message,
      {String? title, Duration? duration}) {
    show(context, AppToastType.success, message,
        title: title, duration: duration);
  }

  static void error(BuildContext context, String message,
      {String? title, Duration? duration}) {
    show(context, AppToastType.error, message,
        title: title, duration: duration);
  }

  static void warning(BuildContext context, String message,
      {String? title, Duration? duration}) {
    show(context, AppToastType.warning, message,
        title: title, duration: duration);
  }

  static void info(BuildContext context, String message,
      {String? title, Duration? duration}) {
    show(context, AppToastType.info, message,
        title: title, duration: duration);
  }

  static void show(
    BuildContext context,
    AppToastType type,
    String message, {
    String? title,
    Duration? duration,
  }) {
    final String text = message.trim();
    if (text.isEmpty) return;

    // Same toast already on screen (e.g. a double tap): ignore it.
    final bool duplicate = _items.value.any(
      (i) => i.type == type && i.message == text && i.title == title,
    );
    if (duplicate) return;

    // With AppToastLayer installed no overlay is needed at all.
    final OverlayState? overlay =
        _layerCount > 0 ? null : Overlay.maybeOf(context, rootOverlay: true);
    if (_layerCount == 0 && overlay == null) return;

    final _ToastItem item = _ToastItem(
      id: _nextId++,
      type: type,
      title: title,
      message: text,
      duration: duration ?? _defaultDuration(type, text),
    );

    List<_ToastItem> next = <_ToastItem>[..._items.value, item];
    if (next.length > _maxVisible) {
      next = next.sublist(next.length - _maxVisible);
    }
    _items.value = next;

    // The layer draws it, above everything. Nothing more to do.
    if (_layerCount > 0) return;

    // Fallback (layer not installed): use the root overlay, and bring the
    // entry to the front every time so a dialog opened in the meantime
    // can't hide it.
    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _ToastHost());
      overlay!.insert(_entry!);
    } else {
      overlay!.rearrange(<OverlayEntry>[_entry!]);
    }
  }

  // Called by a card AFTER its exit animation has finished.
  static void _dismiss(int id) {
    final List<_ToastItem> next =
        _items.value.where((i) => i.id != id).toList();
    _items.value = next;
    if (next.isEmpty) {
      _entry?.remove();
      _entry = null;
    }
  }

  static Duration _defaultDuration(AppToastType type, String message) {
    final int base;
    switch (type) {
      case AppToastType.success:
        base = 3500;
        break;
      case AppToastType.info:
        base = 4000;
        break;
      case AppToastType.warning:
        base = 5500;
        break;
      case AppToastType.error:
        base = 7000;
        break;
    }
    // Long messages need more time to read.
    final int extraChars = math.max(0, math.min(400, message.length - 60));
    return Duration(milliseconds: math.min(14000, base + extraChars * 40));
  }
}

/// Install ONCE, above the navigator, in MaterialApp.builder:
///
///   MaterialApp(
///     ...
///     builder: (context, appChild) =>
///         AppToastLayer(child: appChild ?? const SizedBox.shrink()),
///   )
///
/// Because it sits outside the navigator, toasts are drawn above every
/// page AND every dialog/modal.
class AppToastLayer extends StatefulWidget {
  final Widget child;

  const AppToastLayer({super.key, required this.child});

  @override
  State<AppToastLayer> createState() => _AppToastLayerState();
}

class _AppToastLayerState extends State<AppToastLayer> {
  @override
  void initState() {
    super.initState();
    AppToast._layerCount++;
  }

  @override
  void dispose() {
    AppToast._layerCount--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        // Only the toasts take up space, so everything else stays clickable.
        const _ToastHost(),
      ],
    );
  }
}

// Positions the stack of toasts: horizontally CENTERED at the top of the
// screen on every screen size (desktop, tablet and phone), so a toast looks
// the same wherever it appears and never ends up stuck to one side.
class _ToastHost extends StatelessWidget {
  const _ToastHost();

  // Widest a toast gets (desktop / tablet). On narrow screens it shrinks to
  // fit, always leaving _sideMargin free on both sides.
  static const double _maxWidth = 380;
  static const double _sideMargin = 16;

  // Distance below the top edge (plus the phone's status bar / notch). Kept
  // small so the toast sits over a dialog's title area, above its first form
  // fields, instead of covering them. Raise it if you ever want the toast to
  // clear a taller header.
  static const double _topOffset = 12;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double width =
        math.max(0.0, math.min(_maxWidth, media.size.width - 2 * _sideMargin));

    // A full-width strip anchored to the top, with the toasts centered inside
    // it. Only the toast cards themselves receive taps; the empty parts of the
    // strip let touches fall through, so the page underneath stays clickable.
    return Positioned(
      top: media.padding.top + _topOffset,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: ValueListenableBuilder<List<_ToastItem>>(
            valueListenable: AppToast._items,
            builder: (BuildContext context, List<_ToastItem> items, Widget? _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final _ToastItem item in items)
                    Padding(
                      key: ValueKey<int>(item.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      // Always slides down from the top, since it is
                      // centered (sliding in from the right looked wrong).
                      child: _ToastCard(item: item, fromTop: true),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final _ToastItem item;
  final bool fromTop;

  const _ToastCard({required this.item, required this.fromTop});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: widget.fromTop ? const Offset(0, -0.4) : const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(curve);

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.item.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    AppToast._dismiss(widget.item.id);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // accent = the bar, iconColor = the icon (amber is darkened a little so
  // the icon stays readable on white). The icon shape and the optional
  // title also differ per type, so color is never the only signal.
  ({IconData icon, Color accent, Color iconColor}) _style(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return (
          icon: Icons.check_circle,
          accent: const Color(0xFF16A34A),
          iconColor: const Color(0xFF16A34A),
        );
      case AppToastType.error:
        return (
          icon: Icons.error,
          accent: const Color(0xFFDC2626),
          iconColor: const Color(0xFFDC2626),
        );
      case AppToastType.warning:
        return (
          icon: Icons.warning_rounded,
          accent: const Color(0xFFF59E0B),
          iconColor: const Color(0xFFD97706),
        );
      case AppToastType.info:
        // Neutral near-black: matches the shoe store's black-and-white
        // identity (black buttons and pills) instead of the staff blue.
        return (
          icon: Icons.info,
          accent: const Color(0xFF111827),
          iconColor: const Color(0xFF111827),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(widget.item.type);
    final String? title = widget.item.title?.trim();
    final bool hasTitle = title != null && title.isNotEmpty;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          // Mouse users: hovering pauses the countdown so they can read.
          onEnter: (_) => _timer?.cancel(),
          onExit: (_) {
            if (!_closing) _startTimer();
          },
          child: Semantics(
            // Screen readers announce the toast when it appears.
            liveRegion: true,
            container: true,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // colored accent bar
                        Container(width: 5, color: style.accent),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    style.icon,
                                    size: 20,
                                    color: style.iconColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasTitle) ...[
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          widget.item.message,
                                          style: TextStyle(
                                            fontSize: hasTitle ? 13 : 13.5,
                                            fontWeight: hasTitle
                                                ? FontWeight.w400
                                                : FontWeight.w500,
                                            color: hasTitle
                                                ? const Color(0xFF4B5563)
                                                : const Color(0xFF111827),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // No `tooltip:` on purpose: the toast layer
                                // sits outside the navigator, where a tooltip
                                // would find no Overlay. The label is for
                                // screen readers instead.
                                Semantics(
                                  button: true,
                                  label: 'Dismiss notification',
                                  excludeSemantics: true,
                                  onTap: _close,
                                  child: IconButton(
                                    onPressed: _close,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}