import 'package:flutter/material.dart';

class SerahTerimaItem {
  final int itemId;
  final String itemNama;
  final String tipe;
  final int qtySpk;
  final int qtyTerima;
  final String? keterangan;
  final int? nourut;

  SerahTerimaItem({
    required this.itemId,
    required this.itemNama,
    this.tipe = 'BJ',
    required this.qtySpk,
    required this.qtyTerima,
    this.keterangan,
    this.nourut,
  });

  // Getter untuk UI
  String get tipeLabel => tipe == 'BJ' ? 'BJ' : 'STJ';
  Color get tipeColor => tipe == 'BJ' ? const Color(0xFF4CC9F0) : const Color(0xFF06D6A0);
  IconData get tipeIcon => tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined;

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'tipe': tipe,
      'qty': qtyTerima,
      'keterangan': keterangan ?? '',
      'nourut': nourut,
    };
  }

  SerahTerimaItem copyWith({
    int? itemId,
    String? itemNama,
    String? tipe,
    int? qtySpk,
    int? qtyTerima,
    String? keterangan,
    int? nourut,
  }) {
    return SerahTerimaItem(
      itemId: itemId ?? this.itemId,
      itemNama: itemNama ?? this.itemNama,
      tipe: tipe ?? this.tipe,
      qtySpk: qtySpk ?? this.qtySpk,
      qtyTerima: qtyTerima ?? this.qtyTerima,
      keterangan: keterangan ?? this.keterangan,
      nourut: nourut ?? this.nourut,
    );
  }
}