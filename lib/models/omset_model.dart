class OmsetData {
  final String label;
  final String tanggal;
  final String hari;
  final String week;
  final String bulan;
  final double nilai;
  final String growth;

  OmsetData({
    required this.label,
    this.tanggal = '',
    this.hari = '',
    this.week = '',
    this.bulan = '',
    required this.nilai,
    this.growth = '-',
  });

  factory OmsetData.fromJson(Map<String, dynamic> json) {
    return OmsetData(
      label: json['label']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      hari: json['hari']?.toString() ?? '',
      week: json['week']?.toString() ?? '',
      bulan: json['bulan']?.toString() ?? '',
      nilai: (json['nilai'] ?? 0).toDouble(),
      growth: json['growth']?.toString() ?? '-',
    );
  }
}