class StokinHeader {
  final String stiNomor;
  final DateTime stiTanggal;
  final String stiKeterangan;
  final DateTime dateCrete;

  StokinHeader({
    required this.stiNomor,
    required this.stiTanggal,
    required this.stiKeterangan,
    required this.dateCrete,
  });

  factory StokinHeader.fromJson(Map<String, dynamic> json) {
    return StokinHeader(
      stiNomor: json['sti_nomor'] ?? '',
      stiTanggal: DateTime.parse(json['sti_tanggal'] ?? DateTime.now().toString()),
      stiKeterangan: json['sti_keterangan'] ?? '',
      dateCrete: DateTime.parse(json['date_crete'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sti_nomor': stiNomor,
      'sti_tanggal': stiTanggal.toIso8601String().split('T')[0],
      'sti_keterangan': stiKeterangan,
      'date_crete': dateCrete.toIso8601String(),
    };
  }
}

class StokinDetail {
  final String stidStiNomor;
  final int stidItemId;
  final double stidQty;
  final double stidHpp;
  final String? itemNama;

  StokinDetail({
    required this.stidStiNomor,
    required this.stidItemId,
    required this.stidQty,
    required this.stidHpp,
    this.itemNama,
  });

  factory StokinDetail.fromJson(Map<String, dynamic> json) {
    return StokinDetail(
      stidStiNomor: json['stid_sti_nomor'] ?? '',
      stidItemId: int.tryParse(json['stid_item_id']?.toString() ?? '0') ?? 0,
      stidQty: double.tryParse(json['stid_qty']?.toString() ?? '0') ?? 0.0,
      stidHpp: double.tryParse(json['stid_hpp']?.toString() ?? '0') ?? 0.0,
      itemNama: json['item_nama'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stid_sti_nomor': stidStiNomor,
      'stid_item_id': stidItemId,
      'stid_qty': stidQty,
      'stid_hpp': stidHpp,
    };
  }
}

class StokinItem {
  final int itemId;
  final String itemNama;
  int qty;
  String? referensi;

  StokinItem({
    required this.itemId,
    required this.itemNama,
    this.qty = 0,
    this.referensi,
  });

  factory StokinItem.fromJson(Map<String, dynamic> json) {
    return StokinItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
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
}