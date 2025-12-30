import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(int userId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/ws/$userId'),
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

  void sendMessage(int recipientId, String content) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'recipient_id': recipientId,
        'content': content,
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
