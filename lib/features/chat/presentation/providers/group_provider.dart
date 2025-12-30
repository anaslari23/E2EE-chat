import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class GroupNotifier extends StateNotifier<List<dynamic>> {
  final Ref ref;

  GroupNotifier(this.ref) : super([]) {
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final userId = ref.read(authProvider);
    if (userId == null) return;
    
    final api = ref.read(apiServiceProvider);
    try {
      state = await api.getGroups(userId);
    } catch (e) {
      print('Failed to fetch groups: $e');
    }
  }

  Future<Map<String, dynamic>> createGroup(String name, List<int> memberIds) async {
    final userId = ref.read(authProvider);
    if (userId == null) throw Exception('User not authenticated');

    final api = ref.read(apiServiceProvider);
    final group = await api.createGroup(name, memberIds, userId);
    state = [...state, group];
    return group;
  }
}

final groupProvider = StateNotifierProvider<GroupNotifier, List<dynamic>>((ref) {
  return GroupNotifier(ref);
});

final groupMembersProvider = FutureProvider.family<List<dynamic>, int>((ref, groupId) async {
  final api = ref.read(apiServiceProvider);
  return await api.getGroupMembers(groupId);
});
