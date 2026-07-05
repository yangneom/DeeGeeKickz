// lib/models/chat_model.dart
//
// Maps to Supabase `conversations` and `messages` tables.

// ─── Conversation ──────────────────────────────────────────────────────────────

enum ConversationStatus { open, closed }

class Conversation {
  final String id;             // conversation_id as string
  final String customerId;     // uuid
  final String customerName;   // joined from users table
  final ConversationStatus status;
  final DateTime createdAt;
  final Message? lastMessage;  // latest message, optional join
  final int unreadCount;       // count of is_read=false for admin view

  const Conversation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    // customerName is a joined field — admin list query joins users
    final userMap = map['users'] as Map<String, dynamic>?;
    final firstName = userMap?['first_name'] as String? ?? '';
    final lastName  = userMap?['last_name']  as String? ?? '';
    final name = '$firstName $lastName'.trim();

    return Conversation(
      id:           map['conversation_id'].toString(),
      customerId:   map['customer_id'] as String,
      customerName: name.isEmpty ? 'Customer' : name,
      status:       map['status'] == 'closed'
                        ? ConversationStatus.closed
                        : ConversationStatus.open,
      createdAt:    DateTime.parse(map['created_at'] as String),
    );
  }

  Conversation copyWith({
    Message? lastMessage,
    int? unreadCount,
    ConversationStatus? status,
  }) {
    return Conversation(
      id:           id,
      customerId:   customerId,
      customerName: customerName,
      status:       status ?? this.status,
      createdAt:    createdAt,
      lastMessage:  lastMessage ?? this.lastMessage,
      unreadCount:  unreadCount ?? this.unreadCount,
    );
  }
}

// ─── Message ───────────────────────────────────────────────────────────────────

enum SenderRole { customer, admin, cashier, superAdmin }

class Message {
  final String id;               // message_id as string
  final String conversationId;
  final String senderId;         // uuid
  final SenderRole senderRole;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  bool get isFromCustomer => senderRole == SenderRole.customer;

  // ── Time display ──────────────────────────────────────────────
  String get formattedTime {
    final h = createdAt.hour;
    final m = createdAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour   = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['sender_role'] as String).toLowerCase();
    final role = roleStr == 'customer'
        ? SenderRole.customer
        : roleStr == 'cashier'
            ? SenderRole.cashier
            : roleStr == 'super admin'
                ? SenderRole.superAdmin
                : SenderRole.admin;

    return Message(
      id:             map['message_id'].toString(),
      conversationId: map['conversation_id'].toString(),
      senderId:       map['sender_id'] as String,
      senderRole:     role,
      text:           map['message_text'] as String,
      isRead:         map['is_read'] as bool? ?? false,
      createdAt:      DateTime.parse(map['created_at'] as String),
    );
  }
}