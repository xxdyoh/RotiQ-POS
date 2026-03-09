class SalesItem {
  final int bulan;
  final int tahun;
  final String nomor;
  final DateTime tanggal;
  final String nama;
  final String varrian;
  final String salesType;
  final int qty;
  final int nilai;
  final String served;
  final String category;
  final String kasir;
  // final String category;
  // final int totalQty;
  // final double totalNilai;

  SalesItem({
    this.bulan = 0,
    this.tahun = 0,
    this.nomor = '',
    required this.tanggal,
    this.nama = '',
    this.varrian = '',
    this.salesType = '',
    this.qty = 0,
    this.nilai = 0,
    this.served = '',
    this.category = '',
    this.kasir = '',
  });

  factory SalesItem.fromJson(Map<String, dynamic> json) {
    return SalesItem(
      bulan: json['Bulan'] ?? 0,
      tahun: json['Tahun'] ?? 0,
      nomor: json['Nomor'] ?? '',
      tanggal: DateTime.parse(json['Tanggal'] ?? DateTime.now().toString()),
      nama: json['Nama'] ?? '',
      varrian: json['Varian'] ?? '',
      salesType: json['SalesType'] ?? '',
      qty: json['Qty'] ?? 0,
      nilai: json['Nilai'] ?? 0,
      served: json['Served'] ?? '',
      category: json['Category'] ?? '',
      kasir: json['Kasir'] ?? '',
    );
  }
}