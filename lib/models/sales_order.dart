class SalesOrder {
  final String nomor;
  final String tanggal;
  final String atasNama;
  final String noHp;
  final String status;
  final double nilai;
  final String tglAmbil;
  final String tglBayar;
  final double dp;
  final List<OrderDetail> details;

  SalesOrder({
    required this.nomor,
    required this.tanggal,
    required this.atasNama,
    required this.noHp,
    required this.status,
    required this.nilai,
    required this.tglAmbil,
    required this.tglBayar,
    required this.dp,
    required this.details,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    final details = List<Map<String, dynamic>>.from(json['details'] ?? []);

    return SalesOrder(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      atasNama: json['atas_nama']?.toString() ?? '',
      noHp: json['no_hp']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      nilai: _safeToDouble(json['nilai']),
      tglAmbil: json['tgl_ambil']?.toString() ?? '',
      tglBayar: json['tgl_bayar']?.toString() ?? '',
      dp: _safeToDouble(json['dp']),
      details: details.map((detail) => OrderDetail.fromJson(detail)).toList(),
    );
  }

  // Helper methods
  bool get isPaid => status == 'Sudah';
  bool get hasDp => dp > 0;
  bool get hasAmbilDate => tglAmbil.isNotEmpty && tglAmbil != 'null';
  bool get hasBayarDate => tglBayar.isNotEmpty && tglBayar != 'null';

  String get customerDisplay {
    if (atasNama.isNotEmpty) return atasNama;
    if (noHp.isNotEmpty) return noHp;
    return 'Customer';
  }

  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty || value.toLowerCase() == 'null') return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class OrderDetail {
  final String nomor;
  final String nama;
  final String varian;
  final String salesType;
  final int qty;
  final double price;
  final double disc;
  final double netPrice;
  final String served;

  OrderDetail({
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

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      nomor: json['nomor']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      varian: json['varian']?.toString() ?? '',
      salesType: json['sales_type']?.toString() ?? '',
      qty: _safeToInt(json['qty']),
      price: _safeToDouble(json['price']),
      disc: _safeToDouble(json['disc']),
      netPrice: _safeToDouble(json['net_price']),
      served: json['served']?.toString() ?? '',
    );
  }

  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty || value.toLowerCase() == 'null') return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty || value.toLowerCase() == 'null') return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class OrderSummary {
  final int totalOrders;
  final double totalNilai;
  final double totalDp;
  final int totalBelum;
  final int totalSudah;

  OrderSummary({
    required this.totalOrders,
    required this.totalNilai,
    required this.totalDp,
    required this.totalBelum,
    required this.totalSudah,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      totalOrders: _safeToInt(json['total_orders']),
      totalNilai: _safeToDouble(json['total_nilai']),
      totalDp: _safeToDouble(json['total_dp']),
      totalBelum: _safeToInt(json['total_belum']),
      totalSudah: _safeToInt(json['total_sudah']),
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