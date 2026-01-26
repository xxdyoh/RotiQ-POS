class UangMuka {
  final String umNomor;
  final DateTime umTanggal;
  final String umCustomer;
  final double umNilai;
  final String umJenisBayar;
  final String? umKeterangan;
  final int umIsRealisasi;

  UangMuka({
    required this.umNomor,
    required this.umTanggal,
    required this.umCustomer,
    required this.umNilai,
    required this.umJenisBayar,
    this.umKeterangan,
    this.umIsRealisasi = 0,
  });

  factory UangMuka.fromJson(Map<String, dynamic> json) {
    return UangMuka(
      umNomor: json['um_nomor'] ?? '',
      umTanggal: DateTime.parse(json['um_tanggal'] ?? DateTime.now().toString()),
      umCustomer: json['um_customer'] ?? '',
      umNilai: double.tryParse(json['um_nilai']?.toString() ?? '0') ?? 0.0,
      umJenisBayar: json['um_jenisbayar'] ?? 'Cash',
      umKeterangan: json['um_keterangan'],
      umIsRealisasi: int.tryParse(json['um_isrealisasi']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'um_nomor': umNomor,
      'um_tanggal': umTanggal.toIso8601String().split('T')[0],
      'um_customer': umCustomer,
      'um_nilai': umNilai,
      'um_jenisbayar': umJenisBayar,
      'um_keterangan': umKeterangan,
      'um_isrealisasi': umIsRealisasi,
    };
  }
}