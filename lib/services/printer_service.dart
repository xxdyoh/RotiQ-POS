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

  // Print receipt for POS order - FORMAT FAVORITE + PAPER SIZE SUPPORT
  Future<bool> printReceipt({
    required String orderId,
    required String customerName,
    required List<Map<String, dynamic>> items,
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

      // Header - ROTIQ Branding
      bytes += generator.text('ROTI-Q',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));

      if (_currentPaperSize == PaperSize.mm80) {
        bytes += generator.text('Busukan RT 002 RW 017',
            styles: PosStyles(align: PosAlign.center));
        bytes += generator.text('Mojosongo Solo',
            styles: PosStyles(align: PosAlign.center));
      } else {
        bytes += generator.text('Mojosongo Solo',
            styles: PosStyles(align: PosAlign.center));
      }

      bytes += generator.text('0821-1532-9182',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.hr();
      // bytes += generator.feed(1);

      // Order Information
      bytes += generator.text('No Bon: $orderId');
      bytes += generator.text('Tanggal: ${_formatDate(createdAt)}');
      bytes += generator.text('Waktu: ${_formatTime(createdAt)}');
      bytes += generator.text('Kasir: $cashierName');
      bytes += generator.text('Customer: $customerName');
      // bytes += generator.feed(1);
      bytes += generator.hr();
      // bytes += generator.feed(1);

      // Items Header
      // bytes += generator.text('ITEM', styles: PosStyles(bold: true));
      // bytes += generator.text('QTY   HARGA    TOTAL',
      //     styles: PosStyles(align: PosAlign.right));
      // bytes += generator.hr();
      // bytes += generator.feed(1);

      // Items List - Format favorit Anda
      final maxProductNameLength = _currentPaperSize == PaperSize.mm58 ? 20 : 24;

      for (var item in items) {
        final productName = item['product_name'] ?? 'Unknown';
        final quantity = item['quantity'] ?? 1;
        final price = item['price'] ?? 0.0;
        final total = item['total'] ?? 0.0;
        final discount = item['discount'] ?? 0.0;

        // Product name
        final truncatedName = _truncateProductName(productName, maxProductNameLength);
        bytes += generator.text(truncatedName);

        // Quantity and price line
        final qtyLine = 'x$quantity   ${_formatCurrency(price)}   ${_formatCurrency(total)}';
        bytes += generator.text(qtyLine, styles: PosStyles(align: PosAlign.right));

        // Discount if any
        if (discount > 0) {
          bytes += generator.text('Disc: ${_formatCurrency(discount)}',
              styles: PosStyles(align: PosAlign.right));
        }

        bytes += generator.feed(1);
      }

      bytes += generator.hr();
      // bytes += generator.feed(1);

      // ✅ SUMMARY SEPERTI PDF - FORMAT FAVORIT
      final totalQty = items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
      final subtotal = items.fold(0.0, (sum, item) => sum + (item['price'] ?? 0.0) * (item['quantity'] as int? ?? 0));
      final totalDiscount = items.fold(0.0, (sum, item) => sum + (item['discount'] ?? 0.0));

      // Totals seperti PDF
      bytes += generator.row([
        PosColumn(
          text: 'Total Item',
          width: 6,
        ),
        PosColumn(
          text: '${items.length}',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Total Qty',
          width: 6,
        ),
        PosColumn(
          text: '$totalQty',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();
      // bytes += generator.feed(1);

      // Financial summary seperti PDF
      bytes += generator.row([
        PosColumn(
          text: 'Sub Total',
          width: 6,
        ),
        PosColumn(
          text: _formatCurrency(subtotal),
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      if (totalDiscount > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Disc',
            width: 6,
          ),
          PosColumn(
            text: _formatCurrency(totalDiscount),
            width: 6,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.row([
        PosColumn(
          text: 'Grand Total',
          width: 6,
          styles: PosStyles(bold: true),
        ),
        PosColumn(
          text: _formatCurrency(grandTotal),
          width: 6,
          styles: PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'DP',
          width: 6,
        ),
        PosColumn(
          text: '0',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: paymentMethod == 'cash' ? 'Tunai' : 'Transfer', // ✅ TUNAI/TRANSFER
          width: 6,
        ),
        PosColumn(
          text: _formatCurrency(paidAmount),
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      if (change > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Kembali',
            width: 6,
          ),
          PosColumn(
            text: _formatCurrency(change),
            width: 6,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.feed(1);

      bytes += generator.text('IG: rotiq_solo',
          styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('Terima kasih',
          styles: PosStyles(align: PosAlign.center, bold: true));

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
      final profile = await CapabilityProfile.load();
      final generator = Generator(_currentPaperSize, profile); // ✅ PAPER SIZE DARI CONFIG

      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setGlobalFont(PosFontType.fontA);

      // Test content
      bytes += generator.text('ROTI-Q TEST PAGE',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Paper Size: ${_currentPaperSize == PaperSize.mm58 ? '58mm' : '80mm'}');
      bytes += generator.text('Connected: ${connectedDeviceInfo}');
      bytes += generator.feed(1);
      bytes += generator.text('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      bytes += generator.text('abcdefghijklmnopqrstuvwxyz');
      bytes += generator.text('1234567890!@#\$%^&*()');
      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text('Test successful!',
          styles: PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _bluetoothService.sendData(Uint8List.fromList(bytes));
    } catch (e) {
      print('Test print error: $e');
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