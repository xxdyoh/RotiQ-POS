import 'product.dart';

class OrderItem {
  final Product product;
  int quantity;
  double discount;
  String notes;

  OrderItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.notes = '',
  });

  double get subtotal => product.price * quantity;

  double get discountAmount => subtotal * (discount / 100);

  double get total => subtotal - discountAmount;

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'price': product.price,
      'quantity': quantity,
      'discount': discount,
      'notes': notes,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total': total,
    };
  }
}