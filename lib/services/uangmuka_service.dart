import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import '../models/uangmuka_model.dart';
import 'api_service.dart';

class UangMukaService {
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

  static Future<Map<String, String>> _getHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> getUangMukaList({
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
        uri = Uri.parse('$baseUrl/uangmuka').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/uangmuka');
      }

      print('Fetching uang muka data from: $uri');

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data uang muka');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getUangMukaDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/uangmuka/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail uang muka');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createUangMuka({
    required String tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/uangmuka'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal,
          'customer': customer,
          'nilai': nilai,
          'jenisBayar': jenisBayar,
          'keterangan': keterangan,
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
          'message': data['message'] ?? 'Gagal menambah uang muka',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateUangMuka({
    required String nomor,
    required String tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/uangmuka/$nomor'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal,
          'customer': customer,
          'nilai': nilai,
          'jenisBayar': jenisBayar,
          'keterangan': keterangan,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal update uang muka',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteUangMuka(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/uangmuka/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus uang muka',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<UangMuka>> getAvailableUangMuka() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/uangmuka'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List).map((json) => UangMuka.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<UangMuka?> searchUangMuka(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/uangmuka/search/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UangMuka.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<bool> markAsRealisasi(String nomor) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/payment/uangmuka/$nomor/realisasi'),
        headers: await _getHeadersWithCabang(),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}