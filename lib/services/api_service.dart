import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'cache_service.dart';
import '../models/cabang_model.dart';
import 'session_manager.dart';

class ApiService {
  static const String baseUrl = 'http://103.103.22.7:8094';

  static String? _token;
  static Cabang? _currentCabang;  

  static void setToken(String token) {
    _token = token;
  }

  static void clearToken() {
    _token = null;
    _currentCabang = null;
  }

  static void setCurrentCabang(Cabang cabang) {
    _currentCabang = cabang;
  }

  static Cabang? getCurrentCabang() {
    return _currentCabang;
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
      if (_currentCabang != null) 'X-Cabang-Kode': _currentCabang!.kode,
    };
  }

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

  static Future<Map<String, dynamic>> login(String cbgKode, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cbg_kode': cbgKode,
          'pin': pin,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final user = User.fromJson(Map<String, dynamic>.from(data['data']['user']));
          setToken(data['data']['token']);

          if (user.cabang != null) {
            setCurrentCabang(user.cabang!);
          }

          return {
            'success': true,
            'token': data['data']['token'],
            'user': user,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login gagal',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> loginWithData(Map<String, dynamic> loginData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final user = User.fromJson(Map<String, dynamic>.from(data['data']['user']));
          setToken(data['data']['token']);

          if (user.cabang != null) {
            setCurrentCabang(user.cabang!);
          }

          return {
            'success': true,
            'token': data['data']['token'],
            'user': user,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login gagal',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<Cabang>> getCabangList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cabang'),
        headers: {'Content-Type': 'application/json'},
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

  static Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _getHeaders(),
        body: jsonEncode(orderData),
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

  static Future<Map<String, dynamic>> getOrdersByDate({
    required DateTime startDate,
    required DateTime endDate,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders?'
            'start_date=${DateFormat('yyyy-MM-dd').format(startDate)}'
            '&end_date=${DateFormat('yyyy-MM-dd').format(endDate)}'
            '&user_id=$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'total_orders': data['total_orders'],
          'total_sales': data['total_sales'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Gagal mengambil data orders',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<List<Product>> getProductsMinimal({String? search}) async {
    try {
      String url = '$baseUrl/products-minimal';
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
            .map((json) => Product.fromJsonMinimal(json)) // Pakai factory baru
            .toList();
        return products;
      } else {
        throw Exception('Gagal mengambil data produk');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  static Future<Uint8List?> getProductImage(String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/image'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final imageData = data['data'];

          if (imageData['image'] is Map<String, dynamic>) {
            final bufferData = imageData['image'];
            if (bufferData['type'] == 'Buffer' && bufferData['data'] is List) {
              final List<dynamic> dynamicList = bufferData['data'];
              final List<int> intList = dynamicList.cast<int>().toList();
              final Uint8List imageBytes = Uint8List.fromList(intList);

              return imageBytes;
            }
          }

          if (imageData['image'] is String) {
            return base64Decode(imageData['image']);
          }
        }
      } else {
        print('❌ Image API error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('❌ Error loading image for $productId: $e');
      return null;
    }
  }

  static Future<List<Product>> getProductsOptimized({String? search, bool useCache = true}) async {
    try {
      if (useCache && (search == null || search.isEmpty)) {
        try {
          final cachedProducts = await CacheService.getCachedProducts();
          if (cachedProducts != null && cachedProducts.isNotEmpty) {
            final products = cachedProducts.map((json) => Product.fromJsonMinimal(json)).toList();
            return products;
          }
        } catch (cacheError) {
          print('⚠️ Cache error, falling back to API: $cacheError');
        }
      }

      final products = await getProductsMinimal(search: search);

      if (search == null || search.isEmpty) {
        try {
          final productsJson = products.map((p) => p.toJson()).toList();
          await CacheService.cacheProducts(productsJson);
        } catch (cacheError) {
          print('⚠️ Error caching products: $cacheError');
        }
      }

      return products;
    } catch (e) {
      print('❌ Error in getProductsOptimized: $e');

      try {
        return await getProductsMinimal(search: search);
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }



  static Future<String?> getToken() async {
    return _token;
  }
}