class MutasiInItem {
  final int itemId;
  final String itemNama;
  int qty;
  int qtyMutasi;
  String? referensi;

  MutasiInItem({
    required this.itemId,
    required this.itemNama,
    this.qty = 0,
    this.qtyMutasi = 0,
    this.referensi,
  });

  factory MutasiInItem.fromJson(Map<String, dynamic> json) {
    return MutasiInItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      qtyMutasi: int.tryParse(json['qty_mutasi']?.toString() ?? '0') ?? 0,
      referensi: json['referensi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'qty': qty,
      'referensi': referensi,
    };
  }

  MutasiInItem copyWith({
    int? qty,
    int? qtyMutasi,
    String? referensi,
  }) {
    return MutasiInItem(
      itemId: itemId,
      itemNama: itemNama,
      qty: qty ?? this.qty,
      qtyMutasi: qtyMutasi ?? this.qtyMutasi,
      referensi: referensi ?? this.referensi,
    );
  }
}