import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/chat_message_model.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Upload a chat image to the shared product-images bucket ────
  // Reuses the same bucket inventory already uses, under its own
  // "chat/" folder so the two don't mix. Returns the public URL, or
  // null if the upload failed (caller should show a friendly error
  // and NOT send a message with a broken image link).
  Future<String?> uploadChatImage({
    required String conversationId,
    required PlatformFile file,
  }) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = 'chat/$conversationId/${timestamp}_${file.name}';

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        print('uploadChatImage: no bytes and no path for ${file.name} — cannot upload');
        return null;
      }

      await _client.storage.from('product-images').uploadBinary(filePath, bytes);
      return _client.storage.from('product-images').getPublicUrl(filePath);
    } catch (error) {
      print('uploadChatImage error: $error');
      return null;
    }
  }

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
 // ── Send a message ─────────────────────────────────────────────
  // text can be empty ONLY if imageUrl and/or productId is set — the
  // caller is responsible for that check before calling this (see
  // chat_provider.dart sendMessage). message_text is NOT NULL in the
  // DB, so an image-only message still inserts '' rather than null.
Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String text,
    String? imageUrl,
    String? productId,
  }) async {
    print('📨 sendMessage called with senderRole="$senderRole"');
    await _client.from('messages').insert({
      'conversation_id': int.parse(conversationId),
      'sender_id':       senderId,
      'sender_role':     senderRole,
      'message_text':    text,
      'is_read':         false,
      'image_url':       imageUrl,
      'product_id':      productId == null ? null : int.parse(productId),
    });

   // Notify staff when the CUSTOMER sends a message, and notify the
    // customer when an ADMIN (or cashier/super admin) replies.
    if (senderRole.toLowerCase() == 'customer') {
      await _notifyStaffNewMessage(
        conversationId: conversationId,
        customerId: senderId,
        text: text,
        imageUrl: imageUrl,
        productId: productId,
      );
    } else {
      await _notifyCustomerAdminReply(
        conversationId: conversationId,
        text: text,
        imageUrl: imageUrl,
        productId: productId,
      );
    }
  }

  // ================================================
  // NOTIFY CUSTOMER — ADMIN REPLIED
  // Recipient: the customer who owns this conversation.
  // ================================================
Future<void> _notifyCustomerAdminReply({
    required String conversationId,
    required String text,
    String? imageUrl,
    String? productId,
  }) async {
    print('🔔🔔🔔 _notifyCustomerAdminReply CALLED 🔔🔔🔔');
    try {
      await _client.rpc('notify_customer_admin_reply', params: {
        'p_conversation_id': int.parse(conversationId),
        'p_text': text,
        'p_image_url': imageUrl,
        'p_product_id': productId == null ? null : int.parse(productId),
      });
      print('🔔 RPC completed successfully');
    } catch (error) {
      print('_notifyCustomerAdminReply error: $error');
    }
  }

  // ── Builds a readable preview even when text is empty (image-only
  // or product-only messages) so notifications never show a blank
  // body. Priority: real text > image > product > generic fallback.
  String _buildPreview(String text, String? imageUrl, String? productId) {
    final String trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.length > 60 ? '${trimmed.substring(0, 60)}...' : trimmed;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) return '📷 Sent a photo';
    if (productId != null) return '🔗 Shared a product';
    return 'Sent a message';
  }
  // ================================================
  // NOTIFY STAFF — NEW MESSAGE
  // Recipient: Admin only (Super Admin has no chat screen).
  // ================================================
Future<void> _notifyStaffNewMessage({
    required String conversationId,
    required String customerId,
    required String text,
    String? imageUrl,
    String? productId,
  }) async {
    print('🔔🔔🔔 _notifyStaffNewMessage CALLED 🔔🔔🔔');
    try {
      // Single round trip — the DB does the name lookup, staff lookup,
      // and inserts in one atomic call, so a fast account switch on the
      // client can no longer cut it off mid-flight.
      await _client.rpc('notify_staff_new_message', params: {
        'p_customer_id': customerId,
        'p_text': text,
        'p_image_url': imageUrl,
        'p_product_id': productId == null ? null : int.parse(productId),
      });
      print('🔔 RPC completed successfully');
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