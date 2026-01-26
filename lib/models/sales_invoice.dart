class SalesInvoice {
  final String nomor;
  final String tanggal;
  final String meja;
  final String customer;
  final String duration;
  final double amount;
  final double serviceCharge;
  final double tax;
  final double discount;
  final double cash;
  final double card;
  final double dp;
  final double edc;
  final double otherValue;
  final String other;
  final String statusOrder;
  final String promo;
  final String kasir;
  final List<InvoiceDetail> details;

  SalesInvoice({
    required this.nomor,
    required this.tanggal,
    required this.meja,
    required this.customer,
    required this.duration,
    required this.amount,
    required this.serviceCharge,
    required this.tax,
    required this.discount,
    required this.cash,
    required this.card,
    required this.dp,
    required this.edc,
    required this.otherValue,
    required this.other,
    required this.statusOrder,
    required this.promo,
    required this.kasir,
    required this.details,
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> json) {
    final details = List<Map<String, dynamic>>.from(json['details'] ?? []);

    return SalesInvoice(
      nomor: json['nomor'] ?? '',
      tanggal: json['tanggal'] ?? '',
      meja: json['meja']?.toString() ?? '', // Handle null
      customer: json['customer']?.toString() ?? '', // Handle null
      duration: json['duration'] ?? '',
      amount: _safeToDouble(json['amount']),
      serviceCharge: _safeToDouble(json['service_charge']),
      tax: _safeToDouble(json['tax']),
      discount: _safeToDouble(json['discount']),
      cash: _safeToDouble(json['cash']),
      card: _safeToDouble(json['card']),
      dp: _safeToDouble(json['dp']),
      edc: _safeToDouble(json['edc']), // Handle null edc
      otherValue: _safeToDouble(json['other_value']),
      other: json['other']?.toString() ?? '', // Handle null
      statusOrder: json['status_order'] ?? '',
      promo: json['promo'] ?? '',
      kasir: json['kasir'] ?? '',
      details: details.map((detail) => InvoiceDetail.fromJson(detail)).toList(),
    );
  }

  // Helper method untuk mendapatkan payment method yang digunakan
  List<String> get paymentMethods {
    final methods = <String>[];
    if (cash > 0) methods.add('Cash');
    if (card > 0) methods.add('Card');
    if (edc > 0) methods.add('EDC');
    if (dp > 0) methods.add('DP');
    if (otherValue > 0) methods.add('Other');
    return methods;
  }

  String get paymentMethodsText {
    return paymentMethods.join(', ');
  }

  // 🔥 FIX: Safe conversion untuk handle null dan string
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class InvoiceDetail {
  final String nomor;
  final String nama;
  final String varian;
  final String salesType;
  final int qty;
  final double price;
  final double disc;
  final double netPrice;
  final String served;

  InvoiceDetail({
    required this.nomor,
    required this.nama,
    required this.varian,
    required this.salesType,
    required this.qty,
    required this.price,
    required this.disc,
    required this.netPrice,
    required this.served,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      nomor: json['nomor'] ?? '',
      nama: json['nama'] ?? '',
      varian: json['varian']?.toString() ?? '', // Handle null
      salesType: json['sales_type'] ?? '',
      qty: _safeToInt(json['qty']),
      price: _safeToDouble(json['price']),
      disc: _safeToDouble(json['disc']),
      netPrice: _safeToDouble(json['net_price']),
      served: json['served'] ?? '',
    );
  }

  // 🔥 FIX: Safe conversion untuk qty
  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // 🔥 FIX: Safe conversion untuk double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class PaymentSummary {
  final double totalCash;
  final double totalCard;
  final double totalEdc;
  final double totalDp;
  final double totalOther;
  final double totalAmount;
  final int totalInvoices;

  PaymentSummary({
    required this.totalCash,
    required this.totalCard,
    required this.totalEdc,
    required this.totalDp,
    required this.totalOther,
    required this.totalAmount,
    required this.totalInvoices,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalCash: _safeToDouble(json['total_cash']),
      totalCard: _safeToDouble(json['total_card']),
      totalEdc: _safeToDouble(json['total_edc']),
      totalDp: _safeToDouble(json['total_dp']),
      totalOther: _safeToDouble(json['total_other']),
      totalAmount: _safeToDouble(json['total_amount']),
      totalInvoices: _safeToInt(json['total_invoices']),
    );
  }

  // 🔥 FIX: Safe conversion methods
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}