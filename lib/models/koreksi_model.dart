class KoreksiHeader {
  final String korNomor;
  final DateTime korTanggal;
  final String korKeterangan;
  final DateTime dateCrete;

  KoreksiHeader({
    required this.korNomor,
    required this.korTanggal,
    required this.korKeterangan,
    required this.dateCrete,
  });

  factory KoreksiHeader.fromJson(Map<String, dynamic> json) {
    return KoreksiHeader(
      korNomor: json['kor_nomor'] ?? '',
      korTanggal: DateTime.parse(json['kor_tanggal'] ?? DateTime.now().toString()),
      korKeterangan: json['kor_keterangan'] ?? '',
      dateCrete: DateTime.parse(json['date_crete'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kor_nomor': korNomor,
      'kor_tanggal': korTanggal.toIso8601String().split('T')[0],
      'kor_keterangan': korKeterangan,
      'date_crete': dateCrete.toIso8601String(),
    };
  }
}

class KoreksiDetail {
  final String kordKorNomor;
  final int kordItemId;
  final double kordQty;
  final double kordStok;
  final double kordHpp;
  final String? itemNama;

  KoreksiDetail({
    required this.kordKorNomor,
    required this.kordItemId,
    required this.kordQty,
    required this.kordStok,
    required this.kordHpp,
    this.itemNama,
  });

  factory KoreksiDetail.fromJson(Map<String, dynamic> json) {
    return KoreksiDetail(
      kordKorNomor: json['kord_kor_nomor'] ?? '',
      kordItemId: int.tryParse(json['kord_item_id']?.toString() ?? '0') ?? 0,
      kordQty: double.tryParse(json['kord_qty']?.toString() ?? '0') ?? 0.0,
      kordStok: double.tryParse(json['kord_stok']?.toString() ?? '0') ?? 0.0,
      kordHpp: double.tryParse(json['kord_hpp']?.toString() ?? '0') ?? 0.0,
      itemNama: json['item_nama'],
    );
  }
}

class KoreksiItem {
  final int itemId;
  final String itemNama;
  final String tipe;  // <-- TAMBAHKAN
  double stokSistem;
  final double hpp;
  double stokFisik;
  double selisih;

  KoreksiItem({
    required this.itemId,
    required this.itemNama,
    this.tipe = 'BJ',  // <-- TAMBAHKAN
    this.stokSistem = 0,
    this.hpp = 0,
    this.stokFisik = 0,
    this.selisih = 0,
  });

  factory KoreksiItem.fromJson(Map<String, dynamic> json) {
    return KoreksiItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      tipe: json['tipe'] ?? 'BJ',  // <-- TAMBAHKAN
      hpp: double.tryParse(json['item_hpp']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'tipe': tipe,  // <-- TAMBAHKAN
      'stok_sistem': stokSistem,
      'stok_fisik': stokFisik,
      'selisih': selisih,
      'hpp': hpp,
    };
  }
}