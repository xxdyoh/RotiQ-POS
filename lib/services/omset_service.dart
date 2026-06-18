import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class OmsetService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, dynamic>> getOmset({
    required String tahun,
    required String tipe,
    required String cabangKode,
  }) async {
    try {
      final token = await ApiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/report/omset?tahun=$tahun&tipe=$tipe'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          'X-Cabang-Kode': cabangKode,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Gagal mengambil data omset');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }
}