import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class SpkService {
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

  static Future<List<Map<String, dynamic>>> getSpkList({
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
        uri = Uri.parse('$baseUrl/spk').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/spk');
      }

      final response = await http.get(
        uri,
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
        Uri.parse('$baseUrl/spk/$nomor'),
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

  static Future<Map<String, dynamic>> createSpkFromMinta({
    required String tanggal,
    String? keterangan,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spk/from-minta'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal,
          'keterangan': keterangan,
        }),
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
          'message': result['message'] ?? 'Gagal membuat SPK',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getSpkDetailForExport(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/spk/$nomor/export'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil detail SPK untuk export');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error getSpkDetailForExport: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateSpk(String nomor, String keterangan) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/spk/$nomor'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({'keterangan': keterangan}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': result['message'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal update SPK',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteSpk(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/spk/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus SPK',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> checkSpkByDate(String tanggal) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/spk/check-by-date?tanggal=$tanggal'),
        headers: await _getHeadersWithCabang(),
      );

      print("Check SPK");
      print(tanggal);
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'exists': data['exists'] ?? false,
          'data': data['data'],
          'message': data['message'] ?? '',
        };
      } else {
        return {
          'success': false,
          'exists': false,
          'message': 'Gagal cek SPK',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'exists': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}