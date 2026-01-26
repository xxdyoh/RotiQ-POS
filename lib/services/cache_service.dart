import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _productsKey = 'cached_products';
  static const String _imagesKeyPrefix = 'cached_image_';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  static Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'products': products,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_productsKey, jsonEncode(cacheData));
      print('✅ Products cached: ${products.length} items');
    } catch (e) {
      print('❌ Error caching products: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_productsKey);

      if (cached != null) {
        final cacheData = jsonDecode(cached);
        final timestamp = cacheData['timestamp'] as int?;
        final productsData = cacheData['products'];

        if (timestamp == null || productsData == null || productsData is! List) {
          await prefs.remove(_productsKey);
          return null;
        }

        final age = DateTime.now().millisecondsSinceEpoch - timestamp;

        if (age <= _cacheDuration.inMilliseconds) {
          final List<Map<String, dynamic>> validProducts = [];
          for (final item in productsData) {
            if (item is Map<String, dynamic>) {
              if (item['id'] != null && item['Nama'] != null) {
                validProducts.add(item);
              }
            }
          }

          if (validProducts.isNotEmpty) {
            return validProducts;
          } else {
            print('🗑️ No valid items in cache, clearing...');
            await prefs.remove(_productsKey);
          }
        } else {
          await prefs.remove(_productsKey);
          print('🗑️ Cache expired, cleared');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error reading cache: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_productsKey);
      } catch (_) {}
      return null;
    }
  }

  static Future<void> cacheImage(String productId, String imageHash, Uint8List imageData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_imagesKeyPrefix$productId';

      final cacheData = {
        'image': base64Encode(imageData),
        'hash': imageHash,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      print('❌ Error caching image for $productId: $e');
    }
  }

  static Future<Uint8List?> getCachedImage(String productId, String currentHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_imagesKeyPrefix$productId';
      final cached = prefs.getString(cacheKey);

      if (cached != null) {
        final cacheData = jsonDecode(cached);
        final cachedHash = cacheData['hash'] as String;
        final timestamp = cacheData['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;

        if (cachedHash == currentHash && age <= _cacheDuration.inMilliseconds) {
          final imageBase64 = cacheData['image'] as String;
          final imageData = base64Decode(imageBase64);
          return imageData;
        } else {
          await prefs.remove(cacheKey);
          print('🗑️ Image cache invalid/expired for: $productId');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error reading image cache for $productId: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_imagesKeyPrefix) || key == _productsKey || key == _cacheTimestampKey) {
          await prefs.remove(key);
        }
      }
      print('🧹 All cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  static Future<Map<String, dynamic>> getCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    int imageCount = 0;
    for (final key in keys) {
      if (key.startsWith(_imagesKeyPrefix)) {
        imageCount++;
      }
    }

    return {
      'total_cached_images': imageCount,
      'has_products_cache': prefs.containsKey(_productsKey),
    };
  }
}