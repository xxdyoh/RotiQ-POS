class SetengahJadi {
  final int stjId;
  final String stjNama;
  final double stjStock;

  SetengahJadi({
    required this.stjId,
    required this.stjNama,
    required this.stjStock,
  });

  factory SetengahJadi.fromJson(Map<String, dynamic> json) {
    return SetengahJadi(
      stjId: int.tryParse(json['stj_id']?.toString() ?? '0') ?? 0,
      stjNama: json['stj_nama']?.toString() ?? '',
      stjStock: double.tryParse(json['stj_stock']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stj_id': stjId,
      'stj_nama': stjNama,
      'stj_stock': stjStock,
    };
  }
}