import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_config.dart';
import '../../../../core/providers.dart';

class ChatSettingsNotifier extends StateNotifier<Map<String, ChatConfig>> {
  final Ref ref;

  ChatSettingsNotifier(this.ref) : super({}) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      final settingsList = await api.getChatSettings(userId);
      
      final Map<String, ChatConfig> newMap = {};
      for (var s in settingsList) {
        final config = ChatConfig.fromJson(s);
        newMap[config.chatId] = config;
      }
      state = newMap;
    } catch (e) {
      print('Failed to load chat settings: $e');
    }
  }

  Future<void> togglePin(String chatId) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      await api.togglePinChat(chatId, userId);
      
      final current = state[chatId] ?? ChatConfig(chatId: chatId, userId: userId);
      state = {
        ...state,
        chatId: current.copyWith(isPinned: !current.isPinned),
      };
    } catch (e) {
      print('Failed to pin chat: $e');
    }
  }

  Future<void> toggleArchive(String chatId) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      await api.toggleArchiveChat(chatId, userId);
      
      final current = state[chatId] ?? ChatConfig(chatId: chatId, userId: userId);
      state = {
        ...state,
        chatId: current.copyWith(isArchived: !current.isArchived),
      };
    } catch (e) {
      print('Failed to archive chat: $e');
    }
  }

  Future<void> muteChat(String chatId, int? durationMinutes) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      await api.muteChat(chatId, userId, durationMinutes);
      
      final current = state[chatId] ?? ChatConfig(chatId: chatId, userId: userId);
      final muteUntil = durationMinutes != null 
          ? DateTime.now().add(Duration(minutes: durationMinutes))
          : null;
          
      state = {
        ...state,
        chatId: current.copyWith(muteUntil: muteUntil),
      };
    } catch (e) {
      print('Failed to mute chat: $e');
    }
  }
}

final chatSettingsProvider = StateNotifierProvider<ChatSettingsNotifier, Map<String, ChatConfig>>((ref) {
  return ChatSettingsNotifier(ref);
});
