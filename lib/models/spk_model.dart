class SpkItem {
  final int itemId;
  final String itemNama;
  final int qty;
  final int qtyRealisasi;
  final String? keterangan;
  final int? nourut;

  SpkItem({
    required this.itemId,
    required this.itemNama,
    required this.qty,
    required this.qtyRealisasi,
    this.keterangan,
    this.nourut,
  });

  factory SpkItem.fromJson(Map<String, dynamic> json) {
    return SpkItem(
      itemId: json['spkd_brg_kode'] ?? 0,
      itemNama: json['item_nama'] ?? '',
      qty: json['spkd_qty'] ?? 0,
      qtyRealisasi: json['qty_realisasi'] ?? 0,
      keterangan: json['spkd_keterangan'],
      nourut: json['spkd_nourut'],
    );
  }
}