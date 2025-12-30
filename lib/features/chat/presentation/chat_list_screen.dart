import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/chat_settings_provider.dart';
import 'providers/message_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final chatSettings = ref.watch(chatSettingsProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
              child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF2166EE)),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authStateProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout', style: TextStyle(color: Colors.red)),
              ),
            ],
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
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                // Filter out archived
                final activeConversations = conversations
                    .where((c) => !(chatSettings[c['contact_id'].toString()]?.isArchived ?? false))
                    .where((c) {
                      if (_selectedFilter == 'Unread') return c['unread_count'] > 0;
                      return true;
                    })
                    .toList();

                // Sort: Pinned first
                activeConversations.sort((a, b) {
                  final pinA = chatSettings[a['contact_id'].toString()]?.isPinned ?? false;
                  final pinB = chatSettings[b['contact_id'].toString()]?.isPinned ?? false;
                  if (pinA && !pinB) return -1;
                  if (!pinA && pinB) return 1;
                  return 0;
                });

                if (activeConversations.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedFilter == 'All' 
                        ? 'No active chats yet.' 
                        : 'No unread messages.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: activeConversations.length,
                  itemBuilder: (context, index) {
                    final conv = activeConversations[index];
                    return _ChatTile(conv: conv, index: index);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $st')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewChatDialog(context, ref),
        label: const Text('New Chat'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2166EE),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'All', 
            isSelected: _selectedFilter == 'All', 
            onSelected: () => setState(() => _selectedFilter = 'All'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Unread', 
            isSelected: _selectedFilter == 'Unread', 
            onSelected: () => setState(() => _selectedFilter = 'Unread'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final usersAsync = ref.watch(usersProvider);
          return AlertDialog(
            title: const Text('New Secure Chat'),
            content: SizedBox(
              width: double.maxFinite,
              child: usersAsync.when(
                data: (users) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(user['username'] ?? 'User ${user['id']}'),
                      subtitle: Text(user['phone']),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/chat/${user['id']}');
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2166EE) : Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final Map<String, dynamic> conv;
  final int index;
  const _ChatTile({required this.conv, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = conv['contact_id'].toString();
    final settingsMap = ref.watch(chatSettingsProvider);
    final settings = settingsMap[chatId];
    final isPinned = settings?.isPinned ?? false;
    final isMuted = settings?.isMuted ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onLongPress: () => _showChatActions(context, ref, chatId),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          conv['contact_name'].substring(0, 1).toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2166EE)),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conv['contact_name'],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
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
      subtitle: Text(
        conv['last_message'] ?? 'Start chatting...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(conv['timestamp']),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          if (conv['unread_count'] > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF2166EE), shape: BoxShape.circle),
              child: Text(
                conv['unread_count'].toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () => context.push('/chat/$chatId'),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }

  void _showChatActions(BuildContext context, WidgetRef ref, String chatId) {
    final settingsMap = ref.read(chatSettingsProvider);
    final settings = settingsMap[chatId];
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
