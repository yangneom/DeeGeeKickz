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

  // NEW — joined from users table, same pattern as customerName.
  // Used for the customer info panel and the suspended-conversation
  // badge — previously nothing here knew whether the customer this
  // conversation belongs to was suspended/banned at all.
  final String customerEmail;
  final String customerPhone;
  final bool isCustomerSuspended;
  final int customerBanTier;
  final DateTime? customerLastActiveAt;

  const Conversation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.customerEmail = '',
    this.customerPhone = '',
    this.isCustomerSuspended = false,
    this.customerBanTier = 0,
    this.customerLastActiveAt,
  });

  // Same 5-minute-window definition already used for CustomerAccount
  // in Customer Management, kept consistent across both screens.
  bool get isCustomerOnline {
    if (customerLastActiveAt == null) return false;
    return DateTime.now().difference(customerLastActiveAt!) <= const Duration(minutes: 5);
  }

  String get customerBanTierLabel {
    switch (customerBanTier) {
      case 1:
        return 'Warned (Tier 1)';
      case 2:
        return 'Suspended 24h (Tier 2)';
      case 3:
        return 'Suspended 7 days (Tier 3)';
      default:
        return customerBanTier >= 4 ? 'Permanently Banned (Tier $customerBanTier)' : 'No violations';
    }
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    // customerName is a joined field — admin list query joins users
    final userMap = map['users'] as Map<String, dynamic>?;
    final firstName = userMap?['first_name'] as String? ?? '';
    final lastName  = userMap?['last_name']  as String? ?? '';
    final name = '$firstName $lastName'.trim();

    final String? lastActiveRaw = userMap?['last_active_at'] as String?;

    return Conversation(
      id:           map['conversation_id'].toString(),
      customerId:   map['customer_id'] as String,
      customerName: name.isEmpty ? 'Customer' : name,
      status:       map['status'] == 'closed'
                        ? ConversationStatus.closed
                        : ConversationStatus.open,
      createdAt:    DateTime.parse(map['created_at'] as String),
      customerEmail: userMap?['email'] as String? ?? '',
      customerPhone: userMap?['phone'] as String? ?? '',
      isCustomerSuspended: userMap?['is_disabled'] == true,
      customerBanTier: (userMap?['ban_tier'] as num?)?.toInt() ?? 0,
      customerLastActiveAt: lastActiveRaw != null ? DateTime.tryParse(lastActiveRaw) : null,
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
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      isCustomerSuspended: isCustomerSuspended,
      customerBanTier: customerBanTier,
      customerLastActiveAt: customerLastActiveAt,
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
  final String? imageUrl;
  final String? productId;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.isRead,
    required this.createdAt,
    this.imageUrl,
    this.productId,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasProductRef => productId != null;

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
      // FIX: created_at is stored UTC by Supabase — .toLocal() converts
      // it to the device's local timezone before formattedTime reads
      // .hour/.minute off it. Without this, every timestamp shown was
      // off by the local UTC offset (e.g. PH time was 8 hours behind).
      createdAt:      DateTime.parse(map['created_at'] as String).toLocal(),
      imageUrl:       map['image_url'] as String?,
      productId:      map['product_id']?.toString(),
    );
  }
}