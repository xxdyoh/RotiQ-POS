import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'api_service.dart';

class KoreksiService {
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

  static Future<List<Map<String, dynamic>>> getKoreksiList({
    String? search,
    String? startDate,
    String? endDate,
  }) async {
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

    Uri uri = Uri.parse('$baseUrl/koreksi').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: await _getHeadersWithCabang(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception('Gagal mengambil data koreksi stock');
    }
  }

  static Future<Map<String, dynamic>> getKoreksiDetail(String nomor) async {
    final response = await http.get(
      Uri.parse('$baseUrl/koreksi/$nomor'),
      headers: await _getHeadersWithCabang(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Gagal mengambil detail koreksi stock');
    }
  }

  static Future<double> getStokSistem(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/koreksi-stok-sistem?item_id=$itemId'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stok = data['data']?['stok_sistem'];
        if (stok != null) {
          return (stok).toDouble();
        }
        return 0.0;
      } else {
        return 0.0;
      }
    } catch (e) {
      print('Error getStokSistem: $e');
      return 0.0;
    }
  }

  static Future<List<Map<String, dynamic>>> getItemsForKoreksi({String? search}) async {
    String url = '$baseUrl/koreksi-items';
    if (search != null && search.isNotEmpty) {
      url += '?search=$search';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeadersWithCabang(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = List<Map<String, dynamic>>.from(data['data']);

      return items.map((item) {
        return {
          'item_id': item['item_id'] ?? 0,
          'item_nama': item['item_nama']?.toString() ?? '',
          'item_hpp': (item['item_hpp'] ?? 0).toDouble(),
        };
      }).toList();
    } else {
      throw Exception('Gagal mengambil data items');
    }
  }

  static Future<Map<String, dynamic>> createKoreksi(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/koreksi'),
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
        'message': result['message'] ?? 'Gagal menambah koreksi stock',
      };
    }
  }

  static Future<Map<String, dynamic>> updateKoreksi(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/koreksi/${data['nomor']}'),
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
        'message': result['message'] ?? 'Gagal update koreksi stock',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteKoreksi(String nomor) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/koreksi/$nomor'),
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
        'message': data['message'] ?? 'Gagal hapus koreksi stock',
      };
    }
  }
}