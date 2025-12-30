class ChatConfig {
  final String chatId;
  final int userId;
  final bool isPinned;
  final bool isArchived;
  final DateTime? muteUntil;
  final String category;

  ChatConfig({
    required this.chatId,
    required this.userId,
    this.isPinned = false,
    this.isArchived = false,
    this.muteUntil,
    this.category = 'personal',
  });

  bool get isMuted => muteUntil != null && muteUntil!.isAfter(DateTime.now());

  factory ChatConfig.fromJson(Map<String, dynamic> json) {
    return ChatConfig(
      chatId: json['chat_id'],
      userId: json['user_id'],
      isPinned: json['is_pinned'] ?? false,
      isArchived: json['is_archived'] ?? false,
      muteUntil: json['mute_until'] != null
          ? DateTime.parse(json['mute_until'])
          : null,
      category: json['category'] ?? 'personal',
    );
  }

  ChatConfig copyWith({
    bool? isPinned,
    bool? isArchived,
    DateTime? muteUntil,
    String? category,
  }) {
    return ChatConfig(
      chatId: chatId,
      userId: userId,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      muteUntil: muteUntil ?? this.muteUntil,
      category: category ?? this.category,
    );
  }
}
