class StockReport {
  final String ID;
  final String NAMA;
  final String CATEGORY;
  final int Awal;
  final int STBJ;
  final int Mutasi_in;
  final int Mutasi_out;
  final int Koreksi;      // <-- TAMBAHKAN
  final int Retur;
  final int Sales;
  final int Akhir;

  StockReport({
    required this.ID,
    required this.NAMA,
    required this.CATEGORY,
    required this.Awal,
    required this.STBJ,
    required this.Mutasi_in,
    required this.Mutasi_out,
    required this.Koreksi, // <-- TAMBAHKAN
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
      STBJ: _safeToInt(json['STBJ']),
      Mutasi_in: _safeToInt(json['Mutasi_in']),
      Mutasi_out: _safeToInt(json['Mutasi_out']),
      Koreksi: _safeToInt(json['Koreksi']),  // <-- TAMBAHKAN
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

  int get change => (STBJ + Mutasi_in + Koreksi) - (Mutasi_out + Retur + Sales);
}

class StockSummary {
  final int totalAwal;
  final int totalSTBJ;
  final int totalMutasiIn;
  final int totalMutasiOut;
  final int totalKoreksi;   // <-- TAMBAHKAN
  final int totalRetur;
  final int totalSales;
  final int totalAkhir;
  final int totalItems;

  StockSummary({
    required this.totalAwal,
    required this.totalSTBJ,
    required this.totalMutasiIn,
    required this.totalMutasiOut,
    required this.totalKoreksi, // <-- TAMBAHKAN
    required this.totalRetur,
    required this.totalSales,
    required this.totalAkhir,
    required this.totalItems,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      totalAwal: _safeToInt(json['total_awal']),
      totalSTBJ: _safeToInt(json['total_stbj']),
      totalMutasiIn: _safeToInt(json['total_mutasi_in']),
      totalMutasiOut: _safeToInt(json['total_mutasi_out']),
      totalKoreksi: _safeToInt(json['total_koreksi'] ?? 0), // <-- TAMBAHKAN
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

  int get totalChange => (totalSTBJ + totalMutasiIn + totalKoreksi) - (totalMutasiOut + totalRetur + totalSales);
}