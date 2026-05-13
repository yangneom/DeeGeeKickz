import 'package:flutter/material.dart';
import 'customer_list.dart';

// ================================================
// MESSAGE MODEL
// blueprint for one message in the chat
// ================================================
class ChatMessage {

  // the text of the message
  String text;

  // who sent this message
  // 'admin' or 'customer'
  String sender;

  // time the message was sent
  String time;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.time,
  });
}

// ================================================
// CHAT WINDOW
//
// This is the RIGHT side of the messages screen
//
// Shows:
//   - Chat header with customer name
//   - Messages list
//   - Message input at the bottom
// ================================================
class ChatWindow extends StatefulWidget {

  // the customer we are chatting with
  final CustomerChat customer;

  // list of messages in this chat
  final List<ChatMessage> messages;

  // what happens when admin sends a message
  final Function(String message) onSendMessage;

  const ChatWindow({
    super.key,
    required this.customer,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  State<ChatWindow> createState() {
    return _ChatWindowState();
  }
}

class _ChatWindowState extends State<ChatWindow> {

  // controls the message input field
  final TextEditingController _messageController = TextEditingController();

  // scroll controller to auto scroll to bottom
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ================================================
  // SCROLL TO BOTTOM
  // scrolls chat to the latest message
  // ================================================
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ================================================
  // SEND MESSAGE
  // ================================================
  void _sendMessage() {

    // get message text
    String text = _messageController.text.trim();

    // do nothing if empty
    if (text.isEmpty) {
      return;
    }

    // call parent function to send
    widget.onSendMessage(text);

    // clear the input
    _messageController.clear();

    // scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // ================================================
  // GET INITIALS
  // ================================================
  String _getInitials(String name) {
    List<String> words = name.split(' ');
    String initials = '';
    for (int i = 0; i < words.length; i = i + 1) {
      if (i >= 2) {
        break;
      }
      if (words[i].isNotEmpty) {
        initials = initials + words[i][0].toUpperCase();
      }
    }
    return initials;
  }

  // ================================================
  // BUILD MESSAGE BUBBLE
  // ================================================
  Widget _buildMessageBubble(ChatMessage message) {

    // check if this message is from admin
    bool isAdmin = message.sender == 'admin';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(

        // admin messages on right, customer on left
        mainAxisAlignment: isAdmin == true
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,

        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          // customer avatar — only show for customer messages
          if (isAdmin == false)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.customer.customerName),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),

          // message column — bubble + time
          Column(
            crossAxisAlignment: isAdmin == true
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [

              // message bubble
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 320,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(

                  // blue for admin, white for customer
                  color: isAdmin == true
                      ? const Color(0xFF2563EB)
                      : Colors.white,

                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),

                    // different corner for sender side
                    bottomLeft: isAdmin == true
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isAdmin == true
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),

                  border: isAdmin == true
                      ? null
                      : Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 0.5,
                        ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: isAdmin == true
                        ? Colors.white
                        : const Color(0xFF111827),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // time
              Text(
                message.time,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),

          // admin avatar — only show for admin messages
          if (isAdmin == true)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        // ── CHAT HEADER ──
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [

              // customer avatar
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(widget.customer.customerName),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // customer name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // customer name
                    Text(
                      widget.customer.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // online status
                    Row(
                      children: [

                        // green dot
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 4),

                        const Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3 dot menu button
              GestureDetector(
                onTap: () {
                  print('Options tapped');
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── MESSAGES LIST ──
        Expanded(
          child: Container(
            color: const Color(0xFFF9FAFB),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: widget.messages.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildMessageBubble(widget.messages[index]);
              },
            ),
          ),
        ),

        // ── MESSAGE INPUT ──
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [

              // attach file button
              GestureDetector(
                onTap: () {
                  print('Attach file tapped');
                },
                child: const Icon(
                  Icons.attach_file,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(width: 10),

              // message text field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),

                    // send on enter key
                    onSubmitted: (String value) {
                      _sendMessage();
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}