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
      nomor: json['Nomor'] ?? json['nomor'] ?? '',
      tanggal: json['Tanggal'] ?? json['tanggal'] ?? '',
      meja: json['Meja'] ?? json['meja']?.toString() ?? '',
      customer: json['Customer'] ?? json['customer']?.toString() ?? '',
      duration: json['Duration'] ?? json['duration'] ?? '',
      amount: _safeToDouble(json['Amount'] ?? json['amount']),
      serviceCharge: _safeToDouble(json['SeviceCharge'] ?? json['service_charge']),
      tax: _safeToDouble(json['Tax'] ?? json['tax']),
      discount: _safeToDouble(json['Discount'] ?? json['discount']),
      cash: _safeToDouble(json['Cash'] ?? json['cash']),
      card: _safeToDouble(json['Card'] ?? json['card']),
      dp: _safeToDouble(json['DP'] ?? json['dp']),
      edc: _safeToDouble(json['EDC'] ?? json['edc']),
      otherValue: _safeToDouble(json['Other_Value'] ?? json['other_value']),
      other: json['Other'] ?? json['other']?.toString() ?? '',
      statusOrder: json['StatusOrder'] ?? json['status_order'] ?? '',
      promo: json['Promo'] ?? json['promo'] ?? '',
      kasir: json['Kasir'] ?? json['kasir'] ?? '',
      details: details.map((detail) => InvoiceDetail.fromJson(detail)).toList(),
    );
  }

  List<String> get paymentMethods {
    final methods = <String>[];
    if (cash > 0) methods.add('Cash');
    if (card > 0) methods.add('Card');
    if (edc > 0) methods.add('EDC');
    if (dp > 0) methods.add('DP');
    if (otherValue > 0) methods.add(other.isNotEmpty ? other : 'Other');
    return methods;
  }

  String get paymentMethodsText {
    return paymentMethods.join(', ');
  }

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
      nomor: json['Nomor'] ?? json['nomor'] ?? '',
      nama: json['Nama'] ?? json['nama'] ?? '',
      varian: json['Varian'] ?? json['varian']?.toString() ?? '',
      salesType: json['Salestype'] ?? json['sales_type'] ?? '',
      qty: _safeToInt(json['Qty'] ?? json['qty']),
      price: _safeToDouble(json['Price'] ?? json['price']),
      disc: _safeToDouble(json['Disc'] ?? json['disc']),
      netPrice: _safeToDouble(json['NetPrice'] ?? json['net_price']),
      served: json['Served'] ?? json['served'] ?? '',
    );
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