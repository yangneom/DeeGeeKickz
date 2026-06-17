import 'package:flutter/material.dart';

import '../../../models/notification_model.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/notifications/notification_tile_drop.dart';
import '../../../widgets/customer/notifications/notification_tile_order.dart';
import '../../../widgets/customer/notifications/notification_tile_offer.dart';

/// Notifications screen — flat list, no filter chips.
/// Accessible via the bell icon in [AppTopBar].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Local mutable copy so mark-as-read updates the UI
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.from(fakeNotifications);
  }

  int get _unreadCount =>
      _notifications.where((n) => n.isUnread).length;

  void _markRead(String id) {
    setState(() {
      _notifications = _notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true, isUnread: false);
        return n;
      }).toList();
    });
  }

  void _markAllRead() {
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true, isUnread: false))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final hPad      = isDesktop ? 48.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'notifications'),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 896),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, 32, hPad, 80),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // ── Page header ─────────────────
                              _PageHeader(
                                unreadCount: _unreadCount,
                                onMarkAllRead: _markAllRead,
                              ),

                              const SizedBox(height: 24),

                              const Divider(
                                  height: 1,
                                  color: Color(0xFFCFC4C5)),

                              const SizedBox(height: 20),

                              // ── Notification list ───────────
                              if (_notifications.isEmpty)
                                _EmptyState()
                              else
                                Column(
                                  children: _notifications.map((n) {
                                    switch (n.type) {
                                      case NotificationType.drop:
                                        return NotificationTileDrop(
                                          notification: n,
                                          onMarkRead: () =>
                                              _markRead(n.id),
                                        );
                                      case NotificationType.order:
                                        return NotificationTileOrder(
                                          notification: n,
                                          onMarkRead: () =>
                                              _markRead(n.id),
                                        );
                                      case NotificationType.offer:
                                        return NotificationTileOffer(
                                          notification: n,
                                          onMarkRead: () =>
                                              _markRead(n.id),
                                        );
                                    }
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

// ─── Page header ──────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onMarkAllRead;

  const _PageHeader({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TitleBlock(unreadCount: unreadCount),
              if (unreadCount > 0)
                GestureDetector(
                  onTap: onMarkAllRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TitleBlock(unreadCount: unreadCount),
              if (unreadCount > 0) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onMarkAllRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          );
  }
}

class _TitleBlock extends StatelessWidget {
  final int unreadCount;
  const _TitleBlock({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'NOTIFICATIONS',
              style: TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                color: Colors.black,
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage your drop alerts, order status, and member exclusives.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF656464),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: const [
          Icon(Icons.notifications_off_outlined,
              size: 56, color: Color(0xFFCFC4C5)),
          SizedBox(height: 16),
          Text(
            'All caught up',
            style: TextStyle(
              fontFamily: 'Archivo Narrow',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'You have no notifications right now.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF656464),
            ),
          ),
        ],
      ),
    );
  }
}