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

  // Initialize service
  Future<void> initialize() async {
    await _configService.loadConfigurations();
  }

  // Check if printer is connected and ready
  bool get isPrinterReady => _bluetoothService.isConnected;

  // Get connected device info
  String get connectedDeviceInfo {
    final device = _bluetoothService.connectedDevice;
    if (device == null) return 'No printer connected';
    return device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.toString();
  }

  // Get current paper size from active config
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

  // Get max characters per line based on paper size
  int get _maxCharsPerLine {
    switch (_currentPaperSize) {
      case PaperSize.mm58:
        return 32; // 58mm biasanya 32 karakter
      case PaperSize.mm80:
      default:
        return 48; // 80mm biasanya 48 karakter
    }
  }

  // printer_service.dart - SOLUSI SIMPLE
  // printer_service.dart - GUNAKAN CODE LAMA + TAMBAH GLOBAL DISCOUNT
  Future<bool> printReceipt({
    required String orderId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal, // ✅ SUDAH SETELAH DISKON ITEM (5810, bukan 7000)
    required double orderDiscountAmount, // ✅ DISKON GLOBAL SAJA
    required double grandTotal,
    required double paidAmount,
    required double change,
    required String paymentMethod,
    required String cashierName,
    required DateTime createdAt,
  }) async {
    if (!_bluetoothService.isConnected) {
      return false;
    }

    try {
      final profile = await CapabilityProfile.load(name: 'default');
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      // Initialize Printer
      bytes += generator.reset();
      bytes += generator.setGlobalCodeTable('CP1252');

      // Header
      bytes += generator.text('ROTI-Q',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));

      if (_currentPaperSize == PaperSize.mm80) {
        bytes += generator.text('Busukan RT 002 RW 017', styles: PosStyles(align: PosAlign.center));
        bytes += generator.text('Mojosongo Solo', styles: PosStyles(align: PosAlign.center));
      } else {
        bytes += generator.text('Mojosongo Solo', styles: PosStyles(align: PosAlign.center));
      }

      bytes += generator.text('0821-1532-9182', styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Order Information
      bytes += generator.text('No Bon: $orderId');
      bytes += generator.text('Tanggal: ${_formatDate(createdAt)}');
      bytes += generator.text('Waktu: ${_formatTime(createdAt)}');
      bytes += generator.text('Kasir: $cashierName');
      bytes += generator.text('Customer: $customerName');
      bytes += generator.hr();

      // Items List - DISKON ITEM TAMPIL DI BODY SAJA
      final maxProductNameLength = _currentPaperSize == PaperSize.mm58 ? 20 : 24;

      for (var item in items) {
        final productName = item['product_name'] ?? 'Unknown';
        final quantity = item['quantity'] ?? 1;
        final price = item['price'] ?? 0.0;
        final total = item['total'] ?? 0.0; // ✅ SUDAH SETELAH DISKON ITEM
        final discount = item['discount'] ?? 0.0;

        final truncatedName = _truncateProductName(productName, maxProductNameLength);
        bytes += generator.text(truncatedName);

        final qtyLine = 'x$quantity   ${_formatCurrency(price)}   ${_formatCurrency(total)}';
        bytes += generator.text(qtyLine, styles: PosStyles(align: PosAlign.right));

        // ✅ DISKON ITEM TAMPIL DI BODY (di bawah item)
        if (discount > 0) {
          bytes += generator.text('Disc: ${_formatCurrency(discount)}',
              styles: PosStyles(align: PosAlign.right));
        }

        // bytes += generator.feed(1);
      }

      bytes += generator.hr();

      final totalQty = items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));

      // Totals
      bytes += generator.row([
        PosColumn(text: 'Total Item', width: 6),
        PosColumn(text: '${items.length}', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Total Qty', width: 6),
        PosColumn(text: '$totalQty', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr();

      // ✅ FOOTER YANG SIMPLE:
      // Sub Total (sudah setelah diskon item)
      bytes += generator.row([
        PosColumn(text: 'Sub Total', width: 6),
        PosColumn(text: _formatCurrency(subtotal), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      // ❌ HILANGKAN "Disc Item" di footer
      // ✅ HANYA TAMPILKAN DISKON GLOBAL
      if (orderDiscountAmount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Disc', width: 6), // ✅ CUMA "Disc" saja
          PosColumn(text: '-${_formatCurrency(orderDiscountAmount)}', width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      // Grand Total
      bytes += generator.row([
        PosColumn(text: 'Grand Total', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: _formatCurrency(grandTotal), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);

      // Payment info
      bytes += generator.row([
        PosColumn(text: 'DP', width: 6),
        PosColumn(text: '0', width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.row([
        PosColumn(text: paymentMethod == 'cash' ? 'Tunai' : 'Transfer', width: 6),
        PosColumn(text: _formatCurrency(paidAmount), width: 6, styles: PosStyles(align: PosAlign.right)),
      ]);

      if (change > 0) {
        bytes += generator.row([
          PosColumn(text: 'Kembali', width: 6),
          PosColumn(text: _formatCurrency(change), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      // bytes += generator.feed(1);
      bytes += generator.text('IG: rotiq_solo', styles: PosStyles(align: PosAlign.center));
      // bytes += generator.feed(1);
      bytes += generator.text('Terima kasih', styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.cut(mode: PosCutMode.partial);

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Print receipt error: $e');
      return false;
    }
  }

  // Helper untuk truncate product name dengan length yang dinamis
  String _truncateProductName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 3)}...';
  }

  // Print test page
  Future<bool> printTestPage() async {
    if (!_bluetoothService.isConnected) {
      return false;
    }

    try {
      final profile = await CapabilityProfile.load(name: 'default');
      final generator = Generator(_currentPaperSize, profile);

      List<int> bytes = [];

      bytes += generator.reset();

      // HANYA 3 BARIS + CUT
      bytes += generator.text('TEST MINIMAL',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Baris 1');
      bytes += generator.text('Baris 2');
      bytes += generator.text('Baris 3 - END');

      // **LANGSUNG CUT TANPA FEED**
      bytes += generator.cut(mode: PosCutMode.partial);

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Test extreme minimal error: $e');
      return false;
    }
  }

  // Helper methods
  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}