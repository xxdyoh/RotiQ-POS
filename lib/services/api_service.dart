// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/user.dart';

class ApiService {
  // Ganti dengan URL backend Anda
  static const String baseUrl = 'http://103.103.22.7:8099';

  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Login dengan PIN
  static Future<Map<String, dynamic>> login(String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      );
      print("===DEBUG");
      print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          setToken(data['token']);
        }
        return {
          'success': true,
          'token': data['token'],
          'user':  User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'message': jsonDecode(response.body)['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get daftar customers
  static Future<List<Customer>> getCustomers({String? search}) async {
    try {
      String url = '$baseUrl/customers';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Customer> customers = (data['data'] as List)
            .map((json) => Customer.fromJson(json))
            .toList();
        return customers;
      } else {
        throw Exception('Gagal mengambil data customer');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Get daftar products
  static Future<List<Product>> getProducts({String? search}) async {
    try {
      String url = '$baseUrl/products';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Product> products = (data['data'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
        return products;
      } else {
        throw Exception('Gagal mengambil data produk');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Submit order
  static Future<Map<String, dynamic>> submitOrder(Order order) async {
    print("======DEBUG=====");
    print(jsonEncode(order.toJson()));
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _getHeaders(),
        body: jsonEncode(order.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'order_id': data['order_id'],
        };
      } else {
        return {
          'success': false,
          'message': jsonDecode(response.body)['message'] ?? 'Gagal menyimpan order',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Get order detail (untuk generate struk)
  static Future<Order?> getOrderDetail(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Order.fromJson(data['data']);
      } else {
        throw Exception('Gagal mengambil detail order');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }
}

// pubspec.yaml dependencies yang dibutuhkan:
/*
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  pdf: ^3.10.4
  printing: ^5.11.0
  path_provider: ^2.1.1
  share_plus: ^7.2.1
  intl: ^0.18.1
  flutter_barcode_scanner: ^2.1.0 (optional untuk scan barcode)
*/