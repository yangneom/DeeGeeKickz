// lib/models/chat_message_model.dart

class CustomerChatMessage {
  final String id;
  final String text;
  final CustomerChatSender sender;
  final DateTime timestamp;
  final String? imageUrl; // support image attachments later

  CustomerChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imageUrl,
  });

  String get formattedTime {
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }
}

enum CustomerChatSender { support, customer }

// ── Mock data ────────────────────────────────────────────────────

final List<CustomerChatMessage> mockChatMessages = [
  CustomerChatMessage(
    id: 'msg_001',
    text:
        "Hello! Welcome to DeeGeeKickz Premium Support. I'm Alex. How can I assist you with your recent order or product questions today?",
    sender: CustomerChatSender.support,
    timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
  ),
  CustomerChatMessage(
    id: 'msg_002',
    text:
        "Hi Alex! I'm inquiring about the DG-Quantum limited drop. Will there be a restock for Size 11 before the season ends?",
    sender: CustomerChatSender.customer,
    timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  CustomerChatMessage(
    id: 'msg_003',
    text:
        "The DG-Quantum is part of our Elite series. We have one final allocation arriving this Friday at 8:00 AM. Would you like me to set a priority notification for your account?",
    sender: CustomerChatSender.support,
    timestamp: DateTime.now().subtract(const Duration(minutes: 17)),
  ),
  CustomerChatMessage(
    id: 'msg_004',
    text:
        "Yes, please. That would be perfect. Also, are the shipping policies different for the limited series?",
    sender: CustomerChatSender.customer,
    timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  CustomerChatMessage(
    id: 'msg_005',
    text:
        "Great news — priority notification is set! For the Elite series, we offer free express shipping on all limited drops. Your order will arrive within 2 business days.",
    sender: CustomerChatSender.support,
    timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
  ),
];