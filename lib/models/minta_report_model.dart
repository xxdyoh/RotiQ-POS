class MintaReportItem {
  final String itemNama;
  final String cabang;
  final String keterangan;
  final int totalQty;

  MintaReportItem({
    required this.itemNama,
    required this.cabang,
    required this.keterangan,
    required this.totalQty,
  });

  factory MintaReportItem.fromJson(Map<String, dynamic> json) {
    dynamic qtyValue = json['total_qty'] ?? 0;
    int parsedQty = 0;

    if (qtyValue is String) {
      parsedQty = int.tryParse(qtyValue) ?? 0;
    } else if (qtyValue is int) {
      parsedQty = qtyValue;
    } else if (qtyValue is double) {
      parsedQty = qtyValue.toInt();
    }

    return MintaReportItem(
      itemNama: json['item_nama']?.toString() ?? '',
      cabang: json['cabang_nama']?.toString() ?? '-',
      keterangan: json['keterangan']?.toString() ?? '-',
      totalQty: parsedQty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_nama': itemNama,
      'cabang_nama': cabang,
      'keterangan': keterangan,
      'total_qty': totalQty,
    };
  }
}