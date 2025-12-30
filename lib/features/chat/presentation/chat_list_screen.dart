import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/chat_settings_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatSettings = ref.watch(chatSettingsProvider);
    
    // Simplified: Filter out archived chats for the main list
    final chats = List.generate(5, (i) => 'user_${i + 1}')
        .where((id) => !(chatSettings[id]?.isArchived ?? false))
        .toList();
        
    // Sort: Pinned first
    chats.sort((a, b) {
      final pinA = chatSettings[a]?.isPinned ?? false;
      final pinB = chatSettings[b]?.isPinned ?? false;
      if (pinA && !pinB) return -1;
      if (!pinA && pinB) return 1;
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
            child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF2166EE)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            onPressed: () => context.push('/starred'),
            tooltip: 'Starred Messages',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chatId = chats[index];
          return _ChatTile(chatId: chatId, index: index);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('New Chat'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2166EE),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final String chatId;
  final int index;
  const _ChatTile({required this.chatId, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider)[chatId];
    final isPinned = settings?.isPinned ?? false;
    final isMuted = settings?.isMuted ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onLongPress: () => _showChatActions(context, ref),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          chatId.split('_')[1], 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2166EE)),
        ),
      ),
      title: Row(
        children: [
          Text(
            'User $chatId',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (isPinned) ...[
            const SizedBox(width: 4),
            const Icon(Icons.push_pin, size: 12, color: Colors.amber),
          ],
          if (isMuted) ...[
            const SizedBox(width: 4),
            const Icon(Icons.volume_off, size: 12, color: Colors.grey),
          ],
        ],
      ),
      subtitle: const Text(
        'Tap to open secure chat channel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('10:45 AM', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          if (index == 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF2166EE), shape: BoxShape.circle),
              child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      onTap: () => context.push('/chat/$chatId'),
    );
  }

  void _showChatActions(BuildContext context, WidgetRef ref) {
    final settings = ref.read(chatSettingsProvider)[chatId];
    final isPinned = settings?.isPinned ?? false;
    final isArchived = settings?.isArchived ?? false;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).togglePin(chatId);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive : Icons.archive_outlined),
              title: Text(isArchived ? 'Unarchive' : 'Archive'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).toggleArchive(chatId);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('Mute Notifications'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).muteChat(chatId, 60); // 1 hour
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
