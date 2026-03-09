class MintaItem {
  final int itemId;
  final String itemNama;
  final int qty;
  final String? keterangan;

  MintaItem({
    required this.itemId,
    required this.itemNama,
    required this.qty,
    this.keterangan,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'qty': qty,
      'keterangan': keterangan ?? '',
    };
  }
}