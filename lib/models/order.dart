import 'customer.dart';
import 'order_item.dart';
import 'product.dart';

class Order {
  final String? id;
  final Customer customer;
  final List<OrderItem> items;
  final String paymentMethod;
  final double paidAmount;
  final DateTime createdAt;
  final String? userName;
  final String? userId;
  final double globalDiscount;        // persentase diskon order
  final double globalDiscountAmount;  // nominal diskon order ✅ BARU
  final double subtotalBeforeDiscount; // sebelum diskon order ✅ BARU

  Order({
    this.id,
    required this.customer,
    required this.items,
    required this.paymentMethod,
    required this.paidAmount,
    DateTime? createdAt,
    this.userName,
    this.userId,
    this.globalDiscount = 0,
    this.globalDiscountAmount = 0,    // ✅ DEFAULT
    this.subtotalBeforeDiscount = 0,  // ✅ DEFAULT
  }) : createdAt = createdAt ?? DateTime.now();

  // ✅ PERHITUNGAN YANG BENAR:
  // 1. Hitung subtotal (harga asli item × quantity)
  double get subtotal {
    final raw = items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    return _roundToNearest(raw);
  }

  double get itemDiscounts {
    final raw = items.fold(0.0, (sum, item) => sum + item.discountAmount);
    return _roundToNearest(raw);
  }

  double get totalAfterItemDiscounts {
    final raw = subtotal - itemDiscounts;
    return _roundToNearest(raw);
  }

  double get orderDiscountAmount {
    final raw = totalAfterItemDiscounts * (globalDiscount / 100);
    return _roundToNearest(raw);
  }

  double get grandTotal {
    final raw = totalAfterItemDiscounts - orderDiscountAmount;
    return _roundToNearest(raw);
  }

  double get change {
    if (paymentMethod == 'cash') {
      final raw = paidAmount - grandTotal;
      return _roundToNearest(raw);
    }
    return 0;
  }

  double _roundToNearest(double value) {
    return (value).roundToDouble(); // Round to nearest integer
  }
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
      "global_discount": globalDiscount,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsData = json['items'] as List;

    // Handle customer data
    Customer customer;
    if (json['customer'] is Map) {
      final customerData = json['customer'] as Map<String, dynamic>;
      customer = Customer(
        id: customerData['id']?.toString() ?? 'Unknown',
        name: customerData['name']?.toString() ?? 'Unknown Customer',
        phone: customerData['phone']?.toString() ?? '-',
      );
    } else {
      customer = Customer(
        id: 'unknown',
        name: 'Unknown Customer',
        phone: '-',
      );
    }

    return Order(
      id: json['id']?.toString(),
      customer: customer,
      items: itemsData.map<OrderItem>((item) {
        return OrderItem(
          product: Product(
            id: item['product_id']?.toString() ?? '',
            name: item['product_name']?.toString() ?? 'Unknown Product',
            price: double.parse(item['price']?.toString() ?? '0'),
            stock: int.parse(item['stock']?.toString() ?? '0'),
          ),
          quantity: int.parse(item['quantity']?.toString() ?? '1'),
          discount: double.tryParse(item['discount']?.toString() ?? '0') ?? 0,
          notes: item['notes']?.toString() ?? '',
        );
      }).toList(),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      paidAmount: double.parse(json['paid_amount']?.toString() ?? '0'),
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      userName: json['user_name']?.toString() ?? 'Unknown',
      userId: json['user_id']?.toString() ?? 'Unknown',
      // ✅ DATA BARU DARI API
      globalDiscount: double.tryParse(json['global_discount']?.toString() ?? '0') ?? 0,
      globalDiscountAmount: double.tryParse(json['global_discount_amount']?.toString() ?? '0') ?? 0,
      subtotalBeforeDiscount: double.tryParse(json['subtotal_before_discount']?.toString() ?? '0') ?? 0,
    );
  }
}