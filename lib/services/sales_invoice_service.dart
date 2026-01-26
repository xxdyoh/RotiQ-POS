import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'session_manager.dart';

class SalesInvoiceService {
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

  static Future<Map<String, dynamic>> getSalesByInvoice({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? selectedPromos,
  }) async {
    try {
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      String url = '$baseUrl/report/sales-by-invoice?start_date=$startStr&end_date=$endStr';

      if (selectedPromos != null && selectedPromos.isNotEmpty) {
        final promosParam = selectedPromos.join(',');
        url += '&promos=$promosParam';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Gagal mengambil data sales by invoice');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<String>> getPromos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/report/promos'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data promos');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}