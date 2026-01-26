import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ResponsiveHelper {
  // Simple breakpoints
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  // Cek platform
  static bool get isWeb => kIsWeb;

  static bool get isMobileDevice {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // Untuk POS: mobile portrait vs landscape
  static bool shouldUsePOSLandscape(BuildContext context) {
    if (isDesktop(context)) return true;
    if (isTablet(context)) return true;

    final orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.landscape;
  }

  // Untuk menentukan apakah show bottom navigation
  static bool shouldShowBottomNav(BuildContext context) {
    return isMobile(context) && MediaQuery.of(context).orientation == Orientation.portrait;
  }

  // Simple responsive values
  static double responsiveValue(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static EdgeInsets responsivePadding(BuildContext context, {
    EdgeInsets mobile = const EdgeInsets.all(12.0),
    EdgeInsets tablet = const EdgeInsets.all(16.0),
    EdgeInsets desktop = const EdgeInsets.all(20.0),
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  // Responsive font size
  static double responsiveFontSize(BuildContext context, {
    double mobile = 12.0,
    double tablet = 14.0,
    double desktop = 16.0,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Responsive grid column count
  static int responsiveGridColumns(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }
}