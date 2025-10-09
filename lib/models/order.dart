import 'customer.dart';
import 'order_item.dart';
import 'product.dart';

class Order {
  final String? id;
  final Customer customer;
  final List<OrderItem> items;
  final String paymentMethod; // 'cash' atau 'transfer'
  final double paidAmount;
  final DateTime createdAt;
  final String? userName; // Tambah field untuk nama kasir
  final String? userId;

  Order({
    this.id,
    required this.customer,
    required this.items,
    required this.paymentMethod,
    required this.paidAmount,
    DateTime? createdAt,
    this.userName,
    this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);

  double get change => paymentMethod == 'cash' ? paidAmount - grandTotal : 0;

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customer.id,
      'items': items.map((item) => item.toJson()).toList(),
      'payment_method': paymentMethod,
      'paid_amount': paidAmount,
      'grand_total': grandTotal,
      'change': change,
      'created_at': createdAt.toIso8601String(),
      'user_name': userName,
      "user_id": userId,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString(),
      customer: Customer.fromJson(json['customer']),
      items: (json['items'] as List)
          .map((item) => OrderItem(
        product: Product.fromJson(item['product']),
        quantity: item['quantity'],
        discount: double.parse(item['discount'].toString()),
        notes: item['notes'] ?? '',
      ))
          .toList(),
      paymentMethod: json['payment_method'],
      paidAmount: double.parse(json['paid_amount'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      userName: json['user_name'],
      userId: json['user_id']
    );
  }
}