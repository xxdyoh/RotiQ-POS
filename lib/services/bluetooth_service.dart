import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  blue_plus.BluetoothDevice? _connectedDevice;
  blue_plus.BluetoothCharacteristic? _writeCharacteristic;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  blue_plus.BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<bool> isBluetoothAvailable() async {
    return await blue_plus.FlutterBluePlus.isOn;
  }

  Future<bool> enableBluetooth() async {
    try {
      await blue_plus.FlutterBluePlus.turnOn();
      return true;
    } catch (e) {
      print('Failed to enable Bluetooth: $e');
      return false;
    }
  }

  Stream<List<blue_plus.BluetoothDevice>> startDiscovery() {
    blue_plus.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    return blue_plus.FlutterBluePlus.scanResults.map((results) =>
        results.map((r) => r.device).toList());
  }

  Future<void> stopDiscovery() async {
    await blue_plus.FlutterBluePlus.stopScan();
  }

  Future<List<blue_plus.BluetoothDevice>> getBondedDevices() async {
    return blue_plus.FlutterBluePlus.bondedDevices;
  }

  Future<bool> connectToDevice(blue_plus.BluetoothDevice device) async {
    try {
      if (_connectedDevice != null) {
        await disconnect();
      }

      await device.connect();
      _connectedDevice = device;
      _isConnected = true;

      List<blue_plus.BluetoothService> services = await device.discoverServices();
      for (blue_plus.BluetoothService service in services) {
        for (blue_plus.BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      return true;
    } catch (e) {
      print('Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _connectedDevice = null;
      _writeCharacteristic = null;
      _isConnected = false;
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  Future<bool> sendData(Uint8List data) async {
    if (_writeCharacteristic == null || !_isConnected) {
      return false;
    }

    try {
      const int maxChunkSize = 200;
      int offset = 0;

      while (offset < data.length) {
        int chunkSize = (offset + maxChunkSize < data.length)
            ? maxChunkSize
            : data.length - offset;

        Uint8List chunk = data.sublist(offset, offset + chunkSize);

        try {
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
        } catch (e) {
          print('Without response failed, trying with response: $e');
          await _writeCharacteristic!.write(chunk, withoutResponse: false);
        }

        await Future.delayed(const Duration(milliseconds: 10));

        offset += chunkSize;
      }

      return true;
    } catch (e) {
      print('Send data error: $e');
      return false;
    }
  }

  Stream<bool> get connectionState {
    if (_connectedDevice != null) {
      return _connectedDevice!.connectionState.map((state) =>
      state == blue_plus.BluetoothConnectionState.connected);
    }
    return Stream.value(false);
  }

  Future<bool> isDeviceConnected() async {
    return _isConnected;
  }
}