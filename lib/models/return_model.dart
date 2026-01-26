class ReturnHeader {
  final String retNomor;
  final DateTime retTanggal;
  final String retKeterangan;

  ReturnHeader({
    required this.retNomor,
    required this.retTanggal,
    required this.retKeterangan,
  });

  factory ReturnHeader.fromJson(Map<String, dynamic> json) {
    return ReturnHeader(
      retNomor: json['ret_nomor'] ?? '',
      retTanggal: DateTime.parse(json['ret_tanggal'] ?? DateTime.now().toString()),
      retKeterangan: json['ret_keterangan'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ret_nomor': retNomor,
      'ret_tanggal': retTanggal.toIso8601String().split('T')[0],
      'ret_keterangan': retKeterangan,
    };
  }
}

class ReturnDetail {
  final String retdRetNomor;
  final int retdItemId;
  final double retdQty;
  final double retdHpp;
  final String? itemNama;

  ReturnDetail({
    required this.retdRetNomor,
    required this.retdItemId,
    required this.retdQty,
    required this.retdHpp,
    this.itemNama,
  });

  factory ReturnDetail.fromJson(Map<String, dynamic> json) {
    return ReturnDetail(
      retdRetNomor: json['retd_ret_nomor'] ?? '',
      retdItemId: int.tryParse(json['retd_item_id']?.toString() ?? '0') ?? 0,
      retdQty: double.tryParse(json['retd_qty']?.toString() ?? '0') ?? 0,
      retdHpp: double.tryParse(json['retd_hpp']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'retd_ret_nomor': retdRetNomor,
      'retd_item_id': retdItemId,
      'retd_qty': retdQty,
      'retd_hpp': retdHpp,
    };
  }
}

class ReturnItem {
  final int itemId;
  final String itemNama;
  int qty;

  ReturnItem({
    required this.itemId,
    required this.itemNama,
    this.qty = 0,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'qty': qty,
    };
  }
}