import 'dart:convert';
import 'dart:typed_data';

class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String? category;
  final Uint8List? image;
  final double discount;
  final String? imageHash;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category,
    this.image,
    this.discount = 0,
    this.imageHash,
  });

  // Factory untuk data minimal (dengan null safety)
  factory Product.fromJsonMinimal(Map<String, dynamic> json) {
    return Product(
      id: _parseString(json['id']),
      name: _parseString(json['Nama']),
      price: _parseDouble(json['Price']),
      stock: _parseInt(json['Stok']),
      category: _parseString(json['Category']),
      image: null,
      discount: _parseDouble(json['disc']),
      imageHash: _parseString(json['image_hash']),
    );
  }

  // Factory existing (dengan null safety)
  factory Product.fromJson(Map<String, dynamic> json) {
    final foto = json['foto'];
    Uint8List? imageBytes;

    if (foto != null) {
      if (foto is String) {
        imageBytes = base64Decode(foto);
      } else if (foto is Map && foto['data'] != null) {
        imageBytes = Uint8List.fromList(List<int>.from(foto['data']));
      } else if (foto is Uint8List) {
        imageBytes = foto;
      }
    }

    return Product(
      id: _parseString(json['id']),
      name: _parseString(json['Nama']),
      price: _parseDouble(json['Price']),
      stock: _parseInt(json['Stok']),
      category: _parseString(json['Category']),
      image: imageBytes,
      discount: _parseDouble(json['disc']),
      imageHash: _parseString(json['image_hash']),
    );
  }

  // Helper methods untuk null safety
  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      'foto': image != null ? base64Encode(image!) : null,
      'disc': discount,
      'image_hash': imageHash,
    };
  }

  bool get hasImage {
    if (imageHash == null) return false;
    if (imageHash!.isEmpty) return false;
    if (imageHash == "d41d8cd98f00b204e9800998ecf8427e") return false;
    return true;
  }
}
