import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class PengumumanService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> getActive() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pengumuman/active'),
        // tanpa headers auth
      );
      print('hasil api: ${response.body}');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body)['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}