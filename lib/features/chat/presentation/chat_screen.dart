import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class ChatScreen extends StatelessWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final chat = mockChats.firstWhere((c) => c.id == id);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(chat.name[0], style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text(chat.name),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockMessages.length,
              itemBuilder: (context, index) {
                final message = mockMessages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Align(
                    alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: message.isMe
                            ? const Color(0xFF2166EE)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(message.isMe ? 16 : 0),
                          bottomRight: Radius.circular(message.isMe ? 0 : 16),
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: message.isMe ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add), onPressed: () {}),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF2166EE)),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
