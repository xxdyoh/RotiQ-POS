class PostingPenjualanHeader {
  final String stbjNomor;
  final DateTime stbjTanggal;
  final String stbjKeterangan;
  final String? stbjGdgKode;
  final DateTime? dateCreate;
  final DateTime? dateModified;
  final String? userCreate;
  final String? userModified;

  PostingPenjualanHeader({
    required this.stbjNomor,
    required this.stbjTanggal,
    required this.stbjKeterangan,
    this.stbjGdgKode,
    this.dateCreate,
    this.dateModified,
    this.userCreate,
    this.userModified,
  });

  factory PostingPenjualanHeader.fromJson(Map<String, dynamic> json) {
    return PostingPenjualanHeader(
      stbjNomor: json['stbj_nomor'] ?? '',
      stbjTanggal: DateTime.parse(json['stbj_tanggal'] ?? DateTime.now().toString()),
      stbjKeterangan: json['stbj_keterangan'] ?? '',
      stbjGdgKode: json['stbj_gdg_kode'],
      dateCreate: json['date_create'] != null ? DateTime.parse(json['date_create']) : null,
      dateModified: json['date_modified'] != null ? DateTime.parse(json['date_modified']) : null,
      userCreate: json['user_create'],
      userModified: json['user_modified'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stbj_nomor': stbjNomor,
      'stbj_tanggal': stbjTanggal.toIso8601String(),
      'stbj_keterangan': stbjKeterangan,
      'stbj_gdg_kode': stbjGdgKode,
    };
  }
}

class PostingPenjualanDetail {
  final String stbjdStbjNomor;
  final String stbjdBrgKode;
  final double stbjdJumlah;
  final double? stbjdHarga;
  final String? stbjdKeterangan;
  final String? stbjdSatuan;
  final int? stbjdNourut;
  final String? stbjdGdgKode;
  final double? stbjdQty;
  final String? itemNama;

  PostingPenjualanDetail({
    required this.stbjdStbjNomor,
    required this.stbjdBrgKode,
    required this.stbjdJumlah,
    this.stbjdHarga,
    this.stbjdKeterangan,
    this.stbjdSatuan,
    this.stbjdNourut,
    this.stbjdGdgKode,
    this.stbjdQty,
    this.itemNama,
  });

  factory PostingPenjualanDetail.fromJson(Map<String, dynamic> json) {
    return PostingPenjualanDetail(
      stbjdStbjNomor: json['stbjd_stbj_Nomor'] ?? '',
      stbjdBrgKode: json['stbjd_brg_kode'] ?? '',
      stbjdJumlah: double.tryParse(json['stbjd_Jumlah']?.toString() ?? '0') ?? 0,
      stbjdHarga: double.tryParse(json['stbjd_harga']?.toString() ?? '0'),
      stbjdKeterangan: json['stbjd_Keterangan'],
      stbjdSatuan: json['stbjd_satuan'],
      stbjdNourut: int.tryParse(json['stbjd_nourut']?.toString() ?? '0'),
      stbjdGdgKode: json['stbjd_gdg_kode'],
      stbjdQty: double.tryParse(json['stbjd_qty']?.toString() ?? '0'),
      itemNama: json['item_nama'],
    );
  }
}

class PostingPenjualanItem {
  final int itemId;
  final String itemNama;
  final int qty;
  final String? referensi;

  PostingPenjualanItem({
    required this.itemId,
    required this.itemNama,
    required this.qty,
    this.referensi,
  });

  factory PostingPenjualanItem.fromJson(Map<String, dynamic> json) {
    return PostingPenjualanItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      referensi: json['referensi_list'],
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