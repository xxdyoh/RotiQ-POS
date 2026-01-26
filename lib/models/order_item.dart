import 'product.dart';

class OrderItem {
  final Product product;
  int quantity;
  double discount;
  double discountRp;
  String discountType;
  String notes;

  OrderItem({
    required this.product,
    required this.quantity,
    this.discount = 0,
    this.discountRp = 0,
    this.discountType = 'none',
    this.notes = '',
  });

  double get subtotal => product.price * quantity;

  double get discountAmount {
    if (discountType == 'rp') {
      return discountRp * quantity;
    } else if (discountType == 'percent') {
      return subtotal * (discount / 100);
    }
    return 0;
  }

  double get total => subtotal - discountAmount;

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'price': product.price,
      'quantity': quantity,
      'discount': discount,
      'discount_rp': discountRp,
      'disc_type': discountType,
      'notes': notes,
      'subtotal': subtotal,
      'total': total,
      'discount_amount': discountAmount,
    };
  }
}