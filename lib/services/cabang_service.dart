import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cabang_model.dart';
import 'api_service.dart';

class CabangService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<List<Cabang>> getCabangList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cabang'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<Cabang> cabangList = (data['data'] as List)
              .map((json) => Cabang.fromJson(json))
              .toList();
          return cabangList;
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data cabang');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching cabang: $e');
      rethrow;
    }
  }

  static Future<Cabang?> getCabangByKode(String kode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cabang/$kode'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Cabang.fromJson(data['data']);
        } else {
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error fetching cabang detail: $e');
      return null;
    }
  }
}