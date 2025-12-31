import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/message.dart';
import '../../domain/attachment.dart';
import '../../../../core/providers.dart';
import '../../../../services/api_service.dart';
import '../../../../services/contact_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'group_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

import 'dart:io';

import 'dart:async';

class MessageNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;
  Timer? _pruneTimer;

  MessageNotifier(this.ref) : super([]) {
    _listenToWebSocket();
    _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pruneExpiredMessages());
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    super.dispose();
  }

  void _pruneExpiredMessages() {
    final now = DateTime.now();
    bool changed = false;
    final newList = state.where((msg) {
      if (msg.expiresAt != null && msg.expiresAt!.isBefore(now)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    if (changed) {
      state = newList;
    }
  }

  void _listenToWebSocket() {
    final ws = ref.read(webSocketServiceProvider);
    final signal = ref.read(signalServiceProvider);
    final selfId = ref.read(authProvider);

    ws.messages.listen((data) async {
      try {
        if (data['type'] == 'sender_key_distribution') {
          final senderId = data['sender_id'];
          final groupId = data['group_id'].toString();
          final bundle = data['ciphertext']; // distribution message

          final distMsg = SenderKeyDistributionMessageWrapper.fromSerialized(
              base64Decode(bundle));
          final senderAddress = SignalProtocolAddress(senderId.toString(), 1);

          await signal.processGroupSession(groupId, senderAddress, distMsg);
          print('Processed sender key distribution from $senderId for group $groupId');
          return;
        }

        if (data['type'] == 'group_message') {
          final senderId = data['sender_id'];
          final groupId = data['group_id'].toString();
          final ciphertext = base64Decode(data['ciphertext']);

          final senderAddress = SignalProtocolAddress(senderId.toString(), 1);
          final plaintext = await signal.decryptGroupMessage(
              groupId, senderAddress, ciphertext);

          // Check if it's media
          try {
            final mediaJson = jsonDecode(plaintext);
            if (mediaJson['type'] == 'media') {
              final attachment = ChatAttachment(
                id: mediaJson['attachment_id'],
                type: ChatAttachment.parseType(mediaJson['file_type']),
                fileUrl: '${ApiService.baseUrl}/media/download/${mediaJson['attachment_id']}',
                fileName: mediaJson['file_name'],
                fileSize: mediaJson['file_size'],
                mediaKey: base64Decode(mediaJson['media_key']),
                mediaNonce: base64Decode(mediaJson['media_nonce']),
              );

              state = [
                ...state,
                ChatMessage(
                  id: data['message_id'],
                  content: mediaJson['file_type'] == 'voice' ? 'Voice Note' : mediaJson['file_name'],
                  isMe: senderId == selfId,
                  timestamp: DateTime.now(),
                  attachments: [attachment],
                  messageType: mediaJson['file_type'],
                  groupId: int.tryParse(groupId),
                )
              ];
              return;
            }
          } catch (_) {
            // Not JSON
          }

          state = [
            ...state,
            ChatMessage(
              content: plaintext,
              isMe: senderId == selfId,
              timestamp: DateTime.now(),
              groupId: int.tryParse(groupId),
            )
          ];
          return;
        }

        if (data['type'] == 'message_status') {
          final msgId = data['data']['message_id'];
          final newStatus = data['data']['status'];
          
          state = [
            for (final msg in state)
              if (msg.id == msgId)
                ChatMessage(
                  id: msg.id,
                  content: msg.content,
                  isMe: msg.isMe,
                  timestamp: msg.timestamp,
                  status: newStatus,
                  reactions: msg.reactions,
                  attachments: msg.attachments,
                  messageType: msg.messageType,
                  isStarred: msg.isStarred,
                  groupId: msg.groupId,
                )
              else
                msg
          ];
          return;
        }

        if (data['type'] == 'message') {
          final senderId = data['sender_id'];
          final messageId = data['message_id'];
          final ciphertext = data['ciphertext'];
          final deviceId = data['sender_device_id'];

          final senderName = senderId.toString(); // Should look up in contacts
          
          final decrypted = await signal.decryptMessage(
            senderName, 
            deviceId, 
            base64Decode(ciphertext)
          );

          // Check if it's media
          try {
            final mediaJson = jsonDecode(decrypted);
            if (mediaJson['type'] == 'media') {
              final attachment = ChatAttachment(
                id: mediaJson['attachment_id'],
                type: ChatAttachment.parseType(mediaJson['file_type']),
                fileUrl: '${ApiService.baseUrl}/media/download/${mediaJson['attachment_id']}',
                fileName: mediaJson['file_name'],
                fileSize: mediaJson['file_size'],
                mediaKey: base64Decode(mediaJson['media_key']),
                mediaNonce: base64Decode(mediaJson['media_nonce']),
              );

              final expiresAt = data['expires_at'] != null ? DateTime.parse(data['expires_at']) : null;
              state = [
                ...state,
                ChatMessage(
                  id: messageId,
                  content: mediaJson['file_type'] == 'voice' ? 'Voice Note' : mediaJson['file_name'],
                  isMe: false,
                  timestamp: DateTime.now(),
                  expiresAt: expiresAt,
                  status: 'delivered',
                  attachments: [attachment],
                  messageType: mediaJson['file_type'],
                )
              ];
              ws.sendMessageStatus(messageId, senderId, 'delivered');
              return;
            }
          } catch (_) {
            // Not a JSON media message, treat as text
          }

          final expiresAt = data['expires_at'] != null ? DateTime.parse(data['expires_at']) : null;
          ws.sendMessageStatus(messageId, senderId, 'delivered');
          state = [
            ...state,
            ChatMessage(
              id: messageId,
              content: decrypted,
              isMe: false,
              timestamp: DateTime.now(),
              expiresAt: expiresAt,
              status: 'delivered',
            )
          ];
        }
      } catch (e) {
        print('WebSocket Decryption Error: $e');
      }
    });
  }

  Future<void> sendMessage(int recipientId, String plaintext, {int? expirationDuration}) async {
    try {
      final signal = ref.read(signalServiceProvider);
      final api = ref.read(apiServiceProvider);
      final ws = ref.read(webSocketServiceProvider);
      final selfId = ref.read(authProvider);

      if (selfId == null) return;

      // 1. Fetch recipient bundles
      final bundles = await api.getPreKeyBundles(recipientId);
      final List<Map<String, dynamic>> deviceBundles = bundles.map((b) => {
        'device_id': b['device_id'],
        'bundle': b['bundle'],
      }).toList().cast<Map<String, dynamic>>();

      // 2. Encrypt for all devices
      final ciphers = await signal.encryptMessageMultiDevice(
        recipientId.toString(), 
        deviceBundles, 
        plaintext
      );

      // 3. Send via WebSocket
      final b64Ciphers = ciphers.map((k, v) => MapEntry(k, base64Encode(v.serialize())));
      ws.sendMultiDeviceMessage(recipientId, b64Ciphers, expirationDuration: expirationDuration);

      final expiresAt = expirationDuration != null 
          ? DateTime.now().add(Duration(seconds: expirationDuration)) 
          : null;

      // 4. Update local state
      try {
        final mediaJson = jsonDecode(plaintext);
        if (mediaJson['type'] == 'media') {
          final attachment = ChatAttachment(
            id: mediaJson['attachment_id'],
            type: ChatAttachment.parseType(mediaJson['file_type']),
            fileUrl: '${ApiService.baseUrl}/media/download/${mediaJson['attachment_id']}',
            fileName: mediaJson['file_name'],
            fileSize: mediaJson['file_size'],
            mediaKey: base64Decode(mediaJson['media_key']),
            mediaNonce: base64Decode(mediaJson['media_nonce']),
          );

          state = [
            ...state,
            ChatMessage(
              content: mediaJson['file_type'] == 'voice' ? 'Voice Note' : mediaJson['file_name'],
              isMe: true,
              timestamp: DateTime.now(),
              attachments: [attachment],
              messageType: mediaJson['file_type'],
              expiresAt: expiresAt,
            )
          ];
          return;
        }
      } catch (_) {}

      state = [
        ...state,
        ChatMessage(
          content: plaintext,
          isMe: true,
          timestamp: DateTime.now(),
          expiresAt: expiresAt,
        )
      ];
    } catch (e) {
      print('Failed to send message: $e');
    }
  }

  // Tracking key distribution
  final Set<String> _distributedKeys = {};

  Future<void> sendGroupMessage(int groupId, String plaintext, {int? expirationDuration}) async {
    final selfId = ref.read(authProvider);
    if (selfId == null) return;

    final signal = ref.read(signalServiceProvider);
    final api = ref.read(apiServiceProvider);
    final ws = ref.read(webSocketServiceProvider);
    final selfAddress = SignalProtocolAddress(selfId.toString(), 1);

    try {
      // 1. Get members
      final members = await api.getGroupMembers(groupId);
      
      // 2. Distribute key if needed
      for (var member in members) {
        final mId = member['id'];
        if (mId == selfId) continue;

        final distKey = 'g$groupId-u$mId';
        if (!_distributedKeys.contains(distKey)) {
          final distMsg = await signal.createGroupSession(
              groupId.toString(), selfAddress);
          
          final users = await api.getUsers(selfId); // Simplified: need devices
          // For MVP, assume primary device 1
          final targetBundle = await api.getPreKeyBundle(mId, 1);
          
          final ciphers = await signal.encryptMessageMultiDevice(
            mId.toString(),
            [{'device_id': 1, 'bundle': targetBundle}],
            base64Encode(distMsg.serialize()),
          );

          final b64Ciphers = ciphers.map((k, v) => MapEntry(k, base64Encode(v.serialize())));
          ws.sendMultiDeviceMessage(mId, b64Ciphers, type: 'sender_key_distribution');
          
          _distributedKeys.add(distKey);
        }
      }

      // 3. Encrypt & Broadcast
      final ciphertext = await signal.encryptGroupMessage(
          groupId.toString(), selfAddress, plaintext);
      
      ws.sendGroupMessage(groupId, base64Encode(ciphertext), expirationDuration: expirationDuration);

      final expiresAt = expirationDuration != null 
          ? DateTime.now().add(Duration(seconds: expirationDuration)) 
          : null;

      // Check if it's media
      try {
        final mediaJson = jsonDecode(plaintext);
        if (mediaJson['type'] == 'media') {
          final attachment = ChatAttachment(
            id: mediaJson['attachment_id'],
            type: ChatAttachment.parseType(mediaJson['file_type']),
            fileUrl: '${ApiService.baseUrl}/media/download/${mediaJson['attachment_id']}',
            fileName: mediaJson['file_name'],
            fileSize: mediaJson['file_size'],
            mediaKey: base64Decode(mediaJson['media_key']),
            mediaNonce: base64Decode(mediaJson['media_nonce']),
          );

          state = [
            ...state,
            ChatMessage(
              content: mediaJson['file_type'] == 'voice' ? 'Voice Note' : mediaJson['file_name'],
              isMe: true,
              timestamp: DateTime.now(),
              attachments: [attachment],
              messageType: mediaJson['file_type'],
              groupId: groupId,
              expiresAt: expiresAt,
            )
          ];
          return;
        }
      } catch (_) {
        // Not JSON
      }

      state = [
        ...state,
        ChatMessage(
          content: plaintext,
          isMe: true,
          timestamp: DateTime.now(),
          groupId: groupId,
          expiresAt: expiresAt,
        )
      ];
    } catch (e) {
      print('Failed to send group message: $e');
    }
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
      
      // Securely delete local attachments
      final msg = state.firstWhere((m) => m.id == messageId, orElse: () => ChatMessage(content: '', isMe: false, timestamp: DateTime.now()));
      if (msg.attachments.isNotEmpty) {
        for (final attachment in msg.attachments) {
          if (attachment.localPath != null) {
            final file = File(attachment.localPath!);
            if (await file.exists()) {
              // Overwrite with zeros before deleting
              final length = await file.length();
              await file.writeAsBytes(List.filled(length, 0));
              await file.delete();
            }
          }
        }
      }

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
                groupId: msg.groupId, // Preserve group ID
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

  Future<void> markAsRead(int messageId, int senderId) async {
    final ws = ref.read(webSocketServiceProvider);
    ws.sendMessageStatus(messageId, senderId, 'read');
    
    state = [
      for (final msg in state)
        if (msg.id == messageId)
          ChatMessage(
            id: msg.id,
            content: msg.content,
            isMe: msg.isMe,
            timestamp: msg.timestamp,
            status: 'read',
            reactions: msg.reactions,
            attachments: msg.attachments,
            messageType: msg.messageType,
            isStarred: msg.isStarred,
            groupId: msg.groupId,
          )
        else
          msg
    ];
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  Future<void> fetchHistory(int contactId) async {
    try {
      final userId = ref.read(authProvider);
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      // Fetch message history between current user and contact
      final jsonList = await api.getMessageHistory(userId, contactId); 
      
      final newMessages = jsonList.map((j) => ChatMessage.fromJson(j, userId)).toList();
      
      // Merge with existing state avoiding duplicates
      final existingIds = state.map((m) => m.id).toSet();
      final uniqueNewMessages = newMessages.where((m) => m.id != null && !existingIds.contains(m.id)).toList();

      if (uniqueNewMessages.isNotEmpty) {
        state = [...state, ...uniqueNewMessages];
        // Sort by timestamp
        state.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
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
  final userId = ref.watch(authProvider);
  if (userId == null) return [];
  
  final api = ref.read(apiServiceProvider);
  return await api.getUsers(userId);
});

final starredMessagesProvider = FutureProvider<List<ChatMessage>>((ref) async {
  final userId = ref.watch(authProvider);
  if (userId == null) return [];

  final api = ref.read(apiServiceProvider);
  final jsonList = await api.getStarredMessages(userId);
  return jsonList.map((j) => ChatMessage.fromJson(j, userId)).toList();
});

final syncedContactsProvider = FutureProvider<List<dynamic>>((ref) async {
  final userId = ref.watch(authProvider);
  if (userId == null) return [];

  final contactService = ref.read(contactServiceProvider);
  final api = ref.read(apiServiceProvider);

  try {
    final hashedContacts = await contactService.getHashedContacts();
    if (hashedContacts.isEmpty) return [];

    return await api.syncContacts(hashedContacts);
  } catch (e) {
    print('Failed to sync contacts: $e');
    return [];
  }
});
