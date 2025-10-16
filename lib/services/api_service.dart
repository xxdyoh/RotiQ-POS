import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'cache_service.dart';

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

      print('🔄 Image API Response for $productId: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Image API Success: ${data['success']}');

        if (data['success'] == true && data['data'] != null) {
          final imageData = data['data'];

          // Handle Buffer format: {"type":"Buffer","data":[255,216,255,224,...]}
          if (imageData['image'] is Map<String, dynamic>) {
            final bufferData = imageData['image'];
            if (bufferData['type'] == 'Buffer' && bufferData['data'] is List) {
              // Convert List<dynamic> to List<int> then to Uint8List
              final List<dynamic> dynamicList = bufferData['data'];
              final List<int> intList = dynamicList.cast<int>().toList();
              final Uint8List imageBytes = Uint8List.fromList(intList);

              print('✅ Image loaded as Buffer: ${imageBytes.length} bytes');
              return imageBytes;
            }
          }

          // Fallback: handle jika format berbeda
          if (imageData['image'] is String) {
            // Base64 string
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
      // Jika search kosong, coba dari cache dulu
      if (useCache && (search == null || search.isEmpty)) {
        try {
          final cachedProducts = await CacheService.getCachedProducts();
          if (cachedProducts != null && cachedProducts.isNotEmpty) {
            final products = cachedProducts.map((json) => Product.fromJsonMinimal(json)).toList();
            print('✅ Loaded from cache: ${products.length} items');
            return products;
          }
        } catch (cacheError) {
          print('⚠️ Cache error, falling back to API: $cacheError');
          // Continue to API call
        }
      }

      // Jika tidak ada cache atau cache error, ambil dari API
      print('🌐 Fetching from API...');
      final products = await getProductsMinimal(search: search);

      // Cache data untuk下次使用 (jika bukan search)
      if (search == null || search.isEmpty) {
        try {
          final productsJson = products.map((p) => p.toJson()).toList();
          await CacheService.cacheProducts(productsJson);
          print('💾 Cached ${productsJson.length} items');
        } catch (cacheError) {
          print('⚠️ Error caching products: $cacheError');
        }
      }

      return products;
    } catch (e) {
      print('❌ Error in getProductsOptimized: $e');

      // Fallback strategy
      try {
        print('🔄 Fallback: trying without cache...');
        return await getProductsMinimal(search: search);
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');

        // Last resort: return empty list
        print('🔄 Returning empty list as last resort');
        return [];
      }
    }
  }
}