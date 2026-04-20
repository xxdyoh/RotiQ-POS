import 'package:flutter/material.dart';

class MintaItem {
  final int itemId;
  final String itemNama;
  final String tipe;
  final int qty;
  final String? keterangan;

  MintaItem({
    required this.itemId,
    required this.itemNama,
    this.tipe = 'BJ',
    required this.qty,
    this.keterangan,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'tipe': tipe,
      'qty': qty,
      'keterangan': keterangan ?? '',
    };
  }

  // Getter untuk label tipe
  String get tipeLabel {
    return tipe == 'BJ' ? 'Barang Jadi' : 'Setengah Jadi';
  }

  // Getter untuk warna tipe
  Color get tipeColor {
    return tipe == 'BJ' ? const Color(0xFF4CC9F0) : const Color(0xFF06D6A0);
  }

  // Getter untuk icon tipe
  IconData get tipeIcon {
    return tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined;
  }
}