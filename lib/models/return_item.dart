class ReturnItem {
  final int bulan;
  final int tahun;
  final String nomor;
  final DateTime tanggal;
  final String nama;
  final int qty;
  final int nilai;
  final String cabang;
  final double harga;

  ReturnItem({
    this.bulan = 0,
    this.tahun = 0,
    this.nomor = '',
    required this.tanggal,
    this.nama = '',
    this.qty = 0,
    this.nilai = 0,
    this.cabang = '',
    this.harga = 0,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      bulan: _parseInt(json['Bulan']),
      tahun: _parseInt(json['Tahun']),
      nomor: json['Nomor']?.toString() ?? '',
      tanggal: DateTime.tryParse(json['Tanggal']?.toString() ?? '') ?? DateTime.now(),
      nama: json['Nama']?.toString() ?? '',
      qty: _parseInt(json['Qty']),
      harga: _parseDouble(json['Harga']),
      nilai: _parseInt(json['Nilai']),
      cabang: json['Cabang']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }
}