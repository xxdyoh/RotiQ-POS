import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'bluetooth_service.dart';
import 'printer_config_service.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BluetoothService _bluetoothService = BluetoothService();
  final PrinterConfigService _configService = PrinterConfigService();

  Future<void> initialize() async {
    await _configService.loadConfigurations();
  }

  bool get isPrinterReady => _bluetoothService.isConnected;

  String get connectedDeviceInfo {
    final device = _bluetoothService.connectedDevice;
    if (device == null) return 'No printer connected';
    return device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.toString();
  }

  PaperSize get _currentPaperSize {
    final activeConfig = _configService.activeConfig;

    switch (activeConfig?.type) {
      case PrinterType.thermal58mm:
        return PaperSize.mm58;
      case PrinterType.thermal80mm:
      default:
        return PaperSize.mm80;
    }
  }

  Future<bool> printTestPage() async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung');
      return false;
    }

    try {
      print('🟡 Memulai test print...');

      // Gunakan default profile
      final profile = await CapabilityProfile.load();
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      // Reset printer
      bytes += generator.reset();

      // Set encoding untuk Indonesia
      bytes += generator.setGlobalCodeTable('CP1252');

      // Test teks sederhana
      bytes += generator.text('TEST PRINT SEDERHANA',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));

      bytes += generator.hr();

      bytes += generator.text('Baris 1: Hello World',
          styles: PosStyles(align: PosAlign.left));

      bytes += generator.text('Baris 2: 1234567890',
          styles: PosStyles(align: PosAlign.left));

      bytes += generator.text('Baris 3: Rp 50.000',
          styles: PosStyles(align: PosAlign.left));

      bytes += generator.hr();

      bytes += generator.text('Test Selesai',
          styles: PosStyles(align: PosAlign.center, bold: true));

      // Feed dan cut
      bytes += generator.feed(2);
      bytes += generator.cut(mode: PosCutMode.partial);

      print('🟡 Bytes yang akan dikirim: ${bytes.length} bytes');

      final result = await _bluetoothService.sendData(Uint8List.fromList(bytes));

      print(result ? '✅ Test print berhasil' : '❌ Test print gagal');
      return result;
    } catch (e) {
      print('❌ Error test print: $e');
      print('❌ Stack trace: ${e.toString()}');
      return false;
    }
  }

  Future<bool> printReceipt({
    required String orderId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double orderDiscountAmount,
    required double grandTotal,
    required double paidAmount,
    required double change,
    required String cashierName,
    required DateTime createdAt,
    List<Map<String, dynamic>> paymentMethods = const [],
  }) async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung!');
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.text('ROTI-Q',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text('Mojosongo Solo',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.text('0821-1532-9182',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.hr(ch: '-');
      bytes += generator.text('No Bon: $orderId');
      bytes += generator.text('Tanggal: ${_formatDate(createdAt)}');
      bytes += generator.text('Waktu: ${_formatTime(createdAt)}');
      bytes += generator.text('Kasir: $cashierName');
      bytes += generator.text('Customer: $customerName');
      bytes += generator.hr(ch: '-');

      if (items.isEmpty) {
        bytes += generator.text('** TIDAK ADA ITEM **',
            styles: PosStyles(align: PosAlign.center));
      } else {
        for (var item in items) {
          final productName = item['product_name']?.toString() ?? 'Unknown';
          final quantity = item['quantity'] ?? 1;
          final price = item['price'] ?? 0.0;
          final total = item['total'] ?? 0.0;

          final discountAmount = (item['discount'] as num?)?.toDouble() ?? 0.0;
          final discountType = item['discount_type']?.toString() ?? 'percent';
          final discountPercent = (item['discount_percent'] as num?)?.toDouble() ?? 0.0;
          final discountRp = (item['discount_rp'] as num?)?.toDouble() ?? 0.0;

          String displayName = productName;
          if (displayName.length > 20) {
            displayName = displayName.substring(0, 17) + '...';
          }

          bytes += generator.text(displayName);

          final qtyLine = '${quantity}x ${_formatCurrency(price)} = ${_formatCurrency(total)}';
          bytes += generator.text(qtyLine, styles: PosStyles(align: PosAlign.right));

          // if (item['discount'] != null && (item['discount'] as num) > 0) {
          //   bytes += generator.text('Disc: ${_formatCurrency(item['discount'])}',
          //       styles: PosStyles(align: PosAlign.right));
          // }
          if (discountAmount > 0) {
            if (discountType == 'rp' && discountRp > 0) {
              bytes += generator.text('Disc: ${_formatCurrency(discountRp)}',
                  styles: PosStyles(align: PosAlign.right));
            } else if (discountType == 'percent' && discountPercent > 0) {
              bytes += generator.text('Disc: ${_formatCurrency(discountAmount)}',
                  styles: PosStyles(align: PosAlign.right));
            } else {
              bytes += generator.text('Disc: ${_formatCurrency(discountAmount)}',
                  styles: PosStyles(align: PosAlign.right));
            }
          }
        }
      }

      bytes += generator.hr(ch: '-');

      bytes += generator.row([
        PosColumn(text: 'Sub Total', width: 6),
        PosColumn(text: _formatCurrency(subtotal), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      if (orderDiscountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Disc', width: 6),
          PosColumn(text: '-${_formatCurrency(orderDiscountAmount)}', width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'Grand Total', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: _formatCurrency(grandTotal), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);

      // bytes += generator.hr(ch: '-');

      // Cash payments
      final cashTotal = paymentMethods
          .where((p) => p['type'] == 'cash')
          .fold(0.0, (sum, p) => sum + ((p['amount'] as num).toDouble()));

      if (cashTotal > 0) {
        bytes += generator.row([
          PosColumn(text: 'Cash', width: 6),
          PosColumn(text: _formatCurrency(cashTotal), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      // EDC payments
      final edcPayments = paymentMethods.where((p) => p['type'] == 'edc');
      for (var edc in edcPayments) {
        final amount = (edc['amount'] as num).toDouble();
        final subType = edc['subType']?.toString() ?? 'Transfer';
        bytes += generator.row([
          PosColumn(text: subType, width: 6),
          PosColumn(text: _formatCurrency(amount), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      // DP payments
      final dpPayments = paymentMethods.where((p) => p['type'] == 'dp');
      for (var dp in dpPayments) {
        final amount = (dp['amount'] as num).toDouble();
        final reference = dp['reference']?.toString() ?? '';
        bytes += generator.row([
          PosColumn(text: 'DP', width: 6),
          PosColumn(text: _formatCurrency(amount), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      // Piutang payments
      final piutangPayments = paymentMethods.where((p) => p['type'] == 'piutang');
      for (var piutang in piutangPayments) {
        final amount = (piutang['amount'] as num).toDouble();
        final subType = piutang['subType']?.toString() ?? 'Piutang';
        bytes += generator.row([
          PosColumn(text: subType, width: 6),
          PosColumn(text: _formatCurrency(amount), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'Kembali', width: 6),
        PosColumn(text: _formatCurrency(change), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr(ch: '-');
      bytes += generator.text('IG: rotiq_solo', styles: PosStyles(align: PosAlign.center));
      bytes += generator.text('Terima kasih', styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.cut(mode: PosCutMode.partial);

      final result = await _bluetoothService.sendData(Uint8List.fromList(bytes));

      return result;
    } catch (e) {
      print('❌ Error print receipt: $e');
      print('❌ Stack trace: ${e.toString()}');
      return false;
    }
  }

  Future<bool> printTestExtreme() async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung');
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      bytes += generator.text('TEST PRINT', styles: PosStyles(align: PosAlign.center));
      bytes += generator.text('Baris 1');
      bytes += generator.text('Baris 2');
      bytes += generator.text('Baris 3');
      bytes += generator.cut();

      final result = await _bluetoothService.sendData(Uint8List.fromList(bytes));

      print(result ? '✅ Test simple berhasil' : '❌ Test simple gagal');
      return result;
    } catch (e) {
      print('❌ Error test simple: $e');
      return false;
    }
  }

  Future<bool> checkPrinterConnection() async {
    final isConnected = _bluetoothService.isConnected;
    print('🔍 Printer connection check: $isConnected');

    if (isConnected) {
      final device = _bluetoothService.connectedDevice;
      print('🔍 Connected device: ${device?.platformName} (${device?.remoteId})');
    }

    return isConnected;
  }

  String _formatCurrency(double amount) {
    if (amount.isNaN || amount.isInfinite) return 'Rp 0';

    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDate(DateTime date) {
    try {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '01/01/2024';
    }
  }

  String _formatTime(DateTime date) {
    try {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  Future<bool> printStrukTutupKasir({
    required Map<String, dynamic> mainData,
    required List<dynamic> payments,
    required List<dynamic> biaya,
    required List<dynamic> pendapatan,
    required List<dynamic> uangMuka,
  }) async {
    if (!_bluetoothService.isConnected) {
      return false;
    }

    try {
      final profile = await CapabilityProfile.load(name: 'default');
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalCodeTable('CP1252');

      final cash = _safeToInt(mainData['cash']);
      final card = _safeToInt(mainData['card']);
      final other = _safeToInt(mainData['other']);
      final dp = _safeToInt(mainData['dp']);
      final setoran = _safeToInt(mainData['setoran']);
      final dpCash = _safeToInt(mainData['Dp_Cash']);
      final biayaLain = _safeToInt(mainData['Biaya']);
      final pendapatanLain = _safeToInt(mainData['Pendapatan']);

      bytes += generator.text('ROTI-Q',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Setoran Kasir',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(1);

      print('DISNI YAA ${mainData['tanggal']}');
      final tanggal = DateTime.parse(mainData['tanggal'] ?? DateTime.now().toString());
      bytes += generator.row([
        PosColumn(text: 'Tanggal', width: 6),
        PosColumn(text: _formatDate(tanggal), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Nama Kasir', width: 6),
        PosColumn(text: mainData['nmkasir'] ?? '', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Cash', width: 6),
        PosColumn(text: _formatCurrencyInt(cash), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Card', width: 6),
        PosColumn(text: _formatCurrencyInt(card), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Piutang', width: 6),
        PosColumn(text: _formatCurrencyInt(other), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr();

      final totalPenjualan = cash + card + other;
      bytes += generator.row([
        PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: _formatCurrencyInt(totalPenjualan), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.feed(1);

      if (payments.isNotEmpty) {
        int totalPayments = 0;

        for (var payment in payments) {
          final tipe = payment['Tipe'] ?? '';
          final keterangan = payment['keterangan'] ?? '';
          final jumlah = _safeToInt(payment['jumlah']);
          totalPayments += jumlah;

          bytes += generator.row([
            PosColumn(text: '$keterangan', width: 6),
            PosColumn(text: _formatCurrencyInt(jumlah), width: 6, styles: PosStyles(align: PosAlign.right)),
          ]);
        }

        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: _formatCurrencyInt(totalPayments), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.feed(1);
      }

      if (uangMuka.isNotEmpty) {
        bytes += generator.text('Uang Muka Penjualan',
            styles: PosStyles(align: PosAlign.left, bold: true));

        int totalUangMuka = 0;
        for (var um in uangMuka) {
          final rekNama = um['rek_nama'] ?? '';
          final keterangan = um['jurd_keterangan'] ?? '';
          final debet = _safeToInt(um['jurd_debet']);
          totalUangMuka += debet;

          final description = '$rekNama $keterangan';
          bytes += generator.row([
            PosColumn(text: '$description', width: 6),
            PosColumn(text: _formatCurrencyInt(debet), width: 6, styles: PosStyles(align: PosAlign.right)),
          ]);
        }

        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: _formatCurrencyInt(totalUangMuka), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.feed(1);
      }

      if (biaya.isNotEmpty) {
        bytes += generator.text('Biaya Biaya',
            styles: PosStyles(align: PosAlign.left, bold: true));

        int totalBiaya = 0;
        for (var b in biaya) {
          final rekNama = b['rek_nama'] ?? '';
          final keterangan = b['jurd_keterangan'] ?? '';
          final debet = _safeToInt(b['jurd_debet']);
          totalBiaya += debet;

          final description = '$rekNama $keterangan';
          bytes += generator.row([
            PosColumn(text: '$description', width: 6),
            PosColumn(text: _formatCurrencyInt(debet), width: 6, styles: PosStyles(align: PosAlign.right)),
          ]);
        }

        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: _formatCurrencyInt(totalBiaya), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.feed(1);
      }

      if (pendapatan.isNotEmpty) {
        bytes += generator.text('Pendapatan Lain',
            styles: PosStyles(align: PosAlign.left, bold: true));

        int totalPendapatan = 0;
        for (var p in pendapatan) {
          final rekNama = p['rek_nama'] ?? '';
          final keterangan = p['jurd_keterangan'] ?? '';
          final kredit = _safeToInt(p['jurd_kredit']);
          totalPendapatan += kredit;

          final description = '$rekNama $keterangan';
          bytes += generator.row([
            PosColumn(text: '$description', width: 6),
            PosColumn(text: _formatCurrencyInt(kredit), width: 6, styles: PosStyles(align: PosAlign.right)),
          ]);
        }

        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
          PosColumn(text: _formatCurrencyInt(totalPendapatan), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
        ]);
        bytes += generator.feed(1);
      }

      bytes += generator.text('Setoran dan Selisih',
          styles: PosStyles(align: PosAlign.left, bold: true));

      final totalKas = cash + dpCash + pendapatanLain - biayaLain;
      final selisih = setoran - (dpCash + cash + pendapatanLain - biayaLain);

      bytes += generator.text('Cash + DP Cash + Pendapatan - Biaya :');
      bytes += generator.text(_formatCurrencyInt(totalKas),
          styles: PosStyles(align: PosAlign.right));

      bytes += generator.row([
        PosColumn(text: 'Setoran', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: _formatCurrencyInt(setoran), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Selisih', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: _formatCurrencyInt(selisih), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.cut(mode: PosCutMode.partial);

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Print struk tutup kasir error: $e');
      return false;
    }
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    } else if (value is double) {
      return value.round();
    } else if (value is String) {
      return int.tryParse(value) ?? 0;
    } else {
      return 0;
    }
  }

  String _formatCurrencyInt(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  // Helper methods
  // String _formatCurrency(double amount) {
  //   return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
  //     RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  //         (Match m) => '${m[1]}.',
  //   )}';
  // }

  // String _formatDate(DateTime date) {
  //   return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  // }
  //
  // String _formatTime(DateTime date) {
  //   return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  // }

  // int _safeToInt(dynamic value) {
  //   if (value == null) return 0;
  //   if (value is int) return value;
  //   if (value is double) return value.round();
  //   if (value is String) return int.tryParse(value) ?? 0;
  //   return 0;
  // }

  // String _formatCurrencyInt(int amount) {
  //   return 'Rp ${amount.toString().replaceAllMapped(
  //     RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  //         (Match m) => '${m[1]}.',
  //   )}';
  // }
}