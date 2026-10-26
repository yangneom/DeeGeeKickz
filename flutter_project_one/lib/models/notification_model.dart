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
  newArrival,
}

class AppNotification {
  final String id;          // notification_id as string
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? orderId;      // nullable — only set for order notifications
  final String? referenceId;  // generic reference (size_id, feedback_id, conversation_id — depends on type)

  // The type exactly as it is stored in the database ("account_warning",
  // "discount", ...). The NotificationType list above is shared with the staff
  // screens, which list every type, so adding a type there stops them
  // compiling. A customer-only notice such as an account warning is
  // recognised from this text instead.
  final String? rawType;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.orderId,
    this.referenceId,
    this.rawType,
  });

  bool get isUnread => !isRead;

  // A warning or suspension notice about the customer's own account.
  bool get isAccountWarning => rawType == 'account_warning';

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
      type: _typeFromString(map['type'] as String?),
      title:     map['title'] as String,
      body:      map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead:    map['is_read'] as bool? ?? false,
      orderId:      map['order_id']?.toString(),
      referenceId:  map['reference_id']?.toString(),
      rawType:      map['type'] as String?,
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
      case 'new_arrival':        return NotificationType.newArrival;
      default:                   return NotificationType.promotion;
    }
  }

  // ── copyWith ───────────────────────────────────────────────────
  // FIX: this used to rebuild the notification WITHOUT its referenceId.
  // Marking a notification read (one tap, or "Mark all as read") therefore
  // erased the link it carried, so a review-reply notification opened the
  // review the first time and then said "too old to link directly" every
  // time after.
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id:          id,
      type:        type,
      title:       title,
      body:        body,
      createdAt:   createdAt,
      isRead:      isRead ?? this.isRead,
      orderId:     orderId,
      referenceId: referenceId,
      rawType:     rawType,
    );
  }
}