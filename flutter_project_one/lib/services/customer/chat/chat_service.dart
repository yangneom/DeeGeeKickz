import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/chat_message_model.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Chat photo rules ───────────────────────────────────────────
  // Checked here as well as by the picker, because the picker only
  // filters by "image" and anyone can call the upload directly.
  static const int _maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const Map<String, String> _imageTypes = {
    'jpg':  'image/jpeg',
    'jpeg': 'image/jpeg',
    'png':  'image/png',
    'webp': 'image/webp',
    'gif':  'image/gif',
  };

  // ── Upload a chat image to the shared product-images bucket ────
  // Reuses the same bucket inventory already uses, under its own
  // "chat/" folder so the two don't mix. Returns the public URL, or
  // null if the upload failed or the file isn't an allowed photo
  // (caller should show a friendly error and NOT send a message with
  // a broken image link).
  Future<String?> uploadChatImage({
    required String conversationId,
    required PlatformFile file,
  }) async {
    try {
      final String extension =
          (file.extension ?? file.name.split('.').last).toLowerCase();
      final String? contentType = _imageTypes[extension];
      if (contentType == null) {
        return null; // not a JPG, PNG, WebP or GIF
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty || bytes.length > _maxImageBytes) {
        return null; // nothing to upload, or larger than 10 MB
      }

      // The original file name is typed by whoever owns the device, so
      // keep only plain characters — spaces, slashes and symbols can
      // make the storage path invalid.
      final String safeName =
          file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = 'chat/$conversationId/${timestamp}_$safeName';

      await _client.storage.from('product-images').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      return _client.storage.from('product-images').getPublicUrl(filePath);
    } catch (error) {
      return null;
    }
  }

  // ── Find the customer's open conversation, if any ──────────────
  // Takes the OLDEST open one instead of expecting exactly one. The
  // old maybeSingle() threw as soon as a customer had two open
  // conversations (which could happen if the chat was opened twice
  // at the same moment), and then the chat never loaded again.
  Future<Map<String, dynamic>?> _findOpenConversationRow(
    String customerId,
  ) async {
    final List<dynamic> rows = await _client
        .from('conversations')
        .select()
        .eq('customer_id', customerId)
        .eq('status', 'open')
        .order('created_at', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  // ── Get the open conversation for a customer, or create it ─────
  // Shared by the customer side and the admin side, so both behave
  // the same. If two callers try to create it at the same moment,
  // the database (one open conversation per customer) refuses the
  // second insert, and this simply loads the one that won.
  Future<Conversation> _getOrCreateFor(String customerId) async {
    final Map<String, dynamic>? existing =
        await _findOpenConversationRow(customerId);
    if (existing != null) {
      return Conversation.fromMap(existing);
    }

    try {
      final created = await _client
          .from('conversations')
          .insert({'customer_id': customerId, 'status': 'open'})
          .select()
          .single();

      return Conversation.fromMap(created as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      // 23505 = unique violation: someone else just created it.
      if (e.code == '23505') {
        final Map<String, dynamic>? again =
            await _findOpenConversationRow(customerId);
        if (again != null) {
          return Conversation.fromMap(again);
        }
      }
      rethrow;
    }
  }

  // ── Get or create the single conversation for current customer ─
  Future<Conversation?> getOrCreateConversation() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    return _getOrCreateFor(userId);
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
    try {
      await _client.rpc('notify_customer_admin_reply', params: {
        'p_conversation_id': int.parse(conversationId),
        'p_text': text,
        'p_image_url': imageUrl,
        'p_product_id': productId == null ? null : int.parse(productId),
      });
    } catch (error) {
      // Non-critical: the message itself was already sent.
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
    try {
      await _client.rpc('notify_staff_new_message', params: {
        'p_customer_id': customerId,
        'p_conversation_id': int.parse(conversationId),
        'p_text': text,
        'p_image_url': imageUrl,
        'p_product_id': productId == null ? null : int.parse(productId),
      });
    } catch (error) {
      // Non-critical: the message itself was already sent.
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
            type:   PostgresChangeFilterType.eq,
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
        .select('*, users(first_name, last_name, email, phone, is_disabled, ban_tier, last_active_at)')
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

  // ── Mark all CUSTOMER messages in a conversation as read ───────
  // Only the customer's messages need marking here — admin's own
  // sent messages don't need "read by admin" tracking, and
  // including them was exactly why unreadCount() was inflated
  // (an admin's own outgoing message sits at is_read=false forever
  // otherwise, and got miscounted as something the admin hadn't seen).
  Future<void> markConversationRead(String conversationId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', int.parse(conversationId))
        .eq('sender_role', 'Customer')
        .eq('is_read', false);
  }

  // ── Count unread messages for a conversation ──────────────────
  // Only counts messages FROM the customer that the admin hasn't
  // seen yet — previously this counted ANY unread row regardless of
  // sender, so an admin's own recently-sent message (always inserted
  // with is_read: false) could inflate the badge even though the
  // admin obviously already knows what they themselves just typed.
  Future<int> unreadCount(String conversationId) async {
    final response = await _client
        .from('messages')
        .select('message_id')
        .eq('conversation_id', int.parse(conversationId))
        .eq('sender_role', 'Customer')
        .eq('is_read', false);

    return (response as List).length;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ── Admin: fetch ALL customers, regardless of whether they have
  // a conversation yet — used so admin can search/start a chat with
  // anyone, not just people who already messaged first.
  Future<List<Map<String, dynamic>>> fetchAllCustomers() async {
    final response = await _client
        .from('users')
        .select('id, first_name, last_name')
        .eq('role', 'Customer')
        .order('first_name', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // ── Admin: get or create a conversation with a specific customer.
  // Same behavior as getOrCreateConversation() (the customer-side
  // version) but admin-initiated, keyed by an explicit customerId
  // instead of the currently logged-in user.
  Future<Conversation> getOrCreateConversationWithCustomer(
    String customerId,
  ) async {
    return _getOrCreateFor(customerId);
  }
}