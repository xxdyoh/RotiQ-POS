enum DeviceType {
  bluetooth,
  usb,
  network,
  other
}

class Device {
  final String id;
  final String name;
  final DeviceType type;
  final String address;
  final int? rssi;
  final bool isConnected;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.rssi,
    this.isConnected = false,
  });

  String get typeString {
    switch (type) {
      case DeviceType.bluetooth:
        return 'Bluetooth';
      case DeviceType.usb:
        return 'USB';
      case DeviceType.network:
        return 'Network';
      default:
        return 'Other';
    }
  }

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    String? address,
    int? rssi,
    bool? isConnected,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}