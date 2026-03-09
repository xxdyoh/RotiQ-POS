class DoItem {
  final int itemId;
  final String itemNama;
  final int qtyMinta;
  int qtyKirim;
  final String? keterangan;
  final int? nourut;
  final int stockTersedia;

  DoItem({
    required this.itemId,
    required this.itemNama,
    required this.qtyMinta,
    required this.qtyKirim,
    this.keterangan,
    this.nourut,
    this.stockTersedia = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'qty_kirim': qtyKirim,
      'keterangan': keterangan ?? '',
    };
  }

  DoItem copyWith({
    int? qtyKirim,
    String? keterangan,
    int? stockTersedia,
  }) {
    return DoItem(
      itemId: itemId,
      itemNama: itemNama,
      qtyMinta: qtyMinta,
      qtyKirim: qtyKirim ?? this.qtyKirim,
      keterangan: keterangan ?? this.keterangan,
      nourut: nourut,
      stockTersedia: stockTersedia ?? this.stockTersedia,
    );
  }
}