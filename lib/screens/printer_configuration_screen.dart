import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/universal_printer_service.dart';
import '../utils/platform_detector.dart';
import '../widgets/device_list_tile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;
import '../models/device.dart';

class PrinterConfigurationScreen extends StatefulWidget {
  const PrinterConfigurationScreen({super.key});

  @override
  State<PrinterConfigurationScreen> createState() => _PrinterConfigurationScreenState();
}

class _PrinterConfigurationScreenState extends State<PrinterConfigurationScreen> {
  final UniversalPrinterService _printerService = UniversalPrinterService();

  List<Device> _devices = [];
  bool _isScanning = false;
  bool _isLoading = true;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen to connection status
    _connectionSubscription = _printerService.connectionStream.listen((connected) {
      setState(() {});
    });

    _statusSubscription = _printerService.statusStream.listen((status) {
      setState(() {});
    });

    // Auto-connect jika belum terhubung
    if (!_printerService.isConnected) {
      await _printerService.autoConnect();
    }

    // Load devices
    await _loadDevices();

    setState(() => _isLoading = false);
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _printerService.scanDevices();
      setState(() => _devices = devices);
    } catch (e) {
      print('Error loading devices: $e');
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    // Untuk Bluetooth, perlu start discovery
    if (!PlatformDetector.isWeb) {
      // TODO: Implement Bluetooth scanning
    }

    // Tunggu dan refresh devices
    await Future.delayed(Duration(seconds: 3));
    await _loadDevices();

    setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(Device device) async {
    final success = await _printerService.connect(device);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.name}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Disconnected from printer'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _testPrint() async {
    final success = await _printerService.printTest();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send test print'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPlatformInfo() {
    final isWeb = PlatformDetector.isWeb;
    final platformName = PlatformDetector.platformName;
    final printerType = isWeb ? 'WebSocket Bridge' : 'Bluetooth';

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isWeb ? Colors.blue.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isWeb ? Icons.language : Icons.bluetooth,
                color: isWeb ? Colors.blue : Colors.green,
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform: $platformName',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Printer Type: $printerType',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: ${_printerService.currentStatus}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _printerService.isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    final isConnected = _printerService.isConnected;
    final connectedDevice = _printerService.connectedDevice;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printer Connection',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),

            if (isConnected && connectedDevice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      PlatformDetector.isWeb ? Icons.language : Icons.bluetooth,
                      color: Colors.green,
                    ),
                    title: Text(
                      connectedDevice.name,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      connectedDevice.address,
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: _disconnect,
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testPrint,
                      icon: Icon(Icons.print),
                      label: Text('Test Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF6A918),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No printer connected',
                    style: GoogleFonts.montserrat(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 12),
                  if (!PlatformDetector.isWeb)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startScan,
                        icon: _isScanning
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Icon(Icons.search),
                        label: Text(_isScanning ? 'Scanning...' : 'Scan for Printers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF6A918),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) return SizedBox();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Printers',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select your printer:',
              style: GoogleFonts.montserrat(color: Colors.grey.shade600),
            ),
            SizedBox(height: 12),
            ..._devices.map((device) {
              final isConnected = _printerService.connectedDevice?.id == device.id;

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                elevation: 1,
                child: ListTile(
                  leading: Icon(
                    device.type == DeviceType.bluetooth ? Icons.bluetooth : Icons.language,
                    color: isConnected ? Colors.green : Colors.blue,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    '${device.typeString} • ${device.address}',
                    style: GoogleFonts.montserrat(fontSize: 12),
                  ),
                  trailing: isConnected
                      ? Icon(Icons.check, color: Colors.green)
                      : Icon(Icons.chevron_right),
                  onTap: () => _connectToDevice(device),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSocketConfig() {
    if (!PlatformDetector.isWeb) return SizedBox();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WebSocket Bridge Configuration',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Bridge URL: ws://localhost:8765',
              style: GoogleFonts.montserrat(color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure the desktop bridge application is running on port 8765',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Printer Configuration',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFF6A918),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPlatformInfo(),
            SizedBox(height: 16),
            _buildConnectionCard(),
            SizedBox(height: 16),
            _buildDeviceList(),
            SizedBox(height: 16),
            _buildWebSocketConfig(),
          ],
        ),
      ),
    );
  }
}