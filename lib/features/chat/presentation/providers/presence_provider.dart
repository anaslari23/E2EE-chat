import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';

class PresenceState {
  final Map<int, bool> onlineUsers;
  final Map<int, DateTime> lastSeen;
  final Map<int, bool> typingUsers; // recipientId or groupIdHash -> isTyping
  final Map<int, bool> typingGroups;

  PresenceState({
    this.onlineUsers = const {},
    this.lastSeen = const {},
    this.typingUsers = const {},
    this.typingGroups = const {},
  });

  PresenceState copyWith({
    Map<int, bool>? onlineUsers,
    Map<int, DateTime>? lastSeen,
    Map<int, bool>? typingUsers,
    Map<int, bool>? typingGroups,
  }) {
    return PresenceState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      lastSeen: lastSeen ?? this.lastSeen,
      typingUsers: typingUsers ?? this.typingUsers,
      typingGroups: typingGroups ?? this.typingGroups,
    );
  }
}

class PresenceNotifier extends StateNotifier<PresenceState> {
  final Ref ref;

  PresenceNotifier(this.ref) : super(PresenceState()) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    final ws = ref.read(webSocketServiceProvider);

    ws.messages.listen((data) {
      final type = data['type'];
      final senderId = data['sender_id'];

      if (type == 'presence') {
        final isOnline = data['data']['is_online'] as bool;
        final lastSeenStr = data['data']['last_seen'];
        
        state = state.copyWith(
          onlineUsers: {...state.onlineUsers, senderId: isOnline},
          lastSeen: lastSeenStr != null 
            ? {...state.lastSeen, senderId: DateTime.parse(lastSeenStr)}
            : state.lastSeen,
        );
      } else if (type == 'typing') {
        final isTyping = data['data']['is_typing'] as bool;
        final groupId = data['group_id'];

        if (groupId != null) {
          state = state.copyWith(
            typingGroups: {...state.typingGroups, groupId: isTyping},
          );
        } else {
          state = state.copyWith(
            typingUsers: {...state.typingUsers, senderId: isTyping},
          );
        }
      }
    });
  }

  void setTyping(bool isTyping, int? recipientId, {int? groupId}) {
    final ws = ref.read(webSocketServiceProvider);
    ws.sendTyping(isTyping, recipientId, groupId: groupId);
  }
}

final presenceProvider = StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  return PresenceNotifier(ref);
});
