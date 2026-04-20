import 'package:flutter/material.dart';

class MutasiInItem {
  final int itemId;
  final String itemNama;
  final String tipe; // 'BJ' atau 'STJ'
  int qty;
  int qtyMutasi;
  String? referensi;

  MutasiInItem({
    required this.itemId,
    required this.itemNama,
    this.tipe = 'BJ',
    this.qty = 0,
    this.qtyMutasi = 0,
    this.referensi,
  });

  factory MutasiInItem.fromJson(Map<String, dynamic> json) {
    return MutasiInItem(
      itemId: int.tryParse(json['item_id']?.toString() ?? '0') ?? 0,
      itemNama: json['item_nama'] ?? '',
      tipe: json['tipe'] ?? 'BJ',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      qtyMutasi: int.tryParse(json['qty_mutasi']?.toString() ?? '0') ?? 0,
      referensi: json['referensi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_nama': itemNama,
      'tipe': tipe,
      'qty': qty,
      'referensi': referensi,
    };
  }

  MutasiInItem copyWith({
    int? qty,
    int? qtyMutasi,
    String? referensi,
  }) {
    return MutasiInItem(
      itemId: itemId,
      itemNama: itemNama,
      tipe: tipe,
      qty: qty ?? this.qty,
      qtyMutasi: qtyMutasi ?? this.qtyMutasi,
      referensi: referensi ?? this.referensi,
    );
  }

  String get tipeLabel => tipe == 'BJ' ? 'Barang Jadi' : 'Setengah Jadi';
  Color get tipeColor => tipe == 'BJ' ? const Color(0xFF4CC9F0) : const Color(0xFF06D6A0);
  IconData get tipeIcon => tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined;
}