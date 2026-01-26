import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/setengahjadi.dart';
import 'api_service.dart';
import 'session_manager.dart';

class SetengahJadiService {
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

  static Future<List<SetengahJadi>> getSetengahJadi({String? search}) async {
    try {
      String url = '$baseUrl/setengahjadi';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => SetengahJadi.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil data setengah jadi');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> addSetengahJadi({
    required String nama,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/setengahjadi'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'stj_nama': nama,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal menambah setengah jadi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateSetengahJadi({
    required String stjId,
    required String nama,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/setengahjadi/$stjId'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'stj_nama': nama,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal update setengah jadi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteSetengahJadi(String stjId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/setengahjadi/$stjId'),
        headers: await _getHeadersWithCabang(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal hapus setengah jadi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}