import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

enum AppPlatform {
  android,
  ios,
  web,
  windows,
  macos,
  linux,
  unknown,
}

class PlatformDetector {
  static AppPlatform get currentPlatform {
    if (kIsWeb) return AppPlatform.web;

    try {
      if (Platform.isAndroid) return AppPlatform.android;
      if (Platform.isIOS) return AppPlatform.ios;
      if (Platform.isWindows) return AppPlatform.windows;
      if (Platform.isMacOS) return AppPlatform.macos;
      if (Platform.isLinux) return AppPlatform.linux;
    } catch (e) {
      // Jika di web, akan error saat mengakses Platform
      return AppPlatform.web;
    }

    return AppPlatform.unknown;
  }

  static bool get isMobile => currentPlatform == AppPlatform.android ||
      currentPlatform == AppPlatform.ios;

  static bool get isDesktop => currentPlatform == AppPlatform.windows ||
      currentPlatform == AppPlatform.macos ||
      currentPlatform == AppPlatform.linux;

  static bool get isWeb => currentPlatform == AppPlatform.web;

  static bool get isAndroid => currentPlatform == AppPlatform.android;
  static bool get isIOS => currentPlatform == AppPlatform.ios;

  static String get platformName {
    switch (currentPlatform) {
      case AppPlatform.android: return 'Android';
      case AppPlatform.ios: return 'iOS';
      case AppPlatform.web: return 'Web';
      case AppPlatform.windows: return 'Windows';
      case AppPlatform.macos: return 'macOS';
      case AppPlatform.linux: return 'Linux';
      default: return 'Unknown';
    }
  }
}