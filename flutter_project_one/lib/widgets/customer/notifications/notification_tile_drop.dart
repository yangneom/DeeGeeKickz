import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';

/// Notification card for [NotificationType.drop].
/// Shows product image, title, body, live countdown, and Remind Me / Sold Out.
/// Tapping the card marks it as read via [onMarkRead].
class NotificationTileDrop extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileDrop({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  State<NotificationTileDrop> createState() => _NotificationTileDropState();
}

class _NotificationTileDropState extends State<NotificationTileDrop> {
  late int _seconds;
  Timer? _timer;
  bool _reminded = false;

  bool get _hasCountdown =>
      widget.notification.countdownSeconds != null &&
      !widget.notification.isSoldOut;

  @override
  void initState() {
    super.initState();
    _seconds = widget.notification.countdownSeconds ?? 0;
    if (_hasCountdown && _seconds > 0) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds <= 0) {
        _timer?.cancel();
        return;
      }
      if (mounted) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final n        = widget.notification;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return GestureDetector(
      onTap: widget.onMarkRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        ),
        child: isDesktop
            ? _DesktopLayout(
                notification: n,
                isSoldOut: n.isSoldOut,
                hasCountdown: _hasCountdown,
                formatted: _formatted,
                reminded: _reminded,
                onRemind: () => setState(() => _reminded = true),
              )
            : _MobileLayout(
                notification: n,
                isSoldOut: n.isSoldOut,
                hasCountdown: _hasCountdown,
                formatted: _formatted,
                reminded: _reminded,
                onRemind: () => setState(() => _reminded = true),
              ),
      ),
    );
  }
}

// ─── Layouts ──────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final AppNotification notification;
  final bool isSoldOut;
  final bool hasCountdown;
  final String formatted;
  final bool reminded;
  final VoidCallback onRemind;

  const _DesktopLayout({
    required this.notification,
    required this.isSoldOut,
    required this.hasCountdown,
    required this.formatted,
    required this.reminded,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        if (notification.imageUrl != null)
          _ProductImage(url: notification.imageUrl!),

        const SizedBox(width: 20),

        // Content
        Expanded(
          child: _Content(
            notification: notification,
            isSoldOut: isSoldOut,
            hasCountdown: hasCountdown,
            formatted: formatted,
            reminded: reminded,
            onRemind: onRemind,
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final AppNotification notification;
  final bool isSoldOut;
  final bool hasCountdown;
  final String formatted;
  final bool reminded;
  final VoidCallback onRemind;

  const _MobileLayout({
    required this.notification,
    required this.isSoldOut,
    required this.hasCountdown,
    required this.formatted,
    required this.reminded,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notification.imageUrl != null) ...[
          _ProductImage(url: notification.imageUrl!, fullWidth: true),
          const SizedBox(height: 14),
        ],
        _Content(
          notification: notification,
          isSoldOut: isSoldOut,
          hasCountdown: hasCountdown,
          formatted: formatted,
          reminded: reminded,
          onRemind: onRemind,
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;
  final bool fullWidth;
  const _ProductImage({required this.url, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : 120,
      height: 120,
      color: const Color(0xFFEEEEEE),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.shopping_bag_outlined,
          size: 36,
          color: Color(0xFF656464),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final AppNotification notification;
  final bool isSoldOut;
  final bool hasCountdown;
  final String formatted;
  final bool reminded;
  final VoidCallback onRemind;

  const _Content({
    required this.notification,
    required this.isSoldOut,
    required this.hasCountdown,
    required this.formatted,
    required this.reminded,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type label + time
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'UPCOMING DROP',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.black,
              ),
            ),
            Row(
              children: [
                if (notification.isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  notification.timeAgo,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF656464),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          notification.title,
          style: const TextStyle(
            fontFamily: 'Archivo Narrow',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          notification.body,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF656464),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 14),

        // Countdown + action row
        Row(
          children: [
            if (isSoldOut) ...[
              const Icon(Icons.lock_clock_outlined,
                  size: 18, color: Color(0xFF656464)),
              const SizedBox(width: 6),
              const Text(
                'Ended',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF656464),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCFC4C5)),
                ),
                child: const Text(
                  'SOLD OUT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF656464),
                  ),
                ),
              ),
            ] else if (hasCountdown) ...[
              const Icon(Icons.schedule_outlined,
                  size: 18, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                formatted,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: reminded ? null : onRemind,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  color: reminded
                      ? const Color(0xFFEEEEEE)
                      : Colors.black,
                  child: Text(
                    reminded ? 'REMINDED ✓' : 'REMIND ME',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: reminded
                          ? const Color(0xFF656464)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}