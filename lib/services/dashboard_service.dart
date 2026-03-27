import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/dashboard_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class DashboardService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    final cabang = SessionManager.getCurrentCabang();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (cabang != null) 'X-Cabang-Kode': cabang.kode,
    };
  }

  static Future<DashboardResponse> getDashboardData({
    required DateTime startDate,
    required DateTime endDate,
    required String groupBy,
    String? cabangKode,
    String? jenis,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/dashboard/data?'
          'start_date=${DateFormat('yyyy-MM-dd').format(startDate)}'
          '&end_date=${DateFormat('yyyy-MM-dd').format(endDate)}'
          '&group_by=$groupBy';

      if (cabangKode != null && cabangKode.isNotEmpty && cabangKode != 'all') {
        url += '&cabang_kode=$cabangKode';
      }
      if (jenis != null && jenis.isNotEmpty && jenis != 'all') {
        url += '&jenis=$jenis';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return DashboardResponse.fromJson(data);
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data dashboard');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getDashboardData: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getCabangList() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/cabang-list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data cabang');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getCabangList: $e');
      rethrow;
    }
  }
}