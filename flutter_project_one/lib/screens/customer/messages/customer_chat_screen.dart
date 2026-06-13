// lib/screens/customer/messages/customer_chat_screen.dart

import 'package:flutter/material.dart';
import '../../../models/chat_message_model.dart';
import '../../../widgets/common/nav/app_top_bar.dart';
import '../../../widgets/common/nav/app_drawer.dart';
import '../../../widgets/common/nav/bottom_nav_bar.dart';
import '../../../../widgets/cashier/chat/chat_bubble.dart';
import '../../../../widgets/cashier/chat/chat_input_bar.dart';
import '../../../../widgets/cashier/chat/quick_action_chip_bar.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({super.key});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<CustomerChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    // Deep-copy mock so mutations don't affect the source list
    _messages = List.from(mockChatMessages);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSend(String text) {
    final msg = CustomerChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      sender: CustomerChatSender.customer,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Simulate support reply after 1.5 s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final reply = CustomerChatMessage(
        id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
        text:
            "Thanks for reaching out! Our support team will get back to you shortly. In the meantime, feel free to check our FAQ.",
        sender: CustomerChatSender.support,
        timestamp: DateTime.now(),
      );
      setState(() => _messages.add(reply));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  void _onQuickChipTapped(String chipText) {
    _onSend(chipText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(activeRoute: 'chat'),

            // ── Support header banner ──
            _SupportHeader(),

            // ── Date marker ──
            _DateMarker(),

            // ── Messages list ──
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return ChatBubble(message: _messages[index]);
                },
              ),
            ),

            // ── Quick action chips ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: QuickActionChipBar(onChipTapped: _onQuickChipTapped),
            ),

            // ── Input bar ──
            ChatInputBar(onSend: _onSend),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────

class _SupportHeader extends StatelessWidget {
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
          // Support avatar
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

          // Name + status
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

          // Info icon
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

class _DateMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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