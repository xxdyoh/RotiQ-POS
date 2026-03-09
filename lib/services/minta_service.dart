import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class MintaService {
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

  static Future<List<Map<String, dynamic>>> getMintaList({
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
        uri = Uri.parse('$baseUrl/minta').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/minta');
      }

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Gagal mengambil data permintaan barang');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getMintaDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/minta/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail permintaan barang');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getItemsForMinta({String? search}) async {
    try {
      String url = '$baseUrl/minta-items';
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

  static Future<Map<String, dynamic>> createMinta(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/minta'),
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
          'message': result['message'] ?? 'Gagal menambah permintaan barang',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateMinta(Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/minta/${data['nomor']}'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': data['tanggal'],
          'keterangan': data['keterangan'],
          'items': data['items'],
        }),
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
          'message': result['message'] ?? 'Gagal update permintaan barang',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteMinta(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/minta/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus permintaan barang',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> searchItems({String? search}) async {
    try {
      String url = '$baseUrl/minta-items-search';
      final Map<String, String> queryParams = {};

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      Uri uri = Uri.parse(url).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Gagal mencari items');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }
}