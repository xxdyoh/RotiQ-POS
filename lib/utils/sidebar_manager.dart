import 'package:flutter/material.dart';

class SidebarManager {
  static final ValueNotifier<bool> _sidebarVisible = ValueNotifier<bool>(true);

  static ValueNotifier<bool> get sidebarVisible => _sidebarVisible;

  static void toggle() {
    _sidebarVisible.value = !_sidebarVisible.value;
  }

  static void setVisible(bool visible) {
    _sidebarVisible.value = visible;
  }

  static bool get isVisible => _sidebarVisible.value;

  static void reset() {
    _sidebarVisible.value = true;
  }
}