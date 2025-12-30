import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/message_provider.dart';
import 'providers/group_provider.dart';

class GroupSetupScreen extends ConsumerStatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  ConsumerState<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends ConsumerState<GroupSetupScreen> {
  final _nameController = TextEditingController();
  final Set<int> _selectedMemberIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final group = await ref.read(groupProvider.notifier).createGroup(
            _nameController.text.trim(),
            _selectedMemberIds.toList(),
          );
      if (mounted) {
        context.pushReplacement('/chat/g${group['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(syncedContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          if (_isCreating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _handleCreateGroup,
              child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Group Name',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'SELECT MEMBERS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedMemberIds.length} selected',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No contacts found.'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userId = user['id'];
                    final isSelected = _selectedMemberIds.contains(userId);

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user['username']?[0].toUpperCase() ?? 'U'),
                      ),
                      title: Text(user['username'] ?? 'User $userId'),
                      subtitle: Text(user['phone']),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMemberIds.add(userId);
                            } else {
                              _selectedMemberIds.remove(userId);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedMemberIds.remove(userId);
                          } else {
                            _selectedMemberIds.add(userId);
                          }
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
