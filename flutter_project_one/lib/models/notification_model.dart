// lib/models/notification_model.dart
//
// Maps 1-to-1 with the Supabase `notifications` table.
// Drop-alert type has been removed from the product scope.

enum NotificationType {
  order,
  promotion,
  lowStock,
  outOfStock,
  newFeedback,
  newMessage,
  orderCancellation,
  adminActivity,
  salesAlert,
  adminReply,
}
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
// ── Factory: from Supabase row ─────────────────────────────────
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['notification_id'].toString(),
      type: _typeFromString(map['type'] as String?),
      title:     map['title'] as String,
      body:      map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead:    map['is_read'] as bool? ?? false,
      orderId:   map['order_id']?.toString(),
    );
  }

  static NotificationType _typeFromString(String? raw) {
    switch (raw) {
      case 'order':              return NotificationType.order;
      case 'discount':           return NotificationType.promotion;
      case 'promotion':          return NotificationType.promotion; // legacy — old rows before the rename
      case 'low_stock':          return NotificationType.lowStock;
      case 'out_of_stock':       return NotificationType.outOfStock;
      case 'new_feedback':       return NotificationType.newFeedback;
      case 'new_message':        return NotificationType.newMessage;
      case 'order_cancellation': return NotificationType.orderCancellation;
      case 'admin_activity':     return NotificationType.adminActivity;
      case 'sales_alert':        return NotificationType.salesAlert;
      case 'admin_reply':        return NotificationType.adminReply;
      default:                   return NotificationType.promotion;
    }
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