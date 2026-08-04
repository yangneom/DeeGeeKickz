import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../models/chat_message_model.dart';
import '../../services/customer/chat/chat_service.dart';

// ── Service provider ───────────────────────────────────────────────────────────
// ── Service provider ───────────────────────────────────────────────────────────
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// ── Pending product attachment ──────────────────────────────────────────────
// Set when the customer taps "Ask about this item" on Product Detail.
// The chat screen reads this, shows an attached chip above the input,
// and clears it once the message is actually sent (or dismissed).
// ── Pending product attachment ──────────────────────────────────────────────
// Set when the customer taps "Ask about this item" on Product Detail.
// The chat screen reads this, shows an attached chip above the input,
// and clears it once the message is actually sent (or dismissed).
class PendingChatProduct {
  final String productId;
  final String productName;
  const PendingChatProduct({required this.productId, required this.productName});
}

class PendingChatProductNotifier extends Notifier<PendingChatProduct?> {
  @override
  PendingChatProduct? build() => null;

  void set(PendingChatProduct product) => state = product;
  void clear() => state = null;
}

final pendingChatProductProvider =
    NotifierProvider<PendingChatProductNotifier, PendingChatProduct?>(
  PendingChatProductNotifier.new,
);

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER CHAT PROVIDER
// Manages ONE active conversation for the logged-in customer.
// ══════════════════════════════════════════════════════════════════════════════

class CustomerChatState {
  final Conversation? conversation;
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const CustomerChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  CustomerChatState copyWith({
    Conversation? conversation,
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return CustomerChatState(
      conversation: conversation ?? this.conversation,
      messages:     messages     ?? this.messages,
      isLoading:    isLoading    ?? this.isLoading,
      error:        error,
    );
  }
}

class CustomerChatNotifier extends Notifier<CustomerChatState> {
  RealtimeChannel? _channel;
  // Created directly, not via ref — ChatService has no dependencies
  // of its own (it just uses Supabase.instance.client internally),
  // so there's no need to route it through the provider system, and
  // this sidesteps ref-safety issues entirely (safe to use even
  // during onDispose, since it never touches ref).
  final ChatService _service = ChatService();

  @override
  CustomerChatState build() {
    ref.onDispose(_cancelSubscription);
    Future.microtask(initConversation);
    return const CustomerChatState(isLoading: true);
  }

  // ── Init: get/create conversation then load messages ──────────
  Future<void> initConversation() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversation = await _service.getOrCreateConversation();
      if (conversation == null) {
        state = state.copyWith(isLoading: false, error: 'Not logged in.');
        return;
      }
      final messages = await _service.fetchMessages(conversation.id);
      state = state.copyWith(
        conversation: conversation,
        messages:     messages,
        isLoading:    false,
      );
      _subscribeRealtime(conversation.id);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load chat.',
      );
    }
  }

// ── Send message ──────────────────────────────────────────────
  // text may be empty ONLY if imageUrl or productId is provided —
  // an entirely empty message (no text, no image, no product) is
  // rejected here so the UI can't send nothing.
  Future<void> sendMessage(
    String text, {
    String? imageUrl,
    String? productId,
  }) async {
    final user         = Supabase.instance.client.auth.currentUser;
    final conversation = state.conversation;
    if (user == null || conversation == null) return;

    final String trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null && productId == null) return;

    // Optimistic add
    final optimistic = Message(
      id:             'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversation.id,
      senderId:       user.id,
      senderRole:     SenderRole.customer,
      text:           trimmed,
      isRead:         false,
      createdAt:      DateTime.now(),
      imageUrl:       imageUrl,
      productId:      productId,
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      await _service.sendMessage(
        conversationId: conversation.id,
        senderId:       user.id,
        senderRole:     'Customer',
        text:           trimmed,
        imageUrl:       imageUrl,
        productId:      productId,
      );
    } catch (_) {
      // Remove optimistic message on failure
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.id != optimistic.id)
            .toList(),
      );
    }
  }

  // ── Send an image (picks + uploads, then sends the message) ────
  // Returns false if upload failed, so the UI can show an error
  // snackbar instead of silently doing nothing.
  Future<bool> sendImage(PlatformFile file, {String? caption}) async {
    final conversation = state.conversation;
    if (conversation == null) return false;

    final String? url = await _service.uploadChatImage(
      conversationId: conversation.id,
      file:           file,
    );
    if (url == null) return false;

    await sendMessage(caption ?? '', imageUrl: url);
    return true;
  }
  // ── Realtime ──────────────────────────────────────────────────
  void _subscribeRealtime(String conversationId) {
    _channel = _service.subscribeToMessages(conversationId, (msg) {
      // Avoid duplicates from optimistic updates
      final alreadyPresent = state.messages.any((m) => m.id == msg.id);
      if (!alreadyPresent) {
        // Also remove any matching optimistic temp message
        final withoutOptimistic = state.messages
            .where((m) => !m.id.startsWith('temp_'))
            .toList();
        state = state.copyWith(messages: [...withoutOptimistic, msg]);
      }
    });
  }

  void _cancelSubscription() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
    }
  }
}

final customerChatProvider =
    NotifierProvider<CustomerChatNotifier, CustomerChatState>(() {
  return CustomerChatNotifier();
});

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN CHAT PROVIDER
// Manages the full list of customer conversations for admin/cashier.
// ══════════════════════════════════════════════════════════════════════════════

class AdminChatState {
  final List<Conversation> conversations;
  final String? selectedConversationId;
  final List<Message> messages;
  final bool isLoading;
  final bool isMessagesLoading;
  final String? error;

  // Per-conversation unread counts
  final Map<String, int> unreadCounts;

  const AdminChatState({
    this.conversations          = const [],
    this.selectedConversationId,
    this.messages               = const [],
    this.isLoading              = false,
    this.isMessagesLoading      = false,
    this.error,
    this.unreadCounts           = const {},
  });

  Conversation? get selectedConversation => conversations
      .where((c) => c.id == selectedConversationId)
      .firstOrNull;

  AdminChatState copyWith({
    List<Conversation>? conversations,
    String? selectedConversationId,
    List<Message>? messages,
    bool? isLoading,
    bool? isMessagesLoading,
    String? error,
    Map<String, int>? unreadCounts,
  }) {
    return AdminChatState(
      conversations:            conversations          ?? this.conversations,
      selectedConversationId:   selectedConversationId ?? this.selectedConversationId,
      messages:                 messages               ?? this.messages,
      isLoading:                isLoading              ?? this.isLoading,
      isMessagesLoading:        isMessagesLoading      ?? this.isMessagesLoading,
      error:                    error,
      unreadCounts:             unreadCounts           ?? this.unreadCounts,
    );
  }
}

class AdminChatNotifier extends Notifier<AdminChatState> {
  RealtimeChannel? _conversationChannel;
  RealtimeChannel? _messageChannel;
  final ChatService _service = ChatService();

  @override
  AdminChatState build() {
    ref.onDispose(_cancelSubscriptions);
    Future.microtask(loadConversations);
    return const AdminChatState(isLoading: true);
  }

  // ── Load all conversations ────────────────────────────────────
  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _service.fetchAllConversations();

      // Load unread counts in parallel
      final counts = await Future.wait(
        conversations.map((c) => _service.unreadCount(c.id)),
      );
      final unreadMap = {
        for (var i = 0; i < conversations.length; i++)
          conversations[i].id: counts[i],
      };

      state = state.copyWith(
        conversations: conversations,
        isLoading:     false,
        unreadCounts:  unreadMap,
      );

      // Auto-select first
      if (conversations.isNotEmpty && state.selectedConversationId == null) {
        selectConversation(conversations.first.id);
      }

      _subscribeConversations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load chats.');
    }
  }

  // ── Select a conversation ─────────────────────────────────────
  Future<void> selectConversation(String conversationId) async {
    state = state.copyWith(
      selectedConversationId: conversationId,
      isMessagesLoading:      true,
    );

    // Cancel previous message subscription
    if (_messageChannel != null) {
      _service.unsubscribe(_messageChannel!);
    }

    try {
      final messages = await _service.fetchMessages(conversationId);
      await _service.markConversationRead(conversationId);

      state = state.copyWith(
        messages:          messages,
        isMessagesLoading: false,
        unreadCounts: {
          ...state.unreadCounts,
          conversationId: 0,
        },
      );

      _subscribeMessages(conversationId);
    } catch (_) {
      state = state.copyWith(isMessagesLoading: false);
    }
  }

// ── Admin sends a message ─────────────────────────────────────
  Future<void> sendMessage(
    String text, {
    String? imageUrl,
    String? productId,
  }) async {
    final user         = Supabase.instance.client.auth.currentUser;
    final conversation = state.selectedConversation;
    if (user == null || conversation == null) return;

    final String trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null && productId == null) return;

    // Optimistic add
    final optimistic = Message(
      id:             'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversation.id,
      senderId:       user.id,
      senderRole:     SenderRole.admin,
      text:           trimmed,
      isRead:         false,
      createdAt:      DateTime.now(),
      imageUrl:       imageUrl,
      productId:      productId,
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      await _service.sendMessage(
        conversationId: conversation.id,
        senderId:       user.id,
        senderRole:     'Admin',
        text:           trimmed,
        imageUrl:       imageUrl,
        productId:      productId,
      );
    } catch (_) {
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.id != optimistic.id)
            .toList(),
      );
    }
  }

  // ── Admin sends an image ────────────────────────────────────────
  Future<bool> sendImage(PlatformFile file, {String? caption}) async {
    final conversation = state.selectedConversation;
    if (conversation == null) return false;

    final String? url = await _service.uploadChatImage(
      conversationId: conversation.id,
      file:           file,
    );
    if (url == null) return false;

    await sendMessage(caption ?? '', imageUrl: url);
    return true;
  }

  // ── Realtime: new conversations ────────────────────────────────
  void _subscribeConversations() {
    _conversationChannel = _service.subscribeToConversations(() {
      loadConversations();
    });
  }

  // ── Realtime: new messages in selected conversation ────────────
  void _subscribeMessages(String conversationId) {
    _messageChannel = _service.subscribeToMessages(conversationId, (msg) {
      final alreadyPresent = state.messages.any((m) => m.id == msg.id);
      if (!alreadyPresent) {
        final withoutOptimistic = state.messages
            .where((m) => !m.id.startsWith('temp_'))
            .toList();
        state = state.copyWith(messages: [...withoutOptimistic, msg]);
        // Mark read immediately since this conversation is open
        _service.markConversationRead(conversationId);
      }
    });
  }

  void _cancelSubscriptions() {
    if (_conversationChannel != null) _service.unsubscribe(_conversationChannel!);
    if (_messageChannel      != null) _service.unsubscribe(_messageChannel!);
  }
}

final adminChatProvider =
    NotifierProvider<AdminChatNotifier, AdminChatState>(() {
  return AdminChatNotifier();
});


