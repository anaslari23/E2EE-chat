import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(int userId, int deviceId, String token) {
    final wsUrl = ApiService.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/websocket/ws/$userId/$deviceId?token=$token'),
    );

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      _messageController.add(data);
    }, onDone: () {
      print('WebSocket connection closed');
    }, onError: (error) {
      print('WebSocket error: $error');
    });
  }

  void sendMultiDeviceMessage(
    int recipientId, 
    Map<int, String> ciphers, 
    {String type = 'message', int? expirationDuration}
  ) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'recipient_id': recipientId,
        'ciphers': ciphers.map((key, value) => MapEntry(key.toString(), value)),
        'message_type': type,
        'expiration_duration': expirationDuration,
      }));
    }
  }

  void sendGroupMessage(int groupId, String ciphertext, {String type = 'group_message', int? expirationDuration}) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'recipient_group_id': groupId,
        'ciphertext': ciphertext,
        'message_type': type,
        'expiration_duration': expirationDuration,
      }));
    }
  }

  void sendSignalingMessage(int recipientId, int recipientDeviceId, Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'signaling',
        'recipient_id': recipientId,
        'recipient_device_id': recipientDeviceId,
        'data': data,
      }));
    }
  }

  void sendPresence(bool isOnline, {List<int>? contactIds}) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'presence',
        'data': {
          'is_online': isOnline,
        },
        'contact_ids': contactIds,
      }));
    }
  }

  void sendTyping(bool isTyping, int? recipientId, {int? groupId}) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'recipient_id': recipientId,
        'recipient_group_id': groupId,
        'data': {
          'is_typing': isTyping,
        },
      }));
    }
  }

  void sendMessageStatus(int messageId, int recipientId, String status) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'message_status',
        'recipient_id': recipientId,
        'data': {
          'message_id': messageId,
          'status': status,
        },
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
