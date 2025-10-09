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

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category,
    this.image,
    this.discount = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final foto = json['foto'];
    Uint8List? imageBytes;

    if (foto != null) {
      if (foto is String) {
        // base64 string
        imageBytes = base64Decode(foto);
      } else if (foto is Map && foto['data'] != null) {
        // object { data: [...] }
        imageBytes = Uint8List.fromList(List<int>.from(foto['data']));
      } else if (foto is Uint8List) {
        // langsung Uint8List (SQLite)
        imageBytes = foto;
      }
    }

    return Product(
      id: json['id'].toString(),
      name: json['Nama'],
      price: double.parse(json['Price'].toString()),
      stock: int.parse(json['Stok'].toString()),
      category: json['Category'],
      image: imageBytes,
      discount: double.tryParse(json['disc']?.toString() ?? '0') ?? 0,
    );
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
    };
  }
}
