class SalesDeposit {
  final String Kode;
  final String Tanggal;
  final double Setoran;
  final double Selisih;
  final double Cash;
  final double Card;
  final double Piutang;
  final double DpCash;
  final double DpBank;
  final double Biaya;
  final double Pendapatan;
  final double Total;

  SalesDeposit({
    required this.Kode,
    required this.Tanggal,
    required this.Setoran,
    required this.Selisih,
    required this.Cash,
    required this.Card,
    required this.Piutang,
    required this.DpCash,
    required this.DpBank,
    required this.Biaya,
    required this.Pendapatan,
    required this.Total,
  });

  factory SalesDeposit.fromJson(Map<String, dynamic> json) {
    return SalesDeposit(
      Kode: json['Kode']?.toString() ?? '',
      Tanggal: json['Tanggal'] ?? '',
      Setoran: _safeToDouble(json['Setoran']),
      Selisih: _safeToDouble(json['Selisih']),
      Cash: _safeToDouble(json['Cash']),
      Card: _safeToDouble(json['Card']),
      Piutang: _safeToDouble(json['Piutang']),
      DpCash: _safeToDouble(json['Dp_Cash']),
      DpBank: _safeToDouble(json['Dp_Bank']),
      Biaya: _safeToDouble(json['Biaya']),
      Pendapatan: _safeToDouble(json['Pendapatan']),
      Total: _safeToDouble(json['Total']),
    );
  }

  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}

class DepositSummary {
  final double totalSetoran;
  final double totalSelisih;
  final double totalCash;
  final double totalCard;
  final double totalPiutang;
  final double totalDpCash;
  final double totalDpBank;
  final double totalBiaya;
  final double totalPendapatan;
  final double totalGrandTotal;
  final int totalCount;

  DepositSummary({
    required this.totalSetoran,
    required this.totalSelisih,
    required this.totalCash,
    required this.totalCard,
    required this.totalPiutang,
    required this.totalDpCash,
    required this.totalDpBank,
    required this.totalBiaya,
    required this.totalPendapatan,
    required this.totalGrandTotal,
    required this.totalCount,
  });

  factory DepositSummary.fromJson(Map<String, dynamic> json) {
    return DepositSummary(
      totalSetoran: _safeToDouble(json['total_setoran']),
      totalSelisih: _safeToDouble(json['total_selisih']),
      totalCash: _safeToDouble(json['total_cash']),
      totalCard: _safeToDouble(json['total_card']),
      totalPiutang: _safeToDouble(json['total_piutang']),
      totalDpCash: _safeToDouble(json['total_dp_cash']),
      totalDpBank: _safeToDouble(json['total_dp_bank']),
      totalBiaya: _safeToDouble(json['total_biaya']),
      totalPendapatan: _safeToDouble(json['total_pendapatan']),
      totalGrandTotal: _safeToDouble(json['total_grand_total']),
      totalCount: _safeToInt(json['total_count']),
    );
  }

  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}