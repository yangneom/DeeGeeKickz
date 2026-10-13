import 'package:flutter/material.dart';
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

class CustomerChatScreen extends ConsumerStatefulWidget {
  const CustomerChatScreen({super.key});

  @override
  ConsumerState<CustomerChatScreen> createState() =>
      _CustomerChatScreenState();
}

class _CustomerChatScreenState extends ConsumerState<CustomerChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

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

  bool _isUploadingImage = false;

 void _onSend() {
    final text = _inputController.text.trim();
    final pending = ref.read(pendingChatProductProvider);

    if (text.isEmpty && pending == null) return;

    _inputController.clear();
    ref.read(customerChatProvider.notifier).sendMessage(
          text,
          productId: pending?.productId,
        );
        if (pending != null) {
      ref.read(pendingChatProductProvider.notifier).clear();
    }
    _scrollToBottom();
  }

  Future<void> _onPickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // forces bytes on web — path is always null there
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingImage = true);

      final bool success = await ref
          .read(customerChatProvider.notifier)
          .sendImage(result.files.first);

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

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'chat'),

            // ── Support header ──────────────────────────────────
            const _SupportHeader(),

            // ── Date marker ─────────────────────────────────────
            const _DateMarker(),

            // ── Messages ────────────────────────────────────────
            Expanded(
              child: _buildBody(chatState),
            ),

            // ── Input bar ───────────────────────────────────────
          // ── Input bar ───────────────────────────────────────
            // ── Attached product chip ────────────────────────────
            if (pendingProduct != null)
              _AttachedProductChip(
                productName: pendingProduct.productName,
                onRemove: () =>
                    ref.read(pendingChatProductProvider.notifier).clear(),
              ),

            // ── Input bar ───────────────────────────────────────
            _ChatInputBar(
              controller: _inputController,
              onSend: _onSend,
              onPickImage: _onPickImage,
              isUploadingImage: _isUploadingImage,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFFCFC4C5)),
            const SizedBox(height: 12),
            Text(
              chatState.error!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF656464),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () =>
                  ref.read(customerChatProvider.notifier).initConversation(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration:
                    BoxDecoration(border: Border.all(color: Colors.black)),
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (chatState.messages.isEmpty) {
      return const Center(
        child: Text(
          'Send a message to start chatting with support.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF656464),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        return _ChatBubble(message: chatState.messages[index]);
      },
    );
  }
}

// ─── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends ConsumerWidget {
  final Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomer = message.isFromCustomer;

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
          Column(
            crossAxisAlignment: isCustomer
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
             Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
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
                    // ── Image, if present ──
                    if (message.hasImage)
                      Image.network(
                        message.imageUrl!,
                        width: 240,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 240,
                            height: 180,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 240,
                          height: 120,
                          alignment: Alignment.center,
                          color: const Color(0xFFEEEEEE),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ),

                    // ── Product reference card, if present ──
                   // ── Product reference card, if present ──
                    // ── Product reference card, if present ──
                    if (message.hasProductRef)
                      Container(
                        width: 200,
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E2E2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
                              alignment: Alignment.center,
                              clipBehavior: Clip.antiAlias,
                              child: Builder(builder: (context) {
                                final String? thumbUrl = referencedProduct
                                        ?.variants.isNotEmpty ==
                                        true
                                    ? referencedProduct!.variants.first.primaryImageUrl
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
                            color: isCustomer ? Colors.white : Colors.black,
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
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
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
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF656464)),
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

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.isUploadingImage,
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
            GestureDetector(
              onTap: isUploadingImage ? null : onPickImage,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
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
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  border: Border.all(color: const Color(0xFFCFC4C5)),
                ),
                child: TextField(
                  controller: controller,
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
                      color: Color(0xFF9CA3AF),
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
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                color: Colors.black,
                child: const Icon(
                  Icons.send,
                  size: 18,
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
// ─── Support header ────────────────────────────────────────────────────────────

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PREMIUM SUPPORT',
                  style: TextStyle(
                    fontFamily: 'Archivo Narrow',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF1A1C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online · Typically replies in minutes',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF5F5E5E),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.info_outline,
            size: 20,
            color: Color(0xFF7E7576),
          ),
        ],
      ),
    );
  }
}

// ─── Date marker ───────────────────────────────────────────────────────────────

class _DateMarker extends StatelessWidget {
  const _DateMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: const Color(0xFFEEEEEE),
          child: const Text(
            'TODAY',
            style: TextStyle(
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