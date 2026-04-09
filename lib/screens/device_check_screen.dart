// screens/device_check_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/device_service.dart';
import 'login_screen.dart';

class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({Key? key}) : super(key: key);

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  bool _isLoading = true;
  bool _isAllowed = false;
  String _deviceId = '';
  String _message = '';
  bool _isNew = false;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _errorRed = const Color(0xFFE74C3C);
  final Color _successGreen = const Color(0xFF27AE60);

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    setState(() => _isLoading = true);

    final result = await DeviceService.checkDevice();

    setState(() {
      _isLoading = false;
      _isAllowed = result['is_allowed'] ?? false;
      _deviceId = result['device_id'] ?? '';
      _message = result['message'] ?? '';
      _isNew = result['is_new'] ?? false;
    });

    // Kalau allowed, langsung ke login screen
    if (_isAllowed) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: _deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device ID disalin!'),
        backgroundColor: _successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: _isLoading
            ? _buildLoading()
            : _isAllowed
            ? _buildAllowed()
            : _buildBlocked(),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _primaryDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Memeriksa akses device...',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildAllowed() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _successGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Akses Diizinkan',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mengalihkan ke halaman login...',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBlocked() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _errorRed, width: 2),
            ),
            child: Icon(
              Icons.block_rounded,
              size: 60,
              color: _errorRed,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Akses Dibatasi',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            // _isNew
            //     ? 'Device Anda terdaftar otomatis.\nMenunggu aktivasi dari tim IT.'
            //     :
            'Device ini tidak diizinkan untuk mengakses aplikasi.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Device ID Card
          // Container(
          //   padding: const EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(color: Colors.grey.shade300),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.05),
          //         blurRadius: 10,
          //         offset: const Offset(0, 2),
          //       ),
          //     ],
          //   ),
          //   child: Column(
          //     children: [
          //       Text(
          //         'Device ID Anda',
          //         style: GoogleFonts.montserrat(
          //           fontSize: 14,
          //           fontWeight: FontWeight.w600,
          //           color: Colors.grey[600],
          //         ),
          //       ),
          //       const SizedBox(height: 12),
          //       SelectableText(
          //         _deviceId,
          //         style: GoogleFonts.montserrat(
          //           fontSize: 18,
          //           // fontFamily: 'monospace',
          //           fontWeight: FontWeight.bold,
          //           color: _primaryDark,
          //         ),
          //       ),
          //       const SizedBox(height: 16),
          //       SizedBox(
          //         width: double.infinity,
          //         child: ElevatedButton.icon(
          //           onPressed: _copyDeviceId,
          //           icon: const Icon(Icons.copy, size: 18),
          //           label: const Text('Salin Device ID'),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: _accentGold,
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(vertical: 12),
          //             shape: RoundedRectangleBorder(
          //               borderRadius: BorderRadius.circular(10),
          //             ),
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          //
          // const SizedBox(height: 30),
          //
          // // Info untuk user
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Colors.blue.shade50,
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: Colors.blue.shade200),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(Icons.info_outline, color: Colors.blue.shade700),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: Text(
          //           'Hubungi tim IT dan berikan Device ID di atas untuk mengaktifkan akses.',
          //           style: GoogleFonts.montserrat(
          //             fontSize: 13,
          //             color: Colors.blue.shade900,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          //
          // const SizedBox(height: 24),

          // Refresh button
          TextButton.icon(
            onPressed: _checkDevice,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Cek Kembali'),
            style: TextButton.styleFrom(
              foregroundColor: _accentGold,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}