class MintaReportItem {
  final String itemNama;
  final String cabangKode;
  final String cabang;
  final String status;        // DISPLAY / PESANAN
  final int jumlah;
  final String keterangan;
  final int totalQty;
  final String itemSize;
  final String itemDivisi;
  final double itemGram;
  final double itemHarga;

  MintaReportItem({
    required this.itemNama,
    this.cabangKode = '',
    required this.cabang,
    this.status = 'DISPLAY',
    this.jumlah = 0,
    this.keterangan = '-',
    required this.totalQty,
    this.itemSize = '',
    this.itemDivisi = '',
    this.itemGram = 0,
    this.itemHarga = 0,
  });

  factory MintaReportItem.fromJson(Map<String, dynamic> json) {
    return MintaReportItem(
      itemNama: json['item_nama']?.toString() ?? '',
      cabangKode: json['cabang_kode']?.toString() ?? '',
      cabang: json['cabang_nama']?.toString() ?? '-',
      status: json['mtd_status']?.toString() ?? 'DISPLAY',
      jumlah: _safeToInt(json['mtd_qty']),
      keterangan: json['mtd_keterangan']?.toString() ?? '-',
      totalQty: _safeToInt(json['total_qty']),
      itemSize: json['item_size']?.toString() ?? '',
      itemDivisi: json['item_divisi']?.toString() ?? '',
      itemGram: double.tryParse(json['item_gram']?.toString() ?? '0') ?? 0,
      itemHarga: double.tryParse(json['item_harga']?.toString() ?? '0') ?? 0,
    );
  }

  static int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}