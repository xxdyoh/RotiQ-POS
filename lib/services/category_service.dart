import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class CategoryService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<Map<String, String>> _getHeadersWithCabang() async {
    final token = SessionManager.getToken();
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

  static Future<List<Map<String, dynamic>>> getCategories({String? search}) async {
    try {
      String url = '$baseUrl/categories';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cabang = SessionManager.getCurrentCabang();

        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data kategori: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> addCategory({
    required String name,
    required String printerName,
    required bool isPrint,
    required double discount,
    required double discountRp,
    required String discountType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'ct_nama': name,
          'ct_PrinterName': printerName,
          'ct_isprint': isPrint,
          'ct_disc': discount,
          'ct_disc_rp': discountRp,
          'disc_type': discountType,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final cabang = SessionManager.getCurrentCabang();

        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal menambah kategori',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateCategory({
    required String categoryId,
    required String name,
    required String printerName,
    required bool isPrint,
    required double discount,
    required double discountRp,
    required String discountType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/categories/$categoryId'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'ct_nama': name,
          'ct_PrinterName': printerName,
          'ct_isprint': isPrint,
          'ct_disc': discount,
          'ct_disc_rp': discountRp,
          'disc_type': discountType,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final cabang = SessionManager.getCurrentCabang();

        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal update kategori',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(String categoryId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/categories/$categoryId'),
        headers: await _getHeadersWithCabang(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final cabang = SessionManager.getCurrentCabang();

        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal hapus kategori',
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