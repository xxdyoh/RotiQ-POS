class StokStjinHeader {
  final String stjiNomor;
  final DateTime stjiTanggal;
  final String stjiKeterangan;
  final DateTime dateCreate;

  StokStjinHeader({
    required this.stjiNomor,
    required this.stjiTanggal,
    required this.stjiKeterangan,
    required this.dateCreate,
  });

  factory StokStjinHeader.fromJson(Map<String, dynamic> json) {
    return StokStjinHeader(
      stjiNomor: json['stji_nomor'] ?? '',
      stjiTanggal: DateTime.parse(json['stji_tanggal'] ?? DateTime.now().toString()),
      stjiKeterangan: json['stji_keterangan'] ?? '',
      dateCreate: DateTime.parse(json['date_create'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stji_nomor': stjiNomor,
      'stji_tanggal': stjiTanggal.toIso8601String().split('T')[0],
      'stji_keterangan': stjiKeterangan,
      'date_create': dateCreate.toIso8601String(),
    };
  }
}

class StokStjinDetail {
  final String stjidStjiNomor;
  final int stjidStjId;
  final int stjidQty;
  final String? stjNama;

  StokStjinDetail({
    required this.stjidStjiNomor,
    required this.stjidStjId,
    required this.stjidQty,
    this.stjNama,
  });

  factory StokStjinDetail.fromJson(Map<String, dynamic> json) {
    return StokStjinDetail(
      stjidStjiNomor: json['stjid_stji_nomor'] ?? '',
      stjidStjId: int.tryParse(json['stjid_stj_id']?.toString() ?? '0') ?? 0,
      stjidQty: int.tryParse(json['stjid_qty']?.toString() ?? '0') ?? 0,
      stjNama: json['stj_nama'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stjid_stji_nomor': stjidStjiNomor,
      'stjid_stj_id': stjidStjId,
      'stjid_qty': stjidQty,
    };
  }
}

class StokStjinItem {
  final int stjId;
  final String stjNama;
  int qty;

  StokStjinItem({
    required this.stjId,
    required this.stjNama,
    this.qty = 0,
  });

  factory StokStjinItem.fromJson(Map<String, dynamic> json) {
    return StokStjinItem(
      stjId: int.tryParse(json['stj_id']?.toString() ?? '0') ?? 0,
      stjNama: json['stj_nama'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stj_id': stjId,
      'stj_nama': stjNama,
      'qty': qty,
    };
  }
}