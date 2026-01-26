class TutupKasir {
  final String userKode;
  final String? ip;
  final DateTime tanggal;
  final double setoran;
  final double selisih;
  final double cash;
  final double card;
  final double other;
  final double refund;
  final int voidCount;
  final double dp;

  TutupKasir({
    required this.userKode,
    this.ip,
    required this.tanggal,
    required this.setoran,
    required this.selisih,
    required this.cash,
    required this.card,
    required this.other,
    required this.refund,
    required this.voidCount,
    required this.dp,
  });

  factory TutupKasir.fromJson(Map<String, dynamic> json) {
    return TutupKasir(
      userKode: json['user_kode'] ?? '',
      ip: json['ip'],
      tanggal: DateTime.parse(json['tanggal'] ?? DateTime.now().toString()),
      setoran: double.tryParse(json['setoran']?.toString() ?? '0') ?? 0.0,
      selisih: double.tryParse(json['selisih']?.toString() ?? '0') ?? 0.0,
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      card: double.tryParse(json['card']?.toString() ?? '0') ?? 0.0,
      other: double.tryParse(json['other']?.toString() ?? '0') ?? 0.0,
      refund: double.tryParse(json['refund']?.toString() ?? '0') ?? 0.0,
      voidCount: int.tryParse(json['void']?.toString() ?? '0') ?? 0,
      dp: double.tryParse(json['dp']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_kode': userKode,
      'ip': ip,
      'tanggal': tanggal.toIso8601String().split('T')[0],
      'setoran': setoran,
      'selisih': selisih,
      'cash': cash,
      'card': card,
      'other': other,
      'refund': refund,
      'void': voidCount,
      'dp': dp,
    };
  }
}

class SummaryPenjualan {
  final double cash;
  final double card;
  final double other;
  final double dp;

  SummaryPenjualan({
    required this.cash,
    required this.card,
    required this.other,
    required this.dp,
  });

  factory SummaryPenjualan.fromJson(Map<String, dynamic> json) {
    return SummaryPenjualan(
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      card: double.tryParse(json['card']?.toString() ?? '0') ?? 0.0,
      other: double.tryParse(json['other']?.toString() ?? '0') ?? 0.0,
      dp: double.tryParse(json['dp']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class Profile {
  final String namaProfile;
  final String address;
  final String noTelp;
  final String footer;
  final double sc;
  final double tax;
  final String otorisasi;

  Profile({
    required this.namaProfile,
    required this.address,
    required this.noTelp,
    required this.footer,
    required this.sc,
    required this.tax,
    required this.otorisasi,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      namaProfile: json['nama_profile'] ?? '',
      address: json['address'] ?? '',
      noTelp: json['no_telp'] ?? '',
      footer: json['footer'] ?? '',
      sc: double.tryParse(json['sc']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0,
      otorisasi: json['otorisasi'] ?? '',
    );
  }
}