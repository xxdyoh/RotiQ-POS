class JurnalHeader {
  final String jurNo;
  final DateTime jurTanggal;
  final String jurKeterangan;
  final String jurTipeTransaksi;
  final int jurIsclosed;
  final DateTime dateCreate;
  final DateTime? dateModified;
  final String userCreate;
  final String? userModified;
  final double? totalDebet;

  JurnalHeader({
    required this.jurNo,
    required this.jurTanggal,
    required this.jurKeterangan,
    required this.jurTipeTransaksi,
    required this.jurIsclosed,
    required this.dateCreate,
    this.dateModified,
    required this.userCreate,
    this.userModified,
    this.totalDebet,
  });

  factory JurnalHeader.fromJson(Map<String, dynamic> json) {
    return JurnalHeader(
      jurNo: json['jur_no'] ?? '',
      jurTanggal: DateTime.parse(json['jur_tanggal'] ?? DateTime.now().toString()),
      jurKeterangan: json['jur_keterangan'] ?? '',
      jurTipeTransaksi: json['jur_tipetransaksi'] ?? '',
      jurIsclosed: int.tryParse(json['jur_isclosed']?.toString() ?? '0') ?? 0,
      dateCreate: DateTime.parse(json['date_create'] ?? DateTime.now().toString()),
      dateModified: json['date_modified'] != null ? DateTime.parse(json['date_modified']) : null,
      userCreate: json['user_create'] ?? '',
      userModified: json['user_modified'],
      totalDebet: double.tryParse(json['total_debet']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jur_no': jurNo,
      'jur_tanggal': jurTanggal.toIso8601String().split('T')[0],
      'jur_keterangan': jurKeterangan,
      'jur_tipetransaksi': jurTipeTransaksi,
      'jur_isclosed': jurIsclosed,
      'date_create': dateCreate.toIso8601String(),
      'date_modified': dateModified?.toIso8601String(),
      'user_create': userCreate,
      'user_modified': userModified,
    };
  }
}

class JurnalDetail {
  final String jurdJurNo;
  final String jurdRekKode;
  final double jurdKredit;
  final double jurdDebet;
  final int jurdNourut;
  final String jurdCcKode;
  final String jurdKeterangan;
  final String? jurdCusKode;
  final String? rekNama;
  final String? ccNama;

  JurnalDetail({
    required this.jurdJurNo,
    required this.jurdRekKode,
    required this.jurdKredit,
    required this.jurdDebet,
    required this.jurdNourut,
    required this.jurdCcKode,
    required this.jurdKeterangan,
    this.jurdCusKode,
    this.rekNama,
    this.ccNama,
  });

  factory JurnalDetail.fromJson(Map<String, dynamic> json) {
    return JurnalDetail(
      jurdJurNo: json['jurd_jur_no'] ?? '',
      jurdRekKode: json['jurd_rek_kode'] ?? '',
      jurdKredit: double.tryParse(json['jurd_kredit']?.toString() ?? '0') ?? 0.0,
      jurdDebet: double.tryParse(json['jurd_debet']?.toString() ?? '0') ?? 0.0,
      jurdNourut: int.tryParse(json['jurd_nourut']?.toString() ?? '0') ?? 0,
      jurdCcKode: json['jurd_cc_kode'] ?? '',
      jurdKeterangan: json['jurd_keterangan'] ?? '',
      jurdCusKode: json['jurd_cus_kode'],
      rekNama: json['rek_nama'],
      ccNama: json['cc_nama'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jurd_jur_no': jurdJurNo,
      'jurd_rek_kode': jurdRekKode,
      'jurd_kredit': jurdKredit,
      'jurd_debet': jurdDebet,
      'jurd_nourut': jurdNourut,
      'jurd_cc_kode': jurdCcKode,
      'jurd_keterangan': jurdKeterangan,
      'jurd_cus_kode': jurdCusKode,
    };
  }
}

class Rekening {
  final String rekKode;
  final String rekNama;

  Rekening({
    required this.rekKode,
    required this.rekNama,
  });

  factory Rekening.fromJson(Map<String, dynamic> json) {
    return Rekening(
      rekKode: json['rek_kode'] ?? '',
      rekNama: json['rek_nama'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rek_kode': rekKode,
      'rek_nama': rekNama,
    };
  }
}

class CostCenter {
  final String ccKode;
  final String ccNama;

  CostCenter({
    required this.ccKode,
    required this.ccNama,
  });

  factory CostCenter.fromJson(Map<String, dynamic> json) {
    return CostCenter(
      ccKode: json['cc_kode'] ?? '',
      ccNama: json['cc_nama'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cc_kode': ccKode,
      'cc_nama': ccNama,
    };
  }
}

class JurnalDetailInput {
  String account;
  String accountName;
  double nilai;
  String keterangan;
  String costcenter;
  String costcenterName;

  JurnalDetailInput({
    required this.account,
    required this.accountName,
    required this.nilai,
    required this.keterangan,
    required this.costcenter,
    required this.costcenterName,
  });

  Map<String, dynamic> toJson() {
    return {
      'account': account,
      'accountName': accountName,
      'nilai': nilai,
      'keterangan': keterangan,
      'costcenter': costcenter,
    };
  }
}