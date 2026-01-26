import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tutup_kasir_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class TutupKasirService {
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
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> cekSetoranAda(DateTime tanggal, String userKode) async {
    try {
      final tanggalStr = tanggal.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('$baseUrl/tutup-kasir/cek?tanggal=$tanggalStr&user_kode=$userKode'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['exists'] ?? false;
      } else {
        throw Exception('Gagal mengecek setoran');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<SummaryPenjualan> getSummaryPenjualan(DateTime tanggal, String userKode) async {
    try {
      final tanggalStr = tanggal.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('$baseUrl/tutup-kasir/summary?tanggal=$tanggalStr&user_kode=$userKode'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SummaryPenjualan.fromJson(data['data']);
      } else {
        throw Exception('Gagal mengambil summary penjualan');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Profile> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Profile.fromJson(data['data']);
      } else {
        throw Exception('Gagal mengambil data profile');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> prosesTutupKasir({
    required DateTime tanggal,
    required String userKode,
    required double setoran,
    String? kodeOtorisasi,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tutup-kasir'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal.toIso8601String().split('T')[0],
          'user_kode': userKode,
          'setoran': setoran,
          'kode_otorisasi': kodeOtorisasi,
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
          'message': data['message'] ?? 'Gagal proses tutup kasir',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<TutupKasir>> getHistoryTutupKasir({String? userKode, DateTime? startDate, DateTime? endDate}) async {
    try {
      String url = '$baseUrl/tutup-kasir/history';
      List<String> params = [];

      if (userKode != null && userKode.isNotEmpty) {
        params.add('user_kode=$userKode');
      }
      if (startDate != null) {
        params.add('start_date=${startDate.toIso8601String().split('T')[0]}');
      }
      if (endDate != null) {
        params.add('end_date=${endDate.toIso8601String().split('T')[0]}');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => TutupKasir.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil history tutup kasir');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getStrukTutupKasir(DateTime tanggal, String userKode, String nmUser) async {
    try {
      final tanggalStr = tanggal.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('$baseUrl/tutup-kasir/struk?tanggal=$tanggalStr&user_kode=$userKode&nm_user=$nmUser'),
        headers: await _getHeadersWithCabang(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil data struk',
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