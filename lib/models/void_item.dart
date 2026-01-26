class VoidItem {
  final String bulan;
  final String tahun;
  final String nomor;
  final String tanggal;
  final String nama;
  final String varian;
  final String salesType;
  final int qty;
  final double nilai;
  final String served;
  final String category;

  VoidItem({
    required this.bulan,
    required this.tahun,
    required this.nomor,
    required this.tanggal,
    required this.nama,
    required this.varian,
    required this.salesType,
    required this.qty,
    required this.nilai,
    required this.served,
    required this.category,
  });

  factory VoidItem.fromJson(Map<String, dynamic> json) {
    return VoidItem(
      bulan: json['bulan']?.toString() ?? '',
      tahun: json['tahun']?.toString() ?? '',
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      varian: json['varian']?.toString() ?? '',
      salesType: json['sales_type']?.toString() ?? '',
      qty: _safeToInt(json['qty']),
      nilai: _safeToDouble(json['nilai']),
      served: json['served']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
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

class VoidSummary {
  final int totalItems;
  final int totalQty;
  final double totalNilai;

  VoidSummary({
    required this.totalItems,
    required this.totalQty,
    required this.totalNilai,
  });

  factory VoidSummary.fromJson(Map<String, dynamic> json) {
    return VoidSummary(
      totalItems: _safeToInt(json['total_items']),
      totalQty: _safeToInt(json['total_qty']),
      totalNilai: _safeToDouble(json['total_nilai']),
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