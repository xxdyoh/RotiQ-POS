import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus;

class DeviceListTile extends StatelessWidget {
  final blue_plus.BluetoothDevice device;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback onDisconnect;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isConnected
            ? BorderSide(color: Color(0xFFF6A918), width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isConnected
                ? Color(0xFFF6A918).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isConnected ? Color(0xFFF6A918) : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            isConnected ? Icons.print : Icons.bluetooth,
            color: isConnected ? Color(0xFFF6A918) : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isConnected ? Color(0xFFF6A918) : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.remoteId.toString(),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isConnected)
              Text(
                'Connected',
                style: TextStyle(
                  color: Color(0xFFF6A918),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        trailing: isConnected
            ? IconButton(
          icon: Icon(Icons.close, color: Colors.red),
          onPressed: onDisconnect,
          tooltip: 'Disconnect',
        )
            : isSelected
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
          ),
        )
            : null,
        onTap: isConnected ? null : onTap,
        selected: isSelected,
      ),
    );
  }
}