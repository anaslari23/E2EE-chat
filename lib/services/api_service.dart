import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  Future<void> requestOtp(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to request OTP: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'code': code,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify OTP: ${response.body}');
    }
  }

  Future<void> uploadPreKeyBundle(int userId, int deviceId, Map<String, dynamic> bundle) async {
    final response = await http.post(
      Uri.parse('$baseUrl/keys/upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'device_id': deviceId,
        'bundle': bundle,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload bundle: ${response.body}');
    }
  }

  Future<List<dynamic>> getPreKeyBundles(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/keys/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch bundles: ${response.body}');
    }
  }

  Future<List<dynamic>> getPendingMessages(int deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/pending/$deviceId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch pending messages: ${response.body}');
    }
  }

  Future<void> editMessage(int messageId, String ciphertext) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/$messageId/edit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ciphertext': ciphertext}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to edit message: ${response.body}');
    }
  }

  Future<void> deleteMessage(int messageId, {bool forEveryone = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/$messageId/delete?for_everyone=$forEveryone'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete message: ${response.body}');
    }
  }

  Future<void> reactToMessage(int messageId, int userId, String emoji) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/$messageId/react?user_id=$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'emoji': emoji}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add reaction: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadMedia(
    int messageId,
    String fileType,
    List<int> bytes,
    String fileName,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/media/upload?message_id=$messageId&file_type=$fileType'),
    );

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload media: ${response.body}');
    }
  }

  Future<List<int>> downloadMedia(int attachmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/media/download/$attachmentId'),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download media: ${response.body}');
    }
  }

  Future<void> toggleStarMessage(int messageId, int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/$messageId/star?user_id=$userId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle star: ${response.body}');
    }
  }

  Future<List<dynamic>> getStarredMessages(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/starred/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch starred messages: ${response.body}');
    }
  }

  Future<void> togglePinChat(String chatId, int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/pin?user_id=$userId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle pin: ${response.body}');
    }
  }

  Future<void> toggleArchiveChat(String chatId, int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/archive?user_id=$userId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle archive: ${response.body}');
    }
  }

  Future<void> muteChat(String chatId, int userId, int? durationMinutes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/mute?user_id=$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'duration_minutes': durationMinutes}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mute chat: ${response.body}');
    }
  }

  Future<List<dynamic>> getChatSettings(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chats/settings/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch chat settings: ${response.body}');
    }
  }
}
