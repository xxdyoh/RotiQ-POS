class ItemSetengahJadiDetail {
  final int itemId;
  final int stjId;
  final double qty;

  ItemSetengahJadiDetail({
    required this.itemId,
    required this.stjId,
    required this.qty,
  });

  Map<String, dynamic> toJson() {
    return {
      'stj_id': stjId,
      'qty': qty.toInt(),
    };
  }

  factory ItemSetengahJadiDetail.fromJson(Map<String, dynamic> json) {
    return ItemSetengahJadiDetail(
      itemId: int.tryParse(json['isj_item_id']?.toString() ?? '0') ?? 0,
      stjId: int.tryParse(json['stj_id']?.toString() ?? '0') ?? 0,
      qty: double.tryParse(json['isj_qty']?.toString() ?? '0') ?? 0.0,
    );
  }
}