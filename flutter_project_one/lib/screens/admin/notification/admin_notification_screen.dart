import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/customer/notification_provider.dart';
import '../../../widgets/admin/notifications/staff_notification_tile.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Re-fetch every time this screen is opened — the provider only
    // loads once by default, so navigating away and back otherwise
    // shows stale data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationProvider);
    final notifier   = ref.read(notificationProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  if (notifState.unreadCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${notifState.unreadCount}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: notifier.loadNotifications,
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF6B7280)),
                    tooltip: 'Refresh',
                  ),
                  if (notifState.unreadCount > 0)
                    TextButton(
                      onPressed: notifier.markAllRead,
                      child: const Text('Mark all as read', style: TextStyle(color: Color(0xFF2563EB))),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: notifState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(notifState.error!, style: const TextStyle(color: Color(0xFF6B7280))),
                            const SizedBox(height: 12),
                            TextButton(onPressed: notifier.loadNotifications, child: const Text('Try again')),
                          ],
                        ),
                      )
                    : notifState.notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No notifications yet', style: TextStyle(color: Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: notifState.notifications.length,
                            itemBuilder: (context, i) {
                              final n = notifState.notifications[i];
                              return StaffNotificationTile(
                                notification: n,
                                onMarkRead: () => notifier.markRead(n.id),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}