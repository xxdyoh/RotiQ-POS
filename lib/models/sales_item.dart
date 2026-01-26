class SalesItem {
  final String nama;
  final String category;
  final int totalQty;
  final double totalNilai;

  SalesItem({
    required this.nama,
    required this.category,
    required this.totalQty,
    required this.totalNilai,
  });

  factory SalesItem.fromJson(Map<String, dynamic> json) {
    return SalesItem(
      nama: json['nama'] ?? '',
      category: json['category'] ?? '',
      totalQty: (json['total_qty'] as num?)?.toInt() ?? 0,
      totalNilai: (json['total_nilai'] as num?)?.toDouble() ?? 0.0,
    );
  }
}