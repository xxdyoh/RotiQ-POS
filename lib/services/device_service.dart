// services/device_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'api_service.dart';

class DeviceService {
  static const String baseUrl = ApiService.baseUrl;

  // Generate Device ID dari browser fingerprint
  static String generateDeviceId() {
    final userAgent = html.window.navigator.userAgent;
    final platform = html.window.navigator.platform;
    final language = html.window.navigator.language;
    final screenWidth = html.window.screen?.width ?? 0;
    final screenHeight = html.window.screen?.height ?? 0;
    final timezone = DateTime.now().timeZoneOffset.inMinutes;

    final fingerprint = [
      userAgent,
      platform,
      language,
      screenWidth,
      screenHeight,
      timezone,
    ].join('|');

    final bytes = utf8.encode(fingerprint);
    final hash = base64Url.encode(bytes).substring(0, 20);

    return 'DEV-${hash.toUpperCase()}';
  }

  // Simpan Device ID ke localStorage
  static void saveDeviceId(String deviceId) {
    html.window.localStorage['device_id'] = deviceId;
  }

  // Ambil Device ID dari localStorage
  static String getSavedDeviceId() {
    return html.window.localStorage['device_id'] ?? '';
  }

  // Simpan status allowed
  static void saveAllowedStatus(bool allowed) {
    html.window.localStorage['device_allowed'] = allowed ? 'true' : 'false';
  }

  // Cek status allowed dari localStorage
  static bool getSavedAllowedStatus() {
    return html.window.localStorage['device_allowed'] == 'true';
  }

  // Clear device data
  static void clearDeviceData() {
    html.window.localStorage.remove('device_id');
    html.window.localStorage.remove('device_allowed');
  }

  // Check device ke backend
  static Future<Map<String, dynamic>> checkDevice() async {
    try {
      String deviceId = getSavedDeviceId();

      // Generate baru kalau belum ada
      if (deviceId.isEmpty) {
        deviceId = generateDeviceId();
        saveDeviceId(deviceId);
      }

      final response = await http.post(
        Uri.parse('$baseUrl/device/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isAllowed = data['is_allowed'] == true;

        // Simpan status
        saveAllowedStatus(isAllowed);

        return {
          'success': true,
          'is_allowed': isAllowed,
          'device_id': deviceId,
          'status': data['status'] ?? 0,
          'message': data['message'] ?? '',
          'is_new': data['is_new'] ?? false,
        };
      }

      return {
        'success': false,
        'is_allowed': false,
        'device_id': deviceId,
        'message': 'Gagal terhubung ke server',
      };
    } catch (e) {
      // Offline mode - cek localStorage
      final savedAllowed = getSavedAllowedStatus();
      return {
        'success': false,
        'is_allowed': savedAllowed,
        'device_id': getSavedDeviceId(),
        'message': 'Offline mode',
        'offline': true,
      };
    }
  }
}