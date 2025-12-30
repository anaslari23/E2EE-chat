import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  Future<Map<String, dynamic>> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
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
}
