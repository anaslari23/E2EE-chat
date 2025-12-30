import 'attachment.dart';

class MessageReaction {
  final int userId;
  final String emoji;

  MessageReaction({required this.userId, required this.emoji});
}

class ChatMessage {
  final int? id;
  final String content;
  final bool isMe;
  final DateTime timestamp;
  final String? senderName;
  final String status; // pending, delivered, read
  final int? parentId;
  final bool isEdited;
  final bool isDeleted;
  final bool deletedForAll;
  final List<MessageReaction> reactions;
  final List<ChatAttachment> attachments;
  final String messageType; // text, image, video, voice, document
  final bool isStarred;

  ChatMessage({
    this.id,
    required this.content,
    required this.isMe,
    required this.timestamp,
    this.senderName,
    this.status = 'delivered',
    this.parentId,
    this.isEdited = false,
    this.isDeleted = false,
    this.deletedForAll = false,
    this.reactions = const [],
    this.attachments = const [],
    this.messageType = 'text',
    this.isStarred = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    return ChatMessage(
      id: json['message_id'],
      content: json['ciphertext'] ?? '',
      isMe: json['sender_id'] == currentUserId,
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'] ?? 'delivered',
      parentId: json['parent_id'],
      isEdited: json['is_edited'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      deletedForAll: json['deleted_for_all'] ?? false,
      reactions: (json['reactions'] as List? ?? [])
          .map((r) => MessageReaction(
                userId: r['user_id'],
                emoji: r['emoji'],
              ))
          .toList(),
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => ChatAttachment.fromJson(a))
          .toList(),
      messageType: json['message_type'] ?? 'text',
      isStarred: json['is_starred'] ?? false,
    );
  }
}
