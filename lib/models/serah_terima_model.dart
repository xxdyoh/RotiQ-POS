class SerahTerimaItem {
  final int itemId;
  final String itemNama;
  final int qtySpk;
  int qtyTerima;
  final String? keterangan;
  final int? nourut;

  SerahTerimaItem({
    required this.itemId,
    required this.itemNama,
    required this.qtySpk,
    required this.qtyTerima,
    this.keterangan,
    this.nourut,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'qty_terima': qtyTerima,
      'keterangan': keterangan ?? '',
    };
  }

  SerahTerimaItem copyWith({
    int? qtyTerima,
    String? keterangan,
  }) {
    return SerahTerimaItem(
      itemId: itemId,
      itemNama: itemNama,
      qtySpk: qtySpk,
      qtyTerima: qtyTerima ?? this.qtyTerima,
      keterangan: keterangan ?? this.keterangan,
      nourut: nourut,
    );
  }
}