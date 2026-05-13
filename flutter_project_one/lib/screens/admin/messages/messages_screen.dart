import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/admin/messages/customer_list.dart';
import '../../../widgets/admin/messages/chat_window.dart';



class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() {
    return _MessagesScreenState();
  }
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {

  // ================================================
  // FAKE DATA — for testing only
  // later this will come from Firebase
  // ================================================

  // list of customers
  final List<CustomerChat> _customers = [
    CustomerChat(
      customerId: 'customer_001',
      customerName: 'Angel Tuazon',
      lastMessage: 'Hello! I want to ask about...',
      time: '2:45 PM',
      unreadCount: 3,
    ),
    CustomerChat(
      customerId: 'customer_002',
      customerName: 'Jay Galang',
      lastMessage: 'Is this available in size 9?',
      time: '1:30 PM',
      unreadCount: 0,
    ),
    CustomerChat(
      customerId: 'customer_003',
      customerName: 'John Dela Cruz',
      lastMessage: 'Thank you so much!',
      time: '11:20 AM',
      unreadCount: 1,
    ),
    CustomerChat(
      customerId: 'customer_004',
      customerName: 'Maria Santos',
      lastMessage: 'When will it be restocked?',
      time: 'Yesterday',
      unreadCount: 0,
    ),
    CustomerChat(
      customerId: 'customer_005',
      customerName: 'Kevin Reyes',
      lastMessage: 'Got it, thanks!',
      time: 'Yesterday',
      unreadCount: 0,
    ),
  ];

  // messages per customer
  // key = customerId, value = list of messages
  Map<String, List<ChatMessage>> _messages = {
    'customer_001': [
      ChatMessage(
        text: 'Hello! I want to ask about the Nike Panda in Pink size 8. Is it still available?',
        sender: 'customer',
        time: '2:30 PM',
      ),
      ChatMessage(
        text: 'Hi Angel! Yes, we still have Nike Panda in Pink size 8 available. We have 6 units in stock.',
        sender: 'admin',
        time: '2:32 PM',
      ),
      ChatMessage(
        text: 'That\'s great! How much is it?',
        sender: 'customer',
        time: '2:33 PM',
      ),
      ChatMessage(
        text: 'It\'s priced at ₱2,500. Would you like to place an order?',
        sender: 'admin',
        time: '2:35 PM',
      ),
      ChatMessage(
        text: 'Yes please! How do I order?',
        sender: 'customer',
        time: '2:45 PM',
      ),
    ],
    'customer_002': [
      ChatMessage(
        text: 'Is the Nike Air Max available in size 9?',
        sender: 'customer',
        time: '1:20 PM',
      ),
      ChatMessage(
        text: 'Hi Jay! Let me check that for you.',
        sender: 'admin',
        time: '1:25 PM',
      ),
      ChatMessage(
        text: 'Is this available in size 9?',
        sender: 'customer',
        time: '1:30 PM',
      ),
    ],
    'customer_003': [
      ChatMessage(
        text: 'I received my order. Thank you so much!',
        sender: 'customer',
        time: '11:20 AM',
      ),
    ],
    'customer_004': [
      ChatMessage(
        text: 'When will the Adidas Ultraboost be restocked?',
        sender: 'customer',
        time: 'Yesterday',
      ),
      ChatMessage(
        text: 'When will it be restocked?',
        sender: 'customer',
        time: 'Yesterday',
      ),
    ],
    'customer_005': [
      ChatMessage(
        text: 'Thanks for the info!',
        sender: 'customer',
        time: 'Yesterday',
      ),
      ChatMessage(
        text: 'Got it, thanks!',
        sender: 'customer',
        time: 'Yesterday',
      ),
    ],
  };

  // currently selected customer
  // starts with first customer selected
  CustomerChat? _selectedCustomer;

  @override
  void initState() {
    super.initState();

    // select first customer by default
    if (_customers.isNotEmpty) {
      _selectedCustomer = _customers[0];
    }
  }

  // ================================================
  // ON SEND MESSAGE
  // adds new message to the list
  // ================================================
  void _onSendMessage(String text) {

    // make sure a customer is selected
    if (_selectedCustomer == null) {
      return;
    }

    String customerId = _selectedCustomer!.customerId;

    // create new message
    ChatMessage newMessage = ChatMessage(
      text: text,
      sender: 'admin',
      time: 'Just now',
    );

    setState(() {

      // add message to the list
      if (_messages[customerId] == null) {
        _messages[customerId] = [];
      }

      _messages[customerId]!.add(newMessage);

      // update last message preview in customer list
      for (int i = 0; i < _customers.length; i = i + 1) {
        if (_customers[i].customerId == customerId) {
          _customers[i].lastMessage = text;
          _customers[i].time = 'Just now';
          break;
        }
      }
    });
  }

  // ================================================
  // BUILD
  // ================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── page background: matches app-wide grey ──
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [

          // ── LEFT PANEL — customer list (white card) ──
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(
                  color: Color(0xFFF3F4F6 ),
                  width: 1,
                ),
              ),
            ),
            child: CustomerList(
              customers: _customers,
              selectedCustomerId: _selectedCustomer?.customerId,
              onCustomerSelected: (CustomerChat customer) {
                setState(() {
                  _selectedCustomer = customer;
                });
              },
            ),
          ),

          // ── RIGHT PANEL — chat window (light grey bg) ──
          Expanded(
            child: Container(
              color: const Color(0xFFF3F4F6),
              child: _selectedCustomer == null

                  // no customer selected yet
                  ? const Center(
                      child: Text(
                        'Select a customer to start chatting.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    )

                  // show chat window for selected customer
                  : ChatWindow(
                      customer: _selectedCustomer!,
                      messages: _messages[_selectedCustomer!.customerId] ?? [],
                      onSendMessage: _onSendMessage,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}