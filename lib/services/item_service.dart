import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/item_setengahjadi_detail.dart';
import '../services/session_manager.dart';

class ItemService {
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

  static Future<List<Map<String, dynamic>>> getItems({String? search}) async {
    try {
      String url = '$baseUrl/products';
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
        throw Exception('Gagal mengambil data items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> getItemSetengahJadiDetails(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/items/$itemId/setengah-jadi'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil detail setengah jadi');
        }
      } else {
        throw Exception('Gagal mengambil detail setengah jadi (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> updateItemSetengahJadiDetails({
    required int itemId,
    required List<ItemSetengahJadiDetail> details,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/items/$itemId/setengah-jadi'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'details': details.map((detail) => detail.toJson()).toList(),
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
          'message': data['message'] ?? 'Gagal update detail setengah jadi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> addItem({
    required String name,
    required String category,
    required double price,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/items'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'item_nama': name,
          'item_category': category,
          'item_harga': price,
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
          'message': data['message'] ?? 'Gagal menambah item',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateItem({
    required String itemId,
    required String name,
    required String category,
    required double price,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/items/$itemId'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'item_nama': name,
          'item_category': category,
          'item_harga': price,
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
          'message': data['message'] ?? 'Gagal update item',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteItem(String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/items/$itemId'),
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
          'message': data['message'] ?? 'Gagal hapus item',
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