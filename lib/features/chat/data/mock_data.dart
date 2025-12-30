class ChatModel {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final String avatarUrl;

  ChatModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.avatarUrl = '',
  });
}

class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });
}

final List<ChatModel> mockChats = [
  ChatModel(
    id: '1',
    name: 'Alice',
    lastMessage: 'Hey, did you see the new Signal protocol update?',
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
  ),
  ChatModel(
    id: '2',
    name: 'Bob',
    lastMessage: 'Let\'s meet at 2 PM.',
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  ChatModel(
    id: '3',
    name: 'Project Group',
    lastMessage: 'Encryption is finished!',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final List<MessageModel> mockMessages = [
  MessageModel(
    id: '1',
    senderId: 'Alice',
    content: 'Hi there!',
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    isMe: false,
  ),
  MessageModel(
    id: '2',
    senderId: 'me',
    content: 'Hello Alice! How are you?',
    timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
    isMe: true,
  ),
  MessageModel(
    id: '3',
    senderId: 'Alice',
    content: 'I am good. Excited about our secure chat app!',
    timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
    isMe: false,
  ),
];
