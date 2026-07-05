// lib/models/notification_model.dart
//
// Maps 1-to-1 with the Supabase `notifications` table.
// Drop-alert type has been removed from the product scope.

enum NotificationType { order, promotion }

class AppNotification {
  final String id;          // notification_id as string
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? orderId;    // nullable — only set for order notifications

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.orderId,
  });

  bool get isUnread => !isRead;

  // ── Time-ago helper ────────────────────────────────────────────
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays == 1)     return 'Yesterday';
    if (diff.inDays < 7)      return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  // ── Factory: from Supabase row ─────────────────────────────────
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['notification_id'].toString(),
      type: map['type'] == 'order'
          ? NotificationType.order
          : NotificationType.promotion,
      title:     map['title'] as String,
      body:      map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead:    map['is_read'] as bool? ?? false,
      orderId:   map['order_id']?.toString(),
    );
  }

  // ── copyWith ───────────────────────────────────────────────────
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id:        id,
      type:      type,
      title:     title,
      body:      body,
      createdAt: createdAt,
      isRead:    isRead ?? this.isRead,
      orderId:   orderId,
    );
  }
}