import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class MintaReportService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, String>> _getHeadersWithCabang() async {
    final token = await ApiService.getToken();
    final cabang = SessionManager.getCurrentCabang();

    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    if (cabang != null) {
      headers['X-Cabang-Kode'] = cabang.kode;
      headers['X-Cabang-Nama'] = cabang.nama;
    }

    return headers;
  }

  static Future<Map<String, dynamic>> getMintaReport({
    required DateTime selectedDate,
  }) async {
    try {
      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse('$baseUrl/report/minta').replace(queryParameters: {
        'start_date': dateStr,
        'end_date': dateStr,
      });

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
          'message': data['message'] ?? 'Berhasil mengambil data',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Gagal mengambil data',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}