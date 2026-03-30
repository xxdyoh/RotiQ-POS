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

  static Future<List<Map<String, dynamic>>> getMutasiList({
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
        uri = Uri.parse('$baseUrl/mutasi-out').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/mutasi-out');
      }

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data mutasi out');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getMutasiDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mutasi-out/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail mutasi out');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getGudangList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mutasi-out/gudang'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data gudang');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getCabangTujuanList(String cabangAsalKode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mutasi-out/cabang-tujuan?cabang_asal=$cabangAsalKode'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data cabang tujuan');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getMutasiOutByCabang(String cabangDatabase, String? startDate, String? endDate) async {
    try {
      final Map<String, String> queryParams = {
        'cabang_database': cabangDatabase,
      };

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('$baseUrl/mutasi-in/mutasi-out-list').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data mutasi out');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getMutasiOutDetailFromCabang(String cabangDatabase, String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mutasi-in/mutasi-out-detail/$cabangDatabase/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail mutasi out');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createMutasi(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mutasi-out'),
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
          'message': result['message'] ?? 'Gagal menambah mutasi out',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateMutasi(String nomor, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/mutasi-out/$nomor'),
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
          'message': result['message'] ?? 'Gagal update mutasi out',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteMutasi(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/mutasi-out/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus mutasi out',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getItemsForMutasi({String? search}) async {
    try {
      String url = '$baseUrl/mutasi-out/items';
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
        throw Exception('Gagal mengambil data items');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getDoForStokIn() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/do/available-for-stokin'),
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
}