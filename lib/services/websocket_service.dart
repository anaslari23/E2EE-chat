import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(int userId, int deviceId, String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/api/v1/websocket/ws/$userId/$deviceId?token=$token'),
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
    {String type = 'message'}
  ) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'recipient_id': recipientId,
        'ciphers': ciphers.map((key, value) => MapEntry(key.toString(), value)),
        'message_type': type,
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

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
