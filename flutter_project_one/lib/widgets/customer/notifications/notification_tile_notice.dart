// lib/widgets/customer/notifications/notification_tile_notice.dart

import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../screens/customer/messages/customer_chat_screen.dart';

/// Notification card for [NotificationType.accountWarning] — a warning or
/// suspension notice about the customer's own account.
///
/// There is no "account status" page in the app, so the one useful next step
/// is to talk to support: the whole card, and its CONTACT SUPPORT button, open
/// the support chat.
class NotificationTileNotice extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const NotificationTileNotice({
    super.key,
    required this.notification,
    required this.onMarkRead,
  });

  @override
  State<NotificationTileNotice> createState() => _NotificationTileNoticeState();
}

class _NotificationTileNoticeState extends State<NotificationTileNotice> {
  // True while the chat is open, so a double tap can't stack two chats.
  bool _opening = false;

  Future<void> _openChat() async {
    if (_opening) return;
    _opening = true;

    widget.onMarkRead();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerChatScreen()),
    );

    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final AppNotification notification = widget.notification;

    return GestureDetector(
      onTap: _openChat,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCFC4C5), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ────────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 24,
                color: Colors.black,
              ),
            ),

            const SizedBox(width: 16),

            // ── Content ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACCOUNT NOTICE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF656464),
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
                      fontSize: 18,
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

                  GestureDetector(
                    onTap: _openChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: const Text(
                        'CONTACT SUPPORT',
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
            ),
          ],
        ),
      ),
    );
  }
}