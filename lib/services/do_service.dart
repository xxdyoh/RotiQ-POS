import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class DoService {
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

  static Future<List<Map<String, dynamic>>> getDoList({
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
        uri = Uri.parse('$baseUrl/do').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/do');
      }

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data pengiriman');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getDoDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/do/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail pengiriman');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getMintaListByCabang({
    required String cabangDatabase,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/do/minta-by-cabang').replace(queryParameters: {
        'cabang_database': cabangDatabase,
        'start_date': startDate,
        'end_date': endDate,
      });

      print(cabangDatabase + ' - ' + startDate + ' - ' + endDate);

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data permintaan');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getMintaDetailFromCabang({
    required String cabangDatabase,
    required String nomor,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/do/minta-detail/$cabangDatabase/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail permintaan');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createDo(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/do'),
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
          'message': result['message'] ?? 'Gagal menambah pengiriman',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateDo(String nomor, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/do/$nomor'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode(data),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': result['message'],
          'data': result['data'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal update pengiriman',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteDo(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/do/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus pengiriman',
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