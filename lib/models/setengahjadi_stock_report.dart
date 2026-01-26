class SetengahJadiStockReport {
  final String ID;
  final String NAMA;
  final int Awal;
  final int Stok_in;
  final int Stok_out;
  final int Akhir;

  SetengahJadiStockReport({
    required this.ID,
    required this.NAMA,
    required this.Awal,
    required this.Stok_in,
    required this.Stok_out,
    required this.Akhir,
  });

  factory SetengahJadiStockReport.fromJson(Map<String, dynamic> json) {
    return SetengahJadiStockReport(
      ID: json['ID']?.toString() ?? '',
      NAMA: json['NAMA'] ?? '',
      Awal: _safeToInt(json['Awal']),
      Stok_in: _safeToInt(json['Stok_in']),
      Stok_out: _safeToInt(json['Stok_out']),
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

  int get change => Stok_in - Stok_out;
}

class SetengahJadiStockSummary {
  final int totalAwal;
  final int totalStokIn;
  final int totalStokOut;
  final int totalAkhir;
  final int totalItems;

  SetengahJadiStockSummary({
    required this.totalAwal,
    required this.totalStokIn,
    required this.totalStokOut,
    required this.totalAkhir,
    required this.totalItems,
  });

  factory SetengahJadiStockSummary.fromJson(Map<String, dynamic> json) {
    return SetengahJadiStockSummary(
      totalAwal: _safeToInt(json['total_awal']),
      totalStokIn: _safeToInt(json['total_stok_in']),
      totalStokOut: _safeToInt(json['total_stok_out']),
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

  int get totalChange => totalStokIn - totalStokOut;
}

class StockMovement {
  final String noReferensi;
  final String tanggal;
  final double qty;
  final String keterangan;
  final String jenis;
  final String? itemNama;

  StockMovement({
    required this.noReferensi,
    required this.tanggal,
    required this.qty,
    required this.keterangan,
    required this.jenis,
    this.itemNama,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      noReferensi: json['no_referensi'] ?? '',
      tanggal: json['tanggal'] ?? '',
      qty: _safeToDouble(json['qty']),
      keterangan: json['keterangan'] ?? '',
      jenis: json['jenis'] ?? '',
      itemNama: json['item_nama'],
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
}

class StockMovementDetail {
  final List<StockMovement> masuk;
  final List<StockMovement> keluar;

  StockMovementDetail({
    required this.masuk,
    required this.keluar,
  });

  factory StockMovementDetail.fromJson(Map<String, dynamic> json) {
    return StockMovementDetail(
      masuk: List<StockMovement>.from(
          (json['masuk'] as List).map((x) => StockMovement.fromJson(x))
      ),
      keluar: List<StockMovement>.from(
          (json['keluar'] as List).map((x) => StockMovement.fromJson(x))
      ),
    );
  }
}