import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;
import 'web_socket_printer.dart' as ws_demo;
import '../utils/platform_detector.dart';
import 'bluetooth_service.dart';
import 'printer_config_service.dart';
import 'printer_service.dart';
import '../models/device.dart';
import '../models/receipt.dart';
import 'receipt_template.dart';

abstract class BasePrinterService {
  Future<List<Device>> scanDevices();
  Future<bool> connect(Device device);
  Future<void> disconnect();
  Device? get connectedDevice;
  bool get isConnected;
  Stream<bool> get connectionStream;
  Stream<String> get statusStream;
  String get currentStatus;
  String get platformName;
  bool get isPrinterReady => isConnected;

  Future<bool> printTest();
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
    required List<Map<String, dynamic>> paymentMethods,
  });

  Future<bool> printStrukTutupKasir({
    required Map<String, dynamic> mainData,
    required List<dynamic> payments,
    required List<dynamic> biaya,
    required List<dynamic> pendapatan,
    required List<dynamic> uangMuka,
  });

  Future<bool> printUangMukaReceipt({
    required String nomor,
    required DateTime tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
    bool isRealisasi = false,
  });

  Future<bool> checkConnection();
  Future<void> autoConnect();

  Stream<String> get barcodeStream;
  bool get isScannerEnabled;
  Future<void> enableScanner();
  Future<void> disableScanner();
  void simulateBarcodeScan(String barcode);
}

// Bluetooth Printer Implementation (Android/iOS)
class BluetoothPrinterServiceImpl extends BasePrinterService {
  final BluetoothService _bluetoothService = BluetoothService();
  final PrinterConfigService _configService = PrinterConfigService();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  String _currentStatus = 'Disconnected';
  final StreamController<String> _barcodeController = StreamController<String>.broadcast();
  bool _scannerEnabled = false;

  @override
  Device? get connectedDevice {
    if (!_bluetoothService.isConnected) return null;
    final device = _bluetoothService.connectedDevice;
    if (device == null) return null;

    return Device(
      id: device.remoteId.toString(),
      name: device.platformName.isNotEmpty ? device.platformName : 'Bluetooth Printer',
      type: DeviceType.bluetooth,
      address: device.remoteId.toString(),
      isConnected: true,
    );
  }

  @override
  bool get isConnected => _bluetoothService.isConnected;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  String get currentStatus => _currentStatus;

  @override
  String get platformName => 'Bluetooth';

  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  @override
  Future<List<Device>> scanDevices() async {
    try {
      final devices = await _bluetoothService.getBondedDevices();
      return devices.map((device) => Device(
        id: device.remoteId.toString(),
        name: device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
        type: DeviceType.bluetooth,
        address: device.remoteId.toString(),
        isConnected: false,
      )).toList();
    } catch (e) {
      _updateStatus('Scan error: $e');
      return [];
    }
  }

  @override
  Future<bool> connect(Device device) async {
    try {
      _updateStatus('Connecting to ${device.name}...');

      final blueDevices = await _bluetoothService.getBondedDevices();
      final targetDevice = blueDevices.firstWhere(
            (d) => d.remoteId.toString() == device.id,
        orElse: () => throw Exception('Device not found'),
      );

      final success = await _bluetoothService.connectToDevice(targetDevice);

      if (success) {
        _updateStatus('Connected to ${device.name}');
        _connectionController.add(true);

        // Save for auto-connect
        await PrinterConfigService.saveConnectedDevice(
          deviceId: device.id,
          deviceName: device.name,
          paperSize: 58,
        );

        return true;
      } else {
        _updateStatus('Connection failed');
        return false;
      }
    } catch (e) {
      _updateStatus('Connection error: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _updateStatus('Disconnected');
    _connectionController.add(false);
  }

  @override
  Future<bool> printTest() async {
    final printerService = PrinterService();
    return printerService.printTestPage();
  }

  @override
  // Future<bool> printReceipt({
  //   required String orderId,
  //   required String customerName,
  //   required List<Map<String, dynamic>> items,
  //   required double subtotal,
  //   required double orderDiscountAmount,
  //   required double grandTotal,
  //   required double paidAmount,
  //   required double change,
  //   required String cashierName,
  //   required DateTime createdAt,
  //   required List<Map<String, dynamic>> paymentMethods,
  // }) async {
  //   final printerService = PrinterService();
  //   return printerService.printReceipt(
  //     orderId: orderId,
  //     customerName: customerName,
  //     items: items,
  //     subtotal: subtotal,
  //     orderDiscountAmount: orderDiscountAmount,
  //     grandTotal: grandTotal,
  //     paidAmount: paidAmount,
  //     change: change,
  //     cashierName: cashierName,
  //     createdAt: createdAt,
  //     paymentMethods: paymentMethods,
  //   );
  // }
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
    required List<Map<String, dynamic>> paymentMethods,
  }) async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung!');
      return false;
    }

    try {
      final bytes = await ReceiptTemplate.buildReceipt(
        orderId: orderId,
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        orderDiscountAmount: orderDiscountAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        change: change,
        cashierName: cashierName,
        createdAt: createdAt,
        paymentMethods: paymentMethods,
        paperSize: PaperSize.mm58,
      );

      print('📦 Generated ${bytes.length} bytes using unified template');
      final result = await _bluetoothService.sendData(bytes);
      return result;
    } catch (e) {
      print('❌ Error print receipt: $e');
      print('❌ Stack trace: ${e.toString()}');
      return false;
    }
  }

  @override
  // Future<bool> printStrukTutupKasir({
  //   required Map<String, dynamic> mainData,
  //   required List<dynamic> payments,
  //   required List<dynamic> biaya,
  //   required List<dynamic> pendapatan,
  //   required List<dynamic> uangMuka,
  // }) async {
  //   final printerService = PrinterService();
  //   return printerService.printStrukTutupKasir(
  //     mainData: mainData,
  //     payments: payments,
  //     biaya: biaya,
  //     pendapatan: pendapatan,
  //     uangMuka: uangMuka,
  //   );
  // }

  Future<bool> printStrukTutupKasir({
    required Map<String, dynamic> mainData,
    required List<dynamic> payments,
    required List<dynamic> biaya,
    required List<dynamic> pendapatan,
    required List<dynamic> uangMuka,
  }) async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung!');
      return false;
    }

    try {
      final bytes = await ReceiptTemplate.buildTutupKasirReceipt(
        mainData: mainData,
        payments: payments,
        biaya: biaya,
        pendapatan: pendapatan,
        uangMuka: uangMuka,
        paperSize: PaperSize.mm58,
      );

      print('📦 Generated ${bytes.length} bytes for tutup kasir');
      final result = await _bluetoothService.sendData(bytes);
      return result;
    } catch (e) {
      print('❌ Error print struk tutup kasir: $e');
      return false;
    }
  }

  @override
  Future<bool> printUangMukaReceipt({
    required String nomor,
    required DateTime tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
    bool isRealisasi = false,
  }) async {
    if (!_bluetoothService.isConnected) {
      print('❌ Printer tidak terhubung!');
      return false;
    }

    try {
      final bytes = await ReceiptTemplate.buildUangMukaReceipt(
        nomor: nomor,
        tanggal: tanggal,
        customer: customer,
        nilai: nilai,
        jenisBayar: jenisBayar,
        keterangan: keterangan,
        isRealisasi: isRealisasi,
        paperSize: PaperSize.mm58,
      );

      print('📦 Generated ${bytes.length} bytes for uang muka receipt');
      final result = await _bluetoothService.sendData(bytes);
      return result;
    } catch (e) {
      print('❌ Error print uang muka receipt: $e');
      return false;
    }
  }

  @override
  Future<bool> checkConnection() async {
    final connected = _bluetoothService.isConnected;
    _connectionController.add(connected);
    return connected;
  }

  @override
  Future<void> autoConnect() async {
    try {
      final savedDevice = await PrinterConfigService.getSavedDevice();
      if (savedDevice != null && savedDevice['autoConnect'] == true) {
        _updateStatus('Auto-connecting to ${savedDevice['name']}...');

        final devices = await scanDevices();
        final targetDevice = devices.firstWhere(
              (d) => d.id == savedDevice['id'],
          orElse: () => throw Exception('Saved device not found'),
        );

        await connect(targetDevice);
      }
    } catch (e) {
      _updateStatus('Auto-connect failed: ${e.toString().split('\n').first}');
    }
  }

  @override
  Stream<String> get barcodeStream => _barcodeController.stream;

  @override
  bool get isScannerEnabled => _scannerEnabled;

  @override
  Future<void> enableScanner() async {
    _scannerEnabled = true;
    print('✅ Scanner enabled (Bluetooth mode)');
  }

  @override
  Future<void> disableScanner() async {
    _scannerEnabled = false;
    print('🔕 Scanner disabled');
  }

  @override
  void simulateBarcodeScan(String barcode) {
    if (_scannerEnabled) {
      print('📱 Manual barcode simulation: $barcode');
      _barcodeController.add(barcode);
    }
  }

  void dispose() {
    _connectionController.close();
    _statusController.close();
    _barcodeController.close();
  }
}

// WebSocket Printer Implementation (Web)
class WebSocketPrinterServiceImpl extends BasePrinterService {
  late ws_demo.WebSocketPrinter _webSocketPrinter;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  String _currentStatus = 'Disconnected';
  final StreamController<String> _barcodeController = StreamController<String>.broadcast();
  bool _scannerEnabled = false;

  WebSocketPrinterServiceImpl() {
    _webSocketPrinter = ws_demo.WebSocketPrinter();
    _webSocketPrinter.statusStream.listen(_updateStatus);
    _webSocketPrinter.connectionStream.listen((connected) {
      _connectionController.add(connected);
    });
    _webSocketPrinter.barcodeStream.listen((barcode) {
      _barcodeController.add(barcode);
    });
    _setupBridgeListeners();
  }

  @override
  Device? get connectedDevice {
    if (!_webSocketPrinter.isConnected) return null;

    return Device(
      id: 'bridge_${DateTime.now().millisecondsSinceEpoch}',
      name: 'WebSocket Printer Bridge',
      type: DeviceType.network,
      address: _webSocketPrinter.bridgeUrl,
      isConnected: true,
    );
  }

  @override
  bool get isConnected => _webSocketPrinter.isConnected;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  String get currentStatus => _currentStatus;

  @override
  String get platformName => 'WebSocket Bridge';

  @override
  Stream<String> get barcodeStream => _barcodeController.stream;

  void _setupBridgeListeners() {
    _webSocketPrinter.barcodeStream.listen((barcode) {
      print('📡 Barcode from bridge: $barcode');
      _barcodeController.add(barcode);
    });
  }

  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  @override
  Future<List<Device>> scanDevices() async {
    // Untuk WebSocket, kita return virtual device
    return [
      Device(
        id: 'websocket_bridge',
        name: 'Printer Bridge Connection',
        type: DeviceType.network,
        address: _webSocketPrinter.bridgeUrl,
        isConnected: false,
      )
    ];
  }

  @override
  Future<bool> connect(Device device) async {
    try {
      _updateStatus('Connecting to bridge...');
      _webSocketPrinter.setBridgeUrl(device.address);
      final success = await _webSocketPrinter.connect(device);

      if (success) {
        _updateStatus('Connected to bridge at ${device.address}');
        _connectionController.add(true);

        // Save for auto-connect
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('websocket_bridge_url', device.address);
        await prefs.setBool('websocket_auto_connect', true);

        return true;
      } else {
        _updateStatus('Connection failed');
        return false;
      }
    } catch (e) {
      _updateStatus('Connection error: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _webSocketPrinter.disconnect();
    _updateStatus('Disconnected');
    _connectionController.add(false);
  }

  @override
  Future<bool> printTest() {
    return _webSocketPrinter.printTest();
  }

  @override
  // Future<bool> printReceipt({
  //   required String orderId,
  //   required String customerName,
  //   required List<Map<String, dynamic>> items,
  //   required double subtotal,
  //   required double orderDiscountAmount,
  //   required double grandTotal,
  //   required double paidAmount,
  //   required double change,
  //   required String cashierName,
  //   required DateTime createdAt,
  //   required List<Map<String, dynamic>> paymentMethods,
  // }) async {
  //   // Convert items to receipt items
  //   final receiptItems = items.map((item) {
  //     return ReceiptItem(
  //       name: item['product_name']?.toString() ?? 'Unknown',
  //       quantity: item['quantity'] ?? 1,
  //       price: item['price'] ?? 0.0,
  //       total: item['total'] ?? 0.0,
  //     );
  //   }).toList();
  //
  //   // Buat receipt object
  //   final receipt = Receipt(
  //     id: orderId,
  //     storeName: 'ROTI-Q',
  //     storeAddress: 'Busukan RT 002 RW 017 Mojosongo Solo',
  //     storePhone: '0821-1532-9182',
  //     date: createdAt,
  //     transactionId: orderId,
  //     items: receiptItems,
  //     subtotal: subtotal,
  //     tax: 0.0,
  //     discount: orderDiscountAmount,
  //     grandTotal: grandTotal,
  //     paymentMethod: 'CASH',
  //     cashierName: cashierName,
  //     customerName: customerName,
  //   );
  //
  //   return _webSocketPrinter.printReceipt(receipt);
  // }

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
    required List<Map<String, dynamic>> paymentMethods,
  }) async {
    // Buat receipt object untuk WebSocket printer
    final receipt = Receipt.testReceipt(); // HAPUS yang lama

    // GANTI dengan template unified
    try {
      final bytes = await ReceiptTemplate.buildReceipt(
        orderId: orderId,
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        orderDiscountAmount: orderDiscountAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        change: change,
        cashierName: cashierName,
        createdAt: createdAt,
        paymentMethods: paymentMethods,
        paperSize: PaperSize.mm80, // Default untuk WebSocket
      );

      // Convert to Base64 untuk WebSocket
      final base64Data = base64.encode(bytes);

      if (!_webSocketPrinter.isConnected) {
        _updateStatus('Not connected to bridge');
        return false;
      }

      _updateStatus('Sending receipt to bridge...');

      // Kirim dengan prefix PRINT_BASE64:
      _webSocketPrinter.channel?.sink.add('PRINT_BASE64:$base64Data');
      _updateStatus('Receipt sent to bridge');

      return true;
    } catch (e) {
      print('❌ Print error: $e');
      _updateStatus('Print error: $e');
      return false;
    }
  }

  // @override
  // Future<bool> printStrukTutupKasir({
  //   required Map<String, dynamic> mainData,
  //   required List<dynamic> payments,
  //   required List<dynamic> biaya,
  //   required List<dynamic> pendapatan,
  //   required List<dynamic> uangMuka,
  // }) {
  //   print('WebSocket struk tutup kasir not implemented yet');
  //   return Future.value(false);
  // }

  @override
  Future<bool> printStrukTutupKasir({
    required Map<String, dynamic> mainData,
    required List<dynamic> payments,
    required List<dynamic> biaya,
    required List<dynamic> pendapatan,
    required List<dynamic> uangMuka,
  }) async {
    try {
      final bytes = await ReceiptTemplate.buildTutupKasirReceipt(
        mainData: mainData,
        payments: payments,
        biaya: biaya,
        pendapatan: pendapatan,
        uangMuka: uangMuka,
        paperSize: PaperSize.mm80,
      );

      final base64Data = base64.encode(bytes);

      if (!_webSocketPrinter.isConnected) {
        _updateStatus('Not connected to bridge');
        return false;
      }

      _updateStatus('Sending tutup kasir receipt to bridge...');

      // Gunakan method printRawBytes yang sudah ada
      return await _webSocketPrinter.printRawBytes(bytes);
      // ATAU jika mau pakai Base64:
      // return await _webSocketPrinter.printBase64Receipt(base64Data);

    } catch (e) {
      print('❌ Print struk tutup kasir error: $e');
      _updateStatus('Print error: $e');
      return false;
    }
  }

  @override
  Future<bool> printUangMukaReceipt({
    required String nomor,
    required DateTime tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
    bool isRealisasi = false,
  }) async {
    try {
      final bytes = await ReceiptTemplate.buildUangMukaReceipt(
        nomor: nomor,
        tanggal: tanggal,
        customer: customer,
        nilai: nilai,
        jenisBayar: jenisBayar,
        keterangan: keterangan,
        isRealisasi: isRealisasi,
        paperSize: PaperSize.mm80,
      );

      final base64Data = base64.encode(bytes);

      if (!_webSocketPrinter.isConnected) {
        _updateStatus('Not connected to bridge');
        return false;
      }

      _updateStatus('Sending uang muka receipt to bridge...');
      return await _webSocketPrinter.printRawBytes(bytes);
    } catch (e) {
      print('❌ Print uang muka error: $e');
      _updateStatus('Print error: $e');
      return false;
    }
  }

  @override
  Future<bool> checkConnection() async {
    return _webSocketPrinter.isConnected;
  }

  @override
  Future<void> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('websocket_bridge_url') ?? 'ws://localhost:8765';
      final autoConnect = prefs.getBool('websocket_auto_connect') ?? true;

      if (autoConnect) {
        _updateStatus('Auto-connecting to $savedUrl...');

        // Coba port alternatif jika gagal
        await _tryConnectWithFallback(savedUrl);
      }
    } catch (e) {
      _updateStatus('Auto-connect failed: ${e.toString().split('\n').first}');
    }
  }

  Future<void> _tryConnectWithFallback(String baseUrl) async {
    final ports = [8765, 8766, 8767, 8768, 8769, 8770];

    for (final port in ports) {
      final url = 'ws://localhost:$port';
      _webSocketPrinter.setBridgeUrl(url);

      _updateStatus('Trying $url...');

      final device = Device(
        id: 'bridge_$port',
        name: 'Printer Bridge',
        type: DeviceType.network,
        address: url,
      );

      final success = await connect(device);

      if (success) {
        _updateStatus('Connected to port $port');
        return;
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    _updateStatus('Could not connect to any port');
  }

  @override
  bool get isScannerEnabled => _scannerEnabled && _webSocketPrinter.isConnected;

  @override
  Future<void> enableScanner() async {
    if (_webSocketPrinter.isConnected) {
      await _webSocketPrinter.enableScanner();
      _scannerEnabled = true;
      print('✅ Scanner enabled via WebSocket');
    }
  }

  @override
  Future<void> disableScanner() async {
    if (_webSocketPrinter.isConnected) {
      await _webSocketPrinter.disableScanner();
    }
    _scannerEnabled = false;
    print('🔕 Scanner disabled');
  }

  @override
  void simulateBarcodeScan(String barcode) {
    if (_scannerEnabled) {
      print('📱 Manual barcode simulation: $barcode');
      _barcodeController.add(barcode);
    }
  }

  void dispose() {
    _webSocketPrinter.dispose();
    _connectionController.close();
    _statusController.close();
    _barcodeController.close();
  }
}

// Factory untuk membuat printer service berdasarkan platform
class UniversalPrinterService implements BasePrinterService {
  static final UniversalPrinterService _instance = UniversalPrinterService._internal();
  factory UniversalPrinterService() => _instance;

  late BasePrinterService _delegate;
  bool _initialized = false;

  UniversalPrinterService._internal() {
    _initializeDelegate();
  }

  void _initializeDelegate() {
    if (PlatformDetector.isWeb) {
      _delegate = WebSocketPrinterServiceImpl();
      print('📱 Using WebSocket Printer (Web platform)');
    } else {
      _delegate = BluetoothPrinterServiceImpl();
      print('📱 Using Bluetooth Printer (Mobile platform)');
    }
    _initialized = true;
  }

  // Getters delegate ke implementasi yang sesuai
  @override
  Device? get connectedDevice => _delegate.connectedDevice;

  @override
  bool get isConnected => _delegate.isConnected;

  @override
  bool get isPrinterReady => _delegate.isConnected;

  @override
  Stream<bool> get connectionStream => _delegate.connectionStream;

  @override
  Stream<String> get statusStream => _delegate.statusStream;

  @override
  String get currentStatus => _delegate.currentStatus;

  @override
  String get platformName => _delegate.platformName;

  // Methods delegate ke implementasi yang sesuai
  @override
  Future<List<Device>> scanDevices() => _delegate.scanDevices();

  @override
  Future<bool> connect(Device device) => _delegate.connect(device);

  @override
  Future<void> disconnect() => _delegate.disconnect();

  @override
  Future<bool> printTest() => _delegate.printTest();

  @override
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
    required List<Map<String, dynamic>> paymentMethods,
  }) => _delegate.printReceipt(
    orderId: orderId,
    customerName: customerName,
    items: items,
    subtotal: subtotal,
    orderDiscountAmount: orderDiscountAmount,
    grandTotal: grandTotal,
    paidAmount: paidAmount,
    change: change,
    cashierName: cashierName,
    createdAt: createdAt,
    paymentMethods: paymentMethods,
  );

  @override
  Future<bool> printStrukTutupKasir({
    required Map<String, dynamic> mainData,
    required List<dynamic> payments,
    required List<dynamic> biaya,
    required List<dynamic> pendapatan,
    required List<dynamic> uangMuka,
  }) => _delegate.printStrukTutupKasir(
    mainData: mainData,
    payments: payments,
    biaya: biaya,
    pendapatan: pendapatan,
    uangMuka: uangMuka,
  );

  @override
  Future<bool> printUangMukaReceipt({
    required String nomor,
    required DateTime tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
    bool isRealisasi = false,
  }) => _delegate.printUangMukaReceipt(
    nomor: nomor,
    tanggal: tanggal,
    customer: customer,
    nilai: nilai,
    jenisBayar: jenisBayar,
    keterangan: keterangan,
    isRealisasi: isRealisasi,
  );

  @override
  Future<bool> checkConnection() => _delegate.checkConnection();

  @override
  Future<void> autoConnect() => _delegate.autoConnect();

  // Method tambahan untuk mengetahui platform
  bool get isWebSocket => PlatformDetector.isWeb;
  bool get isBluetooth => !PlatformDetector.isWeb;

  @override
  Stream<String> get barcodeStream => _delegate.barcodeStream;

  @override
  bool get isScannerEnabled => _delegate.isScannerEnabled;

  @override
  Future<void> enableScanner() => _delegate.enableScanner();

  @override
  Future<void> disableScanner() => _delegate.disableScanner();

  @override
  void simulateBarcodeScan(String barcode) => _delegate.simulateBarcodeScan(barcode);

  // Helper method
  bool get canScanBarcode => isConnected && isScannerEnabled;

  // Method untuk dispose resources
  void dispose() {
    if (_delegate is BluetoothPrinterServiceImpl) {
      (_delegate as BluetoothPrinterServiceImpl).dispose();
    } else if (_delegate is WebSocketPrinterServiceImpl) {
      (_delegate as WebSocketPrinterServiceImpl).dispose();
    }
  }
}