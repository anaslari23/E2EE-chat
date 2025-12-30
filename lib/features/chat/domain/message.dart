class ChatMessage {
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final String? senderName;
  final String status; // pending, delivered, read

  ChatMessage({
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.senderName,
    this.status = 'delivered',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    return ChatMessage(
      content: json['ciphertext'] ?? '',
      isMe: json['sender_id'] == currentUserId,
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'] ?? 'delivered',
    );
  }
}
