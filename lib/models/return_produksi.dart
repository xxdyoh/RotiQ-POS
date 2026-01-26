class ReturnProduksi {
  final String nomor;
  final String tanggal;
  final String keterangan;
  final double nilaiJual;
  final List<ReturnDetail> details;

  ReturnProduksi({
    required this.nomor,
    required this.tanggal,
    required this.keterangan,
    required this.nilaiJual,
    required this.details,
  });

  factory ReturnProduksi.fromJson(Map<String, dynamic> json) {
    final details = List<Map<String, dynamic>>.from(json['details'] ?? []);

    return ReturnProduksi(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      nilaiJual: _safeToDouble(json['nilai_jual']),
      details: details.map((detail) => ReturnDetail.fromJson(detail)).toList(),
    );
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

class ReturnDetail {
  final String nomor;
  final int itemId;
  final String nama;
  final int qty;
  final double hargaJual;
  final double nilaiJual;

  ReturnDetail({
    required this.nomor,
    required this.itemId,
    required this.nama,
    required this.qty,
    required this.hargaJual,
    required this.nilaiJual,
  });

  factory ReturnDetail.fromJson(Map<String, dynamic> json) {
    return ReturnDetail(
      nomor: json['nomor']?.toString() ?? '',
      itemId: _safeToInt(json['item_id']),
      nama: json['nama']?.toString() ?? '',
      qty: _safeToInt(json['qty']),
      hargaJual: _safeToDouble(json['harga_jual']),
      nilaiJual: _safeToDouble(json['nilai_jual']),
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

class ReturnSummary {
  final int totalReturns;
  final double totalNilaiJual;
  final int totalItems;

  ReturnSummary({
    required this.totalReturns,
    required this.totalNilaiJual,
    required this.totalItems,
  });

  factory ReturnSummary.fromJson(Map<String, dynamic> json) {
    return ReturnSummary(
      totalReturns: _safeToInt(json['total_returns']),
      totalNilaiJual: _safeToDouble(json['total_nilai_jual']),
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