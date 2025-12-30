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

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }
}

final messagesProvider = StateNotifierProvider<MessageNotifier, List<ChatMessage>>((ref) {
  return MessageNotifier(ref);
});
