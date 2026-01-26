class StockReport {
  final String ID;
  final String NAMA;
  final String CATEGORY;
  final int Awal;
  final int Stok_in;
  final int Retur;
  final int Sales;
  final int Akhir;

  StockReport({
    required this.ID,
    required this.NAMA,
    required this.CATEGORY,
    required this.Awal,
    required this.Stok_in,
    required this.Retur,
    required this.Sales,
    required this.Akhir,
  });

  factory StockReport.fromJson(Map<String, dynamic> json) {
    return StockReport(
      ID: json['ID']?.toString() ?? '',
      NAMA: json['NAMA'] ?? '',
      CATEGORY: json['CATEGORY'] ?? '',
      Awal: _safeToInt(json['Awal']),
      Stok_in: _safeToInt(json['Stok_in']),
      Retur: _safeToInt(json['Retur']),
      Sales: _safeToInt(json['Sales']),
      Akhir: _safeToInt(json['Akhir']),
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

  // Calculate changes
  int get change => Stok_in - Retur - Sales;
}

class StockSummary {
  final int totalAwal;
  final int totalStokIn;
  final int totalRetur;
  final int totalSales;
  final int totalAkhir;
  final int totalItems;

  StockSummary({
    required this.totalAwal,
    required this.totalStokIn,
    required this.totalRetur,
    required this.totalSales,
    required this.totalAkhir,
    required this.totalItems,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      totalAwal: _safeToInt(json['total_awal']),
      totalStokIn: _safeToInt(json['total_stok_in']),
      totalRetur: _safeToInt(json['total_retur']),
      totalSales: _safeToInt(json['total_sales']),
      totalAkhir: _safeToInt(json['total_akhir']),
      totalItems: _safeToInt(json['total_items']),
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

  int get totalChange => totalStokIn - totalRetur - totalSales;
}