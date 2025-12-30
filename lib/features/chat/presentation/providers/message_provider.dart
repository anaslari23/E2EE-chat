import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/message.dart';
import '../../../../core/providers.dart';

class MessageNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  MessageNotifier(this.ref) : super([]) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    final ws = ref.read(webSocketServiceProvider);
    ws.messages.listen((data) {
      // Logic to handle incoming message
      // Note: In a real app, this would involve decryption via SignalService
      // For this polish phase, we'll simulate the addition to state
      if (data is Map<String, dynamic> && data['type'] == 'message') {
        state = [...state, ChatMessage(
          content: data['content'],
          isMe: false,
          timestamp: DateTime.now(),
        )];
      }
    });
  }

  Future<void> editMessage(int messageId, String newContent) async {
    try {
      final api = ref.read(apiServiceProvider);
      // In real life, encrypt newContent here
      await api.editMessage(messageId, newContent);
      
      state = [
        for (final msg in state)
          if (msg.id == messageId)
            ChatMessage(
              id: msg.id,
              content: newContent,
              isMe: msg.isMe,
              timestamp: msg.timestamp,
              isEdited: true,
              status: msg.status,
            )
          else
            msg
      ];
    } catch (e) {
      print('Failed to edit: $e');
    }
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.deleteMessage(messageId, forEveryone: forEveryone);
      
      if (forEveryone) {
        state = [
          for (final msg in state)
            if (msg.id == messageId)
              ChatMessage(
                id: msg.id,
                content: 'Message was deleted',
                isMe: msg.isMe,
                timestamp: msg.timestamp,
                isDeleted: true,
                deletedForAll: true,
              )
            else
              msg
        ];
      } else {
        state = state.where((m) => m.id != messageId).toList();
      }
    } catch (e) {
      print('Failed to delete: $e');
    }
  }

  Future<void> addReaction(int messageId, String emoji) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      await api.reactToMessage(messageId, userId, emoji);
      
      state = [
        for (final msg in state)
          if (msg.id == messageId)
            ChatMessage(
              id: msg.id,
              content: msg.content,
              isMe: msg.isMe,
              timestamp: msg.timestamp,
              isEdited: msg.isEdited,
              isDeleted: msg.isDeleted,
              deletedForAll: msg.deletedForAll,
              parentId: msg.parentId,
              reactions: [
                ...msg.reactions.where((r) => r.userId != userId),
                MessageReaction(userId: userId, emoji: emoji),
              ],
            )
          else
            msg
      ];
    } catch (e) {
      print('Failed to react: $e');
    }
  }

  Future<void> toggleStar(int messageId) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;
      
      final api = ref.read(apiServiceProvider);
      await api.toggleStarMessage(messageId, userId);

      state = [
        for (final msg in state)
          if (msg.id == messageId)
            ChatMessage(
              id: msg.id,
              content: msg.content,
              isMe: msg.isMe,
              timestamp: msg.timestamp,
              isEdited: msg.isEdited,
              isDeleted: msg.isDeleted,
              deletedForAll: msg.deletedForAll,
              parentId: msg.parentId,
              reactions: msg.reactions,
              attachments: msg.attachments,
              messageType: msg.messageType,
              isStarred: !msg.isStarred,
            )
          else
            msg
      ];
    } catch (e) {
      print('Failed to toggle star: $e');
    }
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  Future<void> fetchHistory(int contactId) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      final jsonList = await api.getPendingMessages(userId); // Simplified
      // In real app, we'd have a getHistory(userId, contactId)
      state = jsonList.map((j) => ChatMessage.fromJson(j, userId)).toList();
    } catch (e) {
      print('Failed to fetch history: $e');
    }
  }
}

final messagesProvider = StateNotifierProvider<MessageNotifier, List<ChatMessage>>((ref) {
  return MessageNotifier(ref);
});

final conversationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final userId = ref.watch(authProvider);
  if (userId == null) return [];
  
  final api = ref.read(apiServiceProvider);
  return await api.getConversations(userId);
});

final usersProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getUsers();
});

final starredMessagesProvider = FutureProvider<List<ChatMessage>>((ref) async {
  final userId = ref.watch(authProvider);
  if (userId == null) return [];

  final api = ref.read(apiServiceProvider);
  final jsonList = await api.getStarredMessages(userId);
  return jsonList.map((j) => ChatMessage.fromJson(j, userId)).toList();
});
