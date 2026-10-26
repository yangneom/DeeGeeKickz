import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/customer/chat_provider.dart';
import '../../../providers/customer/chat_provider.dart' show pendingChatProductProvider, PendingChatProduct;
import '../../../providers/product/product_provider.dart';
import '../../../models/chat_message_model.dart';
import '../../../models/product.dart' as db_product;
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../widgets/common/dialog/app_toast.dart';
import '../../../widgets/common/chat/chat_image.dart';

// The conversation column never gets wider than this, so on a large screen
// the messages and the composer stay easy to read instead of stretching
// across the whole window.
const double _kChatMaxWidth = 880;

// Same photo rules the chat service enforces (it checks again on upload).
const int _kMaxPhotoBytes = 10 * 1024 * 1024;
const Set<String> _kPhotoTypes = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

const int _kMaxMessageLength = 1000;

class CustomerChatScreen extends ConsumerStatefulWidget {
  const CustomerChatScreen({super.key});

  @override
  ConsumerState<CustomerChatScreen> createState() =>
      _CustomerChatScreenState();
}

class _CustomerChatScreenState extends ConsumerState<CustomerChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  bool _isUploadingImage = false;
  // True while a message is being saved, so a double tap or a second Enter
  // cannot send it twice.
  bool _isSending = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
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

  Future<void> _onSend() async {
    if (_isSending) return;

    final String text = _inputController.text.trim();
    final pending = ref.read(pendingChatProductProvider);

    if (text.isEmpty && pending == null) return;

    setState(() => _isSending = true);
    _inputController.clear();

    final bool sent = await ref.read(customerChatProvider.notifier).sendMessage(
          text,
          productId: pending?.productId,
        );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (sent) {
      if (pending != null) {
        ref.read(pendingChatProductProvider.notifier).clear();
      }
      _scrollToBottom();
    } else {
      // Put the text back so nothing the customer typed is lost.
      _inputController.text = text;
      _inputController.selection =
          TextSelection.collapsed(offset: text.length);
      AppToast.error(
        context,
        'Your message was not sent. Please check your connection and try again.',
        title: 'Message not sent',
      );
    }
  }

  // Returns a reason if the photo can't be sent, or null if it is fine.
  String? _photoProblem(PlatformFile file) {
    final String extension =
        (file.extension ?? file.name.split('.').last).toLowerCase();
    if (!_kPhotoTypes.contains(extension)) {
      return 'Photos must be JPG, PNG, WebP or GIF.';
    }
    if (file.size > _kMaxPhotoBytes) {
      return 'Photos must be 10 MB or smaller.';
    }
    return null;
  }

  Future<void> _onPickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // forces bytes on web — path is always null there
      );
      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;
      final String? problem = _photoProblem(file);
      if (problem != null) {
        if (mounted) {
          AppToast.warning(context, problem, title: 'Photo not sent');
        }
        return;
      }

      setState(() => _isUploadingImage = true);

      final bool success =
          await ref.read(customerChatProvider.notifier).sendImage(file);

      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (!success) {
          AppToast.error(
            context,
            'We could not send your image. Please try again.',
            title: 'Image not sent',
          );
        } else {
          _scrollToBottom();
        }
      }
    } catch (error) {
      print('_onPickImage error: $error');
      if (mounted) {
        setState(() => _isUploadingImage = false);
        AppToast.error(
          context,
          'We could not open your photos. Please try again.',
          title: 'Image not selected',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(customerChatProvider);
    final pendingProduct = ref.watch(pendingChatProductProvider);
    // Scroll to bottom whenever messages change
    ref.listen(customerChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    final bool isWide = MediaQuery.of(context).size.width > _kChatMaxWidth + 48;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'chat'),

            // The conversation: header, messages, composer. Centered and
            // capped in width on large screens.
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      // A thin edge on each side only when there is room
                      // around the column to frame it.
                      border: isWide
                          ? const Border.symmetric(
                              vertical: BorderSide(color: Color(0xFFE2E2E2)),
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        // ── Support header ──────────────────────────────
                        const _SupportHeader(),

                        // ── Messages ────────────────────────────────────
                        Expanded(child: _buildBody(chatState)),

                        // ── Attached product chip ───────────────────────
                        if (pendingProduct != null)
                          _AttachedProductChip(
                            productName: pendingProduct.productName,
                            onRemove: () => ref
                                .read(pendingChatProductProvider.notifier)
                                .clear(),
                          ),

                        // ── Input bar ───────────────────────────────────
                        _ChatInputBar(
                          controller: _inputController,
                          onSend: _onSend,
                          onPickImage: _onPickImage,
                          isUploadingImage: _isUploadingImage,
                          isSending: _isSending,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildBody(CustomerChatState chatState) {
    if (chatState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (chatState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFCFC4C5)),
              const SizedBox(height: 12),
              Text(
                chatState.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF656464),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    ref.read(customerChatProvider.notifier).initConversation(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chatState.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 40, color: Color(0xFFCFC4C5)),
              SizedBox(height: 12),
              Text(
                'Send a message to start chatting with support.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF656464),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final List<Message> messages = chatState.messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final Message message = messages[index];
        // A date label above the first message of each day, instead of a
        // permanent "TODAY" that was wrong for older conversations.
        final bool showDate = index == 0 ||
            !_isSameDay(messages[index - 1].createdAt, message.createdAt);

        return Column(
          children: [
            if (showDate) _DateChip(date: message.createdAt),
            _ChatBubble(message: message),
          ],
        );
      },
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ─── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends ConsumerWidget {
  final Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomer = message.isFromCustomer;

    // On a wide screen 70% of the window is far too wide to read.
    final double maxBubbleWidth =
        math.min(MediaQuery.of(context).size.width * 0.78, 520.0);

    // Only bother looking up product data if this message actually
    // references one — avoids an unnecessary provider read otherwise.
    db_product.Product? referencedProduct;
    if (message.hasProductRef) {
      final productsAsync = ref.watch(productsProvider);
      final List<db_product.Product> products = productsAsync.value ?? [];
      referencedProduct = products.cast<db_product.Product?>().firstWhere(
            (p) => p!.productId == message.productId,
            orElse: () => null,
          );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Support avatar
          if (!isCustomer)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              color: Colors.black,
              alignment: Alignment.center,
              child: const Text(
                'DG',
                style: TextStyle(
                  fontFamily: 'Archivo Narrow',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),

          // Bubble + time
          Flexible(
            child: Column(
              crossAxisAlignment: isCustomer
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isCustomer ? Colors.black : Colors.white,
                    border: isCustomer
                        ? null
                        : Border.all(color: const Color(0xFFCFC4C5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Image, if present — click it to open it large ──
                      if (message.hasImage)
                        ChatImage(url: message.imageUrl!),

                      // ── Product reference card, if present ──
                      if (message.hasProductRef)
                        Container(
                          width: 200,
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: const Color(0xFFE2E2E2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFEEEEEE)),
                                alignment: Alignment.center,
                                clipBehavior: Clip.antiAlias,
                                child: Builder(builder: (context) {
                                  final String? thumbUrl = referencedProduct
                                              ?.variants.isNotEmpty ==
                                          true
                                      ? referencedProduct!
                                          .variants.first.primaryImageUrl
                                      : null;
                                  if (thumbUrl == null || thumbUrl.isEmpty) {
                                    return const Icon(Icons.image_outlined,
                                        size: 18, color: Color(0xFF9CA3AF));
                                  }
                                  return Image.network(
                                    thumbUrl,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                        color: Color(0xFF9CA3AF)),
                                  );
                                }),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  referencedProduct?.productName ??
                                      'Product unavailable',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Text, if present ──
                      if (message.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color:
                                  isCustomer ? Colors.white : Colors.black,
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
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attached product chip ───────────────────────────────────────────────────

class _AttachedProductChip extends StatelessWidget {
  final String productName;
  final VoidCallback onRemove;

  const _AttachedProductChip({
    required this.productName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F4),
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 16, color: Color(0xFF656464)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Asking about: $productName',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1C1C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: 'Remove',
            child: InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Color(0xFF656464)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input bar ─────────────────────────────────────────────────────────────────
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool isUploadingImage;
  final bool isSending;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.isUploadingImage,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E2E2), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attach a photo — a real button, reachable with the keyboard.
            Tooltip(
              message: 'Attach a photo',
              child: InkWell(
                onTap: isUploadingImage ? null : onPickImage,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.image_outlined,
                            size: 22,
                            color: Color(0xFF656464),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  border: Border.all(color: const Color(0xFFCFC4C5)),
                ),
                child: TextField(
                  controller: controller,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_kMaxMessageLength),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
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
            Tooltip(
              message: 'Send message',
              child: Material(
                color: isSending ? const Color(0xFF374151) : Colors.black,
                child: InkWell(
                  onTap: isSending ? null : onSend,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Support header ────────────────────────────────────────────────────────────
// The old header said "Premium Support" and "Online · Typically replies in
// minutes". The app can't know whether anyone is online or how fast they
// will reply, so those claims are gone.

class _SupportHeader extends StatelessWidget {
  const _SupportHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E2E2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            color: Colors.black,
            alignment: Alignment.center,
            child: const Text(
              'DG',
              style: TextStyle(
                fontFamily: 'Archivo Narrow',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DeeGeeKickz Support',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Color(0xFF1A1C1C),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'We\'re here to help with your orders and account.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date chip ─────────────────────────────────────────────────────────────────
// Shown above the first message of each day: "Today", "Yesterday" or the date.

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip({required this.date});

  String get _label {
    final DateTime now = DateTime.now();
    if (_isSameDay(date, now)) return 'TODAY';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    const List<String> months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: const Color(0xFFEEEEEE),
          child: Text(
            _label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Color(0xFF656464),
            ),
          ),
        ),
      ),
    );
  }
}