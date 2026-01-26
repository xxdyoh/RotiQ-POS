import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart' if (dart.library.io) 'package:web_socket_channel/io.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/device.dart';
import '../models/receipt.dart';
import '../utils/platform_detector.dart';

class Logger {
  static void info(String message) {
    print('[INFO] $message');
  }
}

class WebSocketPrinter {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _barcodeController = StreamController<String>.broadcast();

  String _currentStatus = 'Disconnected';
  bool _isConnected = false;
  String _bridgeUrl = 'ws://localhost:8765';
  bool _isConnecting = false;

  WebSocketChannel? get channel => _channel;

  Device? get connectedDevice => _isConnected
      ? Device(
    id: 'bridge_${DateTime.now().millisecondsSinceEpoch}',
    name: 'WebSocket Printer Bridge',
    type: DeviceType.network,
    address: _bridgeUrl,
    isConnected: true,
  )
      : null;

  bool get isConnected => _isConnected;

  String get platformName => 'WebSocket Bridge';

  Stream<String> get statusStream => _statusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get barcodeStream => _barcodeController.stream;

  String get currentStatus => _currentStatus;
  String get bridgeUrl => _bridgeUrl;

  void setBridgeUrl(String url) {
    _bridgeUrl = url;
    print('Bridge URL updated to: $url');
  }

  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
    Logger.info('WebSocket Status: $status');
  }

  Future<bool> connect(Device device) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _updateStatus('Connecting to ${device.name}...');

    try {
      // Cleanup existing connection
      await _cleanupConnection();

      print('🔗 Connecting to $_bridgeUrl...');

      // Buat WebSocket channel berdasarkan platform
      _channel = WebSocketChannel.connect(Uri.parse(_bridgeUrl));

      // Setup stream listener
      _streamSubscription = _channel!.stream.listen(
            (message) => _handleMessage(message),
        onError: (error) {
          print('WebSocket error: $error');
          _updateStatus('Connection error');
          _isConnected = false;
          _connectionController.add(false);
          _isConnecting = false;
        },
        onDone: () {
          print('WebSocket connection closed');
          _updateStatus('Disconnected from bridge');
          _isConnected = false;
          _connectionController.add(false);
          _isConnecting = false;
        },
      );

      // Kirim PING untuk test connection
      _channel!.sink.add('PING');

      // Tunggu response
      await Future.delayed(const Duration(seconds: 2));

      _isConnecting = false;
      return _isConnected;

    } catch (e) {
      print('Connection failed: $e');
      await _cleanupConnection();
      _updateStatus('Connection failed: ${e.toString().split('\n').first}');
      _isConnecting = false;
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    print('📨 WebSocket message: $message');

    if (message is String) {
      if (message == 'PONG') {
        _isConnected = true;
        _connectionController.add(true);
        _updateStatus('Connected to bridge at $_bridgeUrl');
      }
      else if (message.startsWith('BARCODE:')) {
        final barcode = message.substring('BARCODE:'.length);
        print('📷 Barcode received: $barcode');
        _barcodeController.add(barcode);
      }
      else if (message.startsWith('CASH_DRAWER:')) {
        print('💰 Cash drawer: $message');
      }
      else if (message.startsWith('PRINT_')) {
        print('🖨️  Print status: $message');
      }
    }
  }

  Future<void> _cleanupConnection() async {
    // Cancel subscription
    if (_streamSubscription != null) {
      await _streamSubscription!.cancel();
      _streamSubscription = null;
    }

    // Close channel
    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        print('Error closing channel: $e');
      }
      _channel = null;
    }

    // Reset state
    _isConnected = false;
    _connectionController.add(false);
  }

  Future<void> disconnect() async {
    _updateStatus('Disconnecting...');
    await _cleanupConnection();
    _updateStatus('Disconnected');
  }

  Future<bool> printRawBytes(Uint8List bytes) async {
    if (!_isConnected || _channel == null) {
      _updateStatus('Not connected to bridge');
      return false;
    }

    try {
      final base64Data = base64.encode(bytes);
      _channel!.sink.add('PRINT_BASE64:$base64Data');
      _updateStatus('Raw data sent to bridge');
      return true;
    } catch (e) {
      print('❌ Raw print error: $e');
      _updateStatus('Raw print error: $e');
      return false;
    }
  }

  // Printing methods
  Future<bool> printReceipt(Receipt receipt) async {
    if (!_isConnected || _channel == null) {
      _updateStatus('Not connected to bridge');
      return false;
    }

    _updateStatus('Sending receipt to bridge...');

    try {
      // Generate receipt data (gunakan PaperSize.mm80 sesuai project asli)
      final bytes = await _buildReceiptBytes(receipt);
      print('📦 Generated ${bytes.length} bytes');

      // Convert to Base64 for web
      final base64Data = base64.encode(bytes);

      // Kirim dengan prefix PRINT_BASE64:
      _channel!.sink.add('PRINT_BASE64:$base64Data');
      _updateStatus('Receipt sent to bridge');

      return true;
    } catch (e) {
      print('❌ Print error: $e');
      _updateStatus('Print error: $e');
      return false;
    }
  }

  Future<Uint8List> _buildReceiptBytes(Receipt receipt) async {
    // Load capability profile
    final profile = await CapabilityProfile.load(name: 'TM-T88V');
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // Header
    bytes += generator.text(
      receipt.storeName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    );

    bytes += generator.text(
      receipt.storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // Transaction Info
    bytes += generator.row([
      PosColumn(text: 'No. Transaksi:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: receipt.transactionId, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Tanggal:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '${receipt.date.day}/${receipt.date.month}/${receipt.date.year}',
        width: 6,
      ),
    ]);

    bytes += generator.hr();

    // Items
    for (var item in receipt.items) {
      bytes += generator.row([
        PosColumn(text: item.name, width: 8),
        PosColumn(text: '${item.quantity}x', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: 'Rp ${item.total.toStringAsFixed(0)}', width: 2, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // Summary
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 8),
      PosColumn(text: 'Rp ${receipt.subtotal.toStringAsFixed(0)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Grand Total:', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Rp ${receipt.grandTotal.toStringAsFixed(0)}', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    // Footer
    bytes += generator.text(
      'Terima kasih',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  Future<bool> printTest() async {
    if (!_isConnected) {
      _updateStatus('Not connected to bridge');
      return false;
    }

    try {
      // Buat test receipt
      final receipt = Receipt.testReceipt();
      return await printReceipt(receipt);
    } catch (e) {
      print('Test print error: $e');
      _updateStatus('Test print error: $e');
      return false;
    }
  }

  // POS Hardware Controls
  Future<void> enableScanner() async {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add('SCANNER:ENABLE');
    print('🔫 Scanner enabled requested');
  }

  Future<void> disableScanner() async {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add('SCANNER:DISABLE');
    print('🔫 Scanner disabled requested');
  }

  Future<bool> openCashDrawer() async {
    if (!_isConnected || _channel == null) {
      _updateStatus('Not connected to bridge');
      return false;
    }

    try {
      _channel!.sink.add('OPEN_CASH_DRAWER');
      _updateStatus('Opening cash drawer...');
      return true;
    } catch (e) {
      print('❌ Cash drawer error: $e');
      return false;
    }
  }

  void dispose() {
    _cleanupConnection();
    _statusController.close();
    _connectionController.close();
    _barcodeController.close();
  }
}