class Cabang {
  final String kode;
  final String nama;
  final String? alamat;
  final String? kota;
  final String? telp;
  final int aktif;
  final String database;
  final String host;
  final String user;
  final String password;
  final String port;
  final String jenis;

  Cabang({
    required this.kode,
    required this.nama,
    this.alamat,
    this.kota,
    this.telp,
    required this.aktif,
    required this.database,
    required this.host,
    required this.user,
    required this.password,
    required this.port,
    required this.jenis,
  });

  factory Cabang.fromJson(Map<String, dynamic> json) {
    return Cabang(
      kode: json['cbg_kode'] ?? '',
      nama: json['cbg_nama'] ?? '',
      alamat: json['cbg_alamat'],
      kota: json['cbg_kota'],
      telp: json['cbg_telp'],
      aktif: json['cbg_aktif'] ?? 0,
      database: json['cbg_database'] ?? '',
      host: json['cbg_host'] ?? '',
      user: json['cbg_user'] ?? '',
      password: json['cbg_password'] ?? '',
      port: json['cbg_port']?.toString() ?? '3306',
      jenis: json['cbg_jenis'] ?? 'outlet',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cbg_kode': kode,
      'cbg_nama': nama,
      'cbg_alamat': alamat,
      'cbg_kota': kota,
      'cbg_telp': telp,
      'cbg_aktif': aktif,
      'cbg_database': database,
      'cbg_host': host,
      'cbg_user': user,
      'cbg_password': password,
      'cbg_port': port,
      'cbg_jenis': jenis,
    };
  }

  @override
  String toString() {
    return '$nama ($kode)';
  }
}