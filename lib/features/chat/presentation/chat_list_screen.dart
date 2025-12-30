import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 5, // Simulated recent chats
        itemBuilder: (context, index) {
          final chatId = 'user_${index + 1}';
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

class _ChatTile extends StatelessWidget {
  final String chatId;
  final int index;
  const _ChatTile({required this.chatId, required this.index});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          chatId.split('_')[1], 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2166EE)),
        ),
      ),
      title: Text(
        'User $chatId',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
}
