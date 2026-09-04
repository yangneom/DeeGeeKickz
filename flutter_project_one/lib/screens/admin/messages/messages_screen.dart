// lib/screens/admin/messages/messages_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/customer/chat_provider.dart';
import '../../../providers/product/product_provider.dart';
import '../../../models/chat_message_model.dart';
import '../../../models/product.dart' as db_product;
import 'dart:async';

void _showCustomerInfoDialog(BuildContext context, Conversation conversation) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Info',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 16),
            _infoLine('Name', conversation.customerName),
            const SizedBox(height: 10),
            _infoLine('Email', conversation.customerEmail.isEmpty ? '-' : conversation.customerEmail),
            const SizedBox(height: 10),
            _infoLine('Phone', conversation.customerPhone.isEmpty ? '-' : conversation.customerPhone),
            const SizedBox(height: 10),
            _infoLine('Presence', conversation.isCustomerOnline ? 'Online' : 'Offline'),
            const SizedBox(height: 10),
            _infoLine(
              'Account Status',
              conversation.isCustomerSuspended ? conversation.customerBanTierLabel : 'Active',
          ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoLine(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
    ],
  );
}
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Refreshes conversation data (including customer online/suspended
  // status) every 30s while this screen is open — otherwise presence
  // shown here is frozen at whatever it was the moment Messages was
  // first opened, and never updates no matter how long you wait.
  Timer? _presenceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(adminChatProvider.notifier).loadConversations();
    });
  }

  @override
  void dispose() {
    _presenceRefreshTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

 bool _isUploadingImage = false;

  void _onSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(adminChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _onPickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingImage = true);

      final bool success = await ref
          .read(adminChatProvider.notifier)
          .sendImage(result.files.first);

      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          _scrollToBottom();
        }
      }
    } catch (error) {
      print('_onPickImage error: $error');
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(adminChatProvider);

    // Scroll when messages change
    ref.listen(adminChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: chatState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black))
          : Row(
              children: [
                // ── LEFT: Customer list ───────────────────────
                               _CustomerList(
                  conversations:          chatState.conversations,
                  allCustomers:           chatState.allCustomers,
                  selectedConversationId: chatState.selectedConversationId,
                  unreadCounts:           chatState.unreadCounts,
                  onSelect: (id) =>
                      ref.read(adminChatProvider.notifier).selectConversation(id),
                  onStartChat: (customerId, customerName) => ref
                      .read(adminChatProvider.notifier)
                      .startChatWithCustomer(customerId, customerName),
                ),

                // ── RIGHT: Chat window ────────────────────────
                Expanded(
                  child: chatState.selectedConversation == null
                      ? const Center(
                          child: Text(
                            'Select a customer to start chatting.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        )
                     : _ChatWindow(
                          conversation:    chatState.selectedConversation!,
                          messages:        chatState.messages,
                          isLoading:       chatState.isMessagesLoading,
                          scrollController: _scrollController,
                          inputController: _inputController,
                          onSend:          _onSend,
                          onPickImage:     _onPickImage,
                          isUploadingImage: _isUploadingImage,
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Customer list (left panel) ────────────────────────────────────────────────

class _CustomerList extends StatefulWidget {
  final List<Conversation> conversations;
  final List<Map<String, dynamic>> allCustomers;
  final String? selectedConversationId;
  final Map<String, int> unreadCounts;
  final void Function(String id) onSelect;
  final void Function(String customerId, String customerName) onStartChat;

  const _CustomerList({
    required this.conversations,
    required this.allCustomers,
    required this.selectedConversationId,
    required this.unreadCounts,
    required this.onSelect,
    required this.onStartChat,
  });

  @override
  State<_CustomerList> createState() => _CustomerListState();
}
class _CustomerListState extends State<_CustomerList> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final filteredConversations = widget.conversations
        .where((c) =>
            c.customerName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    // Customers who don't yet have an existing conversation —
    // matched against the same search query, so admin can find and
    // start a chat with literally anyone.
    final conversationCustomerIds =
        widget.conversations.map((c) => c.customerId).toSet();

    final customersWithoutChat = widget.allCustomers.where((u) {
      final id = u['id'] as String;
      if (conversationCustomerIds.contains(id)) return false;
      final name =
          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 16, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF374151)),
                          decoration: const InputDecoration(
                            hintText: 'Search customers...',
                            hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
                    // List — existing conversations first, then customers
          // with no conversation yet.
          Expanded(
            child: ListView(
              children: [
                ...filteredConversations.map((conv) {
                  final isSelected =
                      widget.selectedConversationId == conv.id;
                  final unread = widget.unreadCounts[conv.id] ?? 0;

                  return _ConversationListItem(
                    conversation: conv,
                    isSelected:   isSelected,
                    unreadCount:  unread,
                    onTap:        () => widget.onSelect(conv.id),
                  );
                }),

                if (customersWithoutChat.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'ALL CUSTOMERS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  ...customersWithoutChat.map((u) {
                    final id = u['id'] as String;
                    final name =
                        '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                            .trim();
                    return _NoChatCustomerItem(
                      customerName: name.isEmpty ? 'Customer' : name,
                      onTap: () => widget.onStartChat(
                        id,
                        name.isEmpty ? 'Customer' : name,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Conversation list item ─────────────────────────────────────────────────────

class _ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationListItem({
    required this.conversation,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
  });

  String _initials(String name) {
    final words = name.split(' ');
    return words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF3F4F6)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              color: const Color(0xFFEEEEEE),
              alignment: Alignment.center,
              child: Text(
                _initials(conversation.customerName),
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + status badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.customerName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.black
                          : const Color(0xFF111827),
                    ),
                  ),
                                    const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        color: conversation.status == ConversationStatus.open
                            ? Colors.black
                            : const Color(0xFFEEEEEE),
                        child: Text(
                          conversation.status == ConversationStatus.open
                              ? 'OPEN'
                              : 'CLOSED',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: conversation.status == ConversationStatus.open
                                ? Colors.white
                                : const Color(0xFF656464),
                          ),
                        ),
                      ),
                      if (conversation.isCustomerSuspended) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          color: const Color(0xFFFEE2E2),
                          child: const Text(
                            'SUSPENDED',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Unread badge
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                color: Colors.black,
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Customer with no conversation yet ──────────────────────────────────────────

class _NoChatCustomerItem extends StatelessWidget {
  final String customerName;
  final VoidCallback onTap;

  const _NoChatCustomerItem({
    required this.customerName,
    required this.onTap,
  });

  String _initials(String name) {
    final words = name.split(' ');
    return words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: Text(
                _initials(customerName),
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                customerName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            const Icon(Icons.chat_bubble_outline,
                size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ─── Chat window (right panel) ─────────────────────────────────────────────────

class _ChatWindow extends StatelessWidget {
  final Conversation conversation;
  final List<Message> messages;
  final bool isLoading;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool isUploadingImage;

  const _ChatWindow({
    required this.conversation,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
    required this.inputController,
    required this.onSend,
    required this.onPickImage,
    required this.isUploadingImage,
  });

  String _initials(String name) {
    final words = name.split(' ');
    return words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                color: const Color(0xFFEEEEEE),
                alignment: Alignment.center,
                child: Text(
                  _initials(conversation.customerName),
                  style: const TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.customerName,
                      style: const TextStyle(
                        fontFamily: 'Archivo Narrow',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                                       const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: conversation.isCustomerOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF9CA3AF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          conversation.isCustomerOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: conversation.isCustomerOnline
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                        if (conversation.isCustomerSuspended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              conversation.customerBanTierLabel,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showCustomerInfoDialog(context, conversation),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 0.5),
                  ),
                  child: const Icon(Icons.more_vert,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),

        // Messages
                Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black))
              : Container(
                  color: const Color(0xFFF9FAFB),
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet. Say hello to ${conversation.customerName}!',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: messages.length,
                          itemBuilder: (context, i) =>
                              _AdminMessageBubble(
                            message: messages[i],
                            customerName: conversation.customerName,
                          ),
                        ),
                ),
        ),

        // Input
        // Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: isUploadingImage ? null : onPickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8),
                  child: isUploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined,
                          size: 20, color: Color(0xFF6B7280)),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: inputController,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF374151)),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.black,
                  child: const Icon(Icons.send,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Admin message bubble ──────────────────────────────────────────────────────

class _AdminMessageBubble extends StatelessWidget {
  final Message message;
  final String customerName;

  const _AdminMessageBubble({
    required this.message,
    required this.customerName,
  });

  String _initials(String name) {
    final words = name.split(' ');
    return words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = !message.isFromCustomer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Customer avatar
          if (!isAdmin)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              color: const Color(0xFFEEEEEE),
              alignment: Alignment.center,
              child: Text(
                _initials(customerName),
                style: const TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),

          // Bubble + time
         // Bubble + time
          Flexible(
            child: Column(
            crossAxisAlignment:
                isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isAdmin
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isAdmin
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  border: isAdmin
                      ? null
                      : Border.all(
                          color: const Color(0xFFE5E7EB), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.hasImage)
                      Image.network(
                        message.imageUrl!,
                        width: 240,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 240,
                            height: 160,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 240,
                          height: 100,
                          color: const Color(0xFFEEEEEE),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    if (message.hasProductRef)
                      _AdminProductRefCard(
                        productId: message.productId!,
                        isAdmin: isAdmin,
                      ),
                    if (message.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: isAdmin
                                ? Colors.white
                                : const Color(0xFF111827),
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          
              const SizedBox(height: 4),
              Text(
                message.formattedTime,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          )),

          // Admin avatar
          // Admin avatar
          // Admin avatar
          if (isAdmin)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 8),
              color: Colors.black,
              alignment: Alignment.center,
              child: const Text(
                'A',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminProductRefCard extends ConsumerWidget {
  final String productId;
  final bool isAdmin;

  const _AdminProductRefCard({
    required this.productId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final List<db_product.Product> products = productsAsync.value ?? [];
    final db_product.Product? product = products.cast<db_product.Product?>().firstWhere(
          (p) => p!.productId == productId,
          orElse: () => null,
        );

    return Container(
      width: 190,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: Builder(builder: (context) {
              final String? thumbUrl =
                  product?.variants.isNotEmpty == true
                      ? product!.variants.first.primaryImageUrl
                      : null;
              if (thumbUrl == null || thumbUrl.isEmpty) {
                return const Icon(Icons.image_outlined,
                    size: 16, color: Color(0xFF9CA3AF));
              }
              return Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: Color(0xFF9CA3AF)),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product?.productName ?? 'Product unavailable',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAdmin ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}