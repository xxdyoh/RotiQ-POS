import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jurnal_model.dart';
import 'api_service.dart';
import 'session_manager.dart';

class JurnalService {
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

  static Future<List<JurnalHeader>> getJurnalList({
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
        uri = Uri.parse('$baseUrl/jurnal').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('$baseUrl/jurnal');
      }

      print('Fetching jurnal data from: $uri');

      final response = await http.get(
        uri,
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => JurnalHeader.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil data biaya lain-lain');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getJurnalDetail(String nomor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/jurnal/$nomor'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil detail biaya lain-lain');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Rekening>> getRekeningForHeader(String jenis) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/jurnal-rekening-header?jenis=$jenis'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => Rekening.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil data rekening header');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<Rekening>> getRekeningForDetail() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/jurnal-rekening-detail'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => Rekening.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil data rekening detail');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<List<CostCenter>> getCostCenter() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/jurnal-costcenter'),
        headers: await _getHeadersWithCabang(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List)
            .map((json) => CostCenter.fromJson(json))
            .toList();
      } else {
        throw Exception('Gagal mengambil data cost center');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> createJurnal({
    required String tanggal,
    required String jenis,
    required String accountHeader,
    required String keteranganHeader,
    required double nilaiHeader,
    required List<Map<String, dynamic>> details,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/jurnal'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal,
          'jenis': jenis,
          'account_header': accountHeader,
          'keterangan_header': keteranganHeader,
          'nilai_header': nilaiHeader,
          'details': details,
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
          'message': data['message'] ?? 'Gagal menambah biaya lain-lain',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updateJurnal({
    required String nomor,
    required String tanggal,
    required String jenis,
    required String accountHeader,
    required String keteranganHeader,
    required double nilaiHeader,
    required List<Map<String, dynamic>> details,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/jurnal/$nomor'),
        headers: await _getHeadersWithCabang(),
        body: jsonEncode({
          'tanggal': tanggal,
          'jenis': jenis,
          'account_header': accountHeader,
          'keterangan_header': keteranganHeader,
          'nilai_header': nilaiHeader,
          'details': details,
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
          'message': data['message'] ?? 'Gagal update biaya lain-lain',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteJurnal(String nomor) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/jurnal/$nomor'),
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
          'message': data['message'] ?? 'Gagal hapus biaya lain-lain',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}