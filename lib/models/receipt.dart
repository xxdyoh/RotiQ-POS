class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['name'],
      quantity: map['quantity'],
      price: map['price'].toDouble(),
      total: map['total'].toDouble(),
    );
  }
}

class Receipt {
  final String id;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final DateTime date;
  final String transactionId;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double grandTotal;
  final String paymentMethod;
  final String cashierName;
  final String? customerName;

  Receipt({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.date,
    required this.transactionId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    required this.cashierName,
    this.customerName,
  });

  // Factory untuk test receipt
  factory Receipt.testReceipt() {
    final items = [
      ReceiptItem(name: 'Nasi Goreng Spesial', quantity: 2, price: 25000, total: 50000),
      ReceiptItem(name: 'Ayam Bakar', quantity: 1, price: 35000, total: 35000),
      ReceiptItem(name: 'Es Teh Manis', quantity: 3, price: 5000, total: 15000),
      ReceiptItem(name: 'Kerupuk', quantity: 2, price: 3000, total: 6000),
    ];

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.1;
    const discount = 5000.0;
    final grandTotal = subtotal + tax - discount;

    return Receipt(
      id: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      storeName: 'TOKO MAKANAN ENAK',
      storeAddress: 'Jl. Contoh No. 123, Jakarta',
      storePhone: '(021) 123-4567',
      date: DateTime.now(),
      transactionId: 'TRX-${DateTime.now().millisecondsSinceEpoch}',
      items: items,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      grandTotal: grandTotal,
      paymentMethod: 'CASH',
      cashierName: 'Demo User',
      customerName: 'Pelanggan Demo',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'storePhone': storePhone,
      'date': date.toIso8601String(),
      'transactionId': transactionId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'cashierName': cashierName,
      'customerName': customerName,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'],
      storeName: map['storeName'],
      storeAddress: map['storeAddress'],
      storePhone: map['storePhone'],
      date: DateTime.parse(map['date']),
      transactionId: map['transactionId'],
      items: (map['items'] as List)
          .map((item) => ReceiptItem.fromMap(item))
          .toList(),
      subtotal: map['subtotal'].toDouble(),
      tax: map['tax'].toDouble(),
      discount: map['discount'].toDouble(),
      grandTotal: map['grandTotal'].toDouble(),
      paymentMethod: map['paymentMethod'],
      cashierName: map['cashierName'],
      customerName: map['customerName'],
    );
  }
}