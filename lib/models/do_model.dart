import 'package:flutter/material.dart';

class MutasiItem {
  final int itemId;
  final String itemNama;
  final String tipe;
  final int qtyMinta;
  int qty;
  String? keterangan;
  final int? nourut;

  MutasiItem({
    required this.itemId,
    required this.itemNama,
    required this.tipe,
    this.qtyMinta = 0,
    this.qty = 0,
    this.keterangan,
    this.nourut,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'tipe': tipe,
      'qty': qty,
      'keterangan': keterangan ?? '',
    };
  }

  MutasiItem copyWith({
    int? qty,
    String? keterangan,
  }) {
    return MutasiItem(
      itemId: itemId,
      itemNama: itemNama,
      tipe: tipe,
      qtyMinta: qtyMinta,
      qty: qty ?? this.qty,
      keterangan: keterangan ?? this.keterangan,
      nourut: nourut,
    );
  }

  String get tipeLabel => tipe == 'BJ' ? 'Barang Jadi' : 'Setengah Jadi';
  Color get tipeColor => tipe == 'BJ' ? const Color(0xFF4CC9F0) : const Color(0xFF06D6A0);
  IconData get tipeIcon => tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined;
}

class Gudang {
  final String kode;
  final String nama;
  final String? penanggungjawab;
  final String? keterangan;

  Gudang({
    required this.kode,
    required this.nama,
    this.penanggungjawab,
    this.keterangan,
  });

  factory Gudang.fromJson(Map<String, dynamic> json) {
    return Gudang(
      kode: json['gdg_kode'] ?? '',
      nama: json['gdg_nama'] ?? '',
      penanggungjawab: json['gdg_penanggungjawab'],
      keterangan: json['gdg_keterangan'],
    );
  }

  @override
  String toString() {
    return '$nama ($kode)';
  }
}