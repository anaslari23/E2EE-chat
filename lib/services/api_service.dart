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
}
