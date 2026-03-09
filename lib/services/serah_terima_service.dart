import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class SerahTerimaService {
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

  static Future<List<Map<String, dynamic>>> getSerahTerimaList({
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final Map<String, String> queryParams = {};

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      Uri uri;
      if (queryParams.isNotEmpty) {
        uri = Uri.parse('$baseUrl/serah-terima').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/serah-terima');
      }

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data serah terima');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getSerahTerimaDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/serah-terima/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail serah terima');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getSpkList({String? search}) async {
    try {
      String url = '$baseUrl/spk-list';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data SPK');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getSpkDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/spk-list/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail SPK');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createSerahTerima(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/serah-terima'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode(data),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': result['data'],
          'message': result['message'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal menambah serah terima',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateSerahTerima(String nomor, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/serah-terima/$nomor'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode(data),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': result['data'],
          'message': result['message'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal update serah terima',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteSerahTerima(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/serah-terima/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus serah terima',
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