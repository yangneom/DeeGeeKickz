// lib/screens/customer/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_model.dart';
import '../../../providers/customer/notification_provider.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/nav/app_footer.dart';
import '../../../widgets/customer/notifications/notification_tile_order.dart';
import '../../../widgets/customer/notifications/notification_tile_offer.dart';

/// Notifications screen — reads from [NotificationProvider].
/// Accessible via the bell icon in [AppTopBar].
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationProvider);
    final notifier   = ref.read(notificationProvider.notifier);

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
                        constraints: const BoxConstraints(maxWidth: 896),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Page header ──────────────────
                              _PageHeader(
                                unreadCount: notifState.unreadCount,
                                onMarkAllRead: notifier.markAllRead,
                              ),

                              const SizedBox(height: 24),
                              const Divider(height: 1, color: Color(0xFFCFC4C5)),
                              const SizedBox(height: 20),

                              // ── Body ─────────────────────────
                              if (notifState.isLoading)
                                const _LoadingState()
                              else if (notifState.error != null)
                                _ErrorState(
                                  message: notifState.error!,
                                  onRetry: notifier.loadNotifications,
                                )
                              else if (notifState.notifications.isEmpty)
                                const _EmptyState()
                              else
                                Column(
                                  children: notifState.notifications.map((n) {
                                    switch (n.type) {
                                      case NotificationType.order:
                                        return NotificationTileOrder(
                                          notification: n,
                                          onMarkRead: () =>
                                              notifier.markRead(n.id),
                                        );
                                      case NotificationType.promotion:
                                      default:
                                        // Staff-only types (lowStock, newFeedback, etc.)
                                        // shouldn't normally reach a customer's feed,
                                        // but fall back to the offer tile rather than
                                        // crashing if they ever do.
                                        return NotificationTileOffer(
                                          notification: n,
                                          onMarkRead: () =>
                                              notifier.markRead(n.id),
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

// ─── Page header ───────────────────────────────────────────────────────────────

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
          'Manage your order status and member exclusives.',
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

// ─── States ────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator(color: Colors.black)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFCFC4C5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF656464),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
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