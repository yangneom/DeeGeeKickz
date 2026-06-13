// lib/widgets/customer/chat/chat_bubble.dart

import 'package:flutter/material.dart';
import '../../../models/chat_message_model.dart';

class ChatBubble extends StatelessWidget {
  final CustomerChatMessage message;

  const ChatBubble({super.key, required this.message});

  bool get _isSupport => message.sender == CustomerChatSender.support;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            _isSupport ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          _isSupport ? _ReceivedBubble(message: message) : _SentBubble(message: message),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              left: _isSupport ? 4 : 0,
              right: _isSupport ? 0 : 4,
            ),
            child: Text(
              message.formattedTime,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: Color(0xFF7E7576),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedBubble extends StatelessWidget {
  final CustomerChatMessage message;
  const _ReceivedBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E2E2)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: Color(0xFF1A1C1C),
          ),
        ),
      ),
    );
  }
}

class _SentBubble extends StatelessWidget {
  final CustomerChatMessage message;
  const _SentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(2),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.6,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}