// lib/services/customer/chat/chat_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/chat_message_model.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Get or create the single conversation for current customer ─
  Future<Conversation?> getOrCreateConversation() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Check for existing open conversation
    final existing = await _client
        .from('conversations')
        .select()
        .eq('customer_id', userId)
        .eq('status', 'open')
        .maybeSingle();

    if (existing != null) {
      return Conversation.fromMap(existing as Map<String, dynamic>);
    }

    // Create new conversation
    final created = await _client
        .from('conversations')
        .insert({'customer_id': userId, 'status': 'open'})
        .select()
        .single();

    return Conversation.fromMap(created as Map<String, dynamic>);
  }

  // ── Fetch messages for a conversation ─────────────────────────
  Future<List<Message>> fetchMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', int.parse(conversationId))
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Message.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Send a message ─────────────────────────────────────────────
// ── Send a message ─────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    await _client.from('messages').insert({
      'conversation_id': int.parse(conversationId),
      'sender_id':       senderId,
      'sender_role':     senderRole,
      'message_text':    text,
      'is_read':         false,
    });

   // Only notify staff when the CUSTOMER sends a message — not when
    // an admin replies in their own conversation.
    if (senderRole.toLowerCase() == 'customer') {
      await _notifyStaffNewMessage(
        conversationId: conversationId,
        customerId: senderId,
        text: text,
      );
    }
  }

  // ================================================
  // NOTIFY STAFF — NEW MESSAGE
  // Recipient: Admin only (Super Admin has no chat screen).
  // ================================================
  Future<void> _notifyStaffNewMessage({
    required String conversationId,
    required String customerId,
    required String text,
  }) async {
    try {
      String customerName = 'A customer';
      try {
        final row = await _client
            .from('users')
            .select('first_name, last_name')
            .eq('id', customerId)
            .single();
        final firstName = row['first_name']?.toString() ?? '';
        final lastName = row['last_name']?.toString() ?? '';
        final full = '$firstName $lastName'.trim();
        if (full.isNotEmpty) customerName = full;
      } catch (_) {
        // fall back to the generic label above
      }

      final preview = text.trim().length > 60
          ? '${text.trim().substring(0, 60)}...'
          : text.trim();

      final staff = await _client
          .from('users')
          .select('id')
          .eq('role', 'Admin');

      if ((staff as List).isEmpty) return;

      final rows = staff.map((u) => {
            'customer_id': u['id'],
            'type': 'new_message',
            'title': 'New message from $customerName',
            'body': preview,
          }).toList();

      await _client.from('notifications').insert(rows); // NO .select() !
    } catch (error) {
      print('_notifyStaffNewMessage error: $error');
    }
  }

  // ── Subscribe to new messages in a conversation (Realtime) ─────
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message message) onMessage,
  ) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'messages',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq, // ✅ fixed from FilterType.eq
            column: 'conversation_id',
            value:  int.parse(conversationId),
          ),
          callback: (payload) {
            final msg = Message.fromMap(
              payload.newRecord as Map<String, dynamic>,
            );
            onMessage(msg);
          },
        )
        .subscribe();
  }

  // ── Admin: fetch all conversations ────────────────────────────
  Future<List<Conversation>> fetchAllConversations() async {
    final response = await _client
        .from('conversations')
        .select('*, users(first_name, last_name)')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => Conversation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ── Admin: subscribe to new conversations ─────────────────────
  RealtimeChannel subscribeToConversations(
    void Function() onNewConversation,
  ) {
    return _client
        .channel('conversations:all')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'conversations',
          callback: (_) => onNewConversation(),
        )
        .subscribe();
  }

  // ── Mark all messages in a conversation as read ───────────────
  Future<void> markConversationRead(String conversationId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', int.parse(conversationId))
        .eq('is_read', false);
  }

  // ── Count unread messages for a conversation ──────────────────
  Future<int> unreadCount(String conversationId) async {
    final response = await _client
        .from('messages')
        .select('message_id')
        .eq('conversation_id', int.parse(conversationId))
        .eq('is_read', false);

    return (response as List).length;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}