import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType {
  thermal80mm,
  thermal58mm,
  dotMatrix,
  inkjet,
}

enum TicketFormat {
  standard,
  compact,
  detailed,
  custom,
}

class PrinterConfig {
  final String name;
  final PrinterType type;
  final TicketFormat format;
  final Map<String, dynamic> customSettings;
  final bool isDefault;

  PrinterConfig({
    required this.name,
    required this.type,
    required this.format,
    this.customSettings = const {},
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'format': format.toString().split('.').last,
      'customSettings': customSettings,
      'isDefault': isDefault,
    };
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      name: json['name'] ?? '',
      type: PrinterType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
        orElse: () => PrinterType.thermal80mm,
      ),
      format: TicketFormat.values.firstWhere(
            (e) => e.toString().split('.').last == json['format'],
        orElse: () => TicketFormat.standard,
      ),
      customSettings: Map<String, dynamic>.from(json['customSettings'] ?? {}),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class PrinterConfigService {
  static final PrinterConfigService _instance = PrinterConfigService._internal();
  factory PrinterConfigService() => _instance;
  PrinterConfigService._internal();

  List<PrinterConfig> _configs = [];
  PrinterConfig? _activeConfig;

  List<PrinterConfig> get configs => _configs;
  PrinterConfig? get activeConfig => _activeConfig;

  Future<void> loadConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getString('printer_configs');

      if (configsJson != null) {
        final List<dynamic> configsList = jsonDecode(configsJson);
        _configs = configsList.map((config) => PrinterConfig.fromJson(config)).toList();

        final activeConfigName = prefs.getString('active_printer_config');
        if (activeConfigName != null) {
          _activeConfig = _configs.firstWhere(
                (config) => config.name == activeConfigName,
            orElse: () => _configs.isNotEmpty ? _configs.first : _getDefaultConfig(),
          );
        } else if (_configs.isNotEmpty) {
          _activeConfig = _configs.first;
        } else {
          _activeConfig = _getDefaultConfig();
        }
      } else {
        _initializeDefaultConfigs();
      }
    } catch (e) {
      print('Error loading printer configurations: $e');
      _initializeDefaultConfigs();
    }
  }

  Future<void> saveConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = jsonEncode(_configs.map((config) => config.toJson()).toList());
      await prefs.setString('printer_configs', configsJson);

      if (_activeConfig != null) {
        await prefs.setString('active_printer_config', _activeConfig!.name);
      }
    } catch (e) {
      print('Error saving printer configurations: $e');
    }
  }

  Future<void> addConfig(PrinterConfig config) async {
    _configs.add(config);
    await saveConfigurations();
  }

  Future<void> updateConfig(String name, PrinterConfig config) async {
    final index = _configs.indexWhere((c) => c.name == name);
    if (index != -1) {
      _configs[index] = config;
      await saveConfigurations();
    }
  }

  Future<void> removeConfig(String name) async {
    _configs.removeWhere((config) => config.name == name);
    if (_activeConfig?.name == name) {
      _activeConfig = _configs.isNotEmpty ? _configs.first : _getDefaultConfig();
    }
    await saveConfigurations();
  }

  Future<void> setActiveConfig(String name) async {
    final config = _configs.firstWhere(
          (config) => config.name == name,
      orElse: () => _getDefaultConfig(),
    );
    _activeConfig = config;
    await saveConfigurations();
  }

  void _initializeDefaultConfigs() {
    _configs = [
      PrinterConfig(
        name: 'Standard Thermal 80mm',
        type: PrinterType.thermal80mm,
        format: TicketFormat.standard,
        isDefault: true,
      ),
      PrinterConfig(
        name: 'Compact Thermal 58mm',
        type: PrinterType.thermal58mm,
        format: TicketFormat.compact,
      ),
    ];
    _activeConfig = _configs.first;
  }

  PrinterConfig _getDefaultConfig() {
    return PrinterConfig(
      name: 'Default Thermal Printer',
      type: PrinterType.thermal58mm,
      format: TicketFormat.standard,
      isDefault: true,
    );
  }

  static Future<void> setDefault58mm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_paper_size', '58mm');
  }

  static Future<String> getDefaultPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_paper_size') ?? '80mm';
  }

  static Future<void> saveConnectedDevice({
    required String deviceId,
    required String deviceName,
    required int paperSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_device_id', deviceId);
    await prefs.setString('last_device_name', deviceName);
    await prefs.setInt('last_paper_size', paperSize);
    await prefs.setBool('auto_connect_enabled', true);
  }

  static Future<Map<String, dynamic>?> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('last_device_id');
    final deviceName = prefs.getString('last_device_name');
    final paperSize = prefs.getInt('last_paper_size') ?? 58;
    final autoConnect = prefs.getBool('auto_connect_enabled') ?? false;

    if (deviceId != null && deviceName != null) {
      return {
        'id': deviceId,
        'name': deviceName,
        'paperSize': paperSize,
        'autoConnect': autoConnect,
      };
    }
    return null;
  }

  void updateDefaultTo58mm() {
    final has58mm = _configs.any((c) => c.type == PrinterType.thermal58mm);

    if (!has58mm) {
      _configs.add(PrinterConfig(
        name: 'Thermal 58mm Default',
        type: PrinterType.thermal58mm,
        format: TicketFormat.compact,
        isDefault: true,
      ));
    }

    _activeConfig = _configs.firstWhere(
          (c) => c.type == PrinterType.thermal58mm,
      orElse: () => _configs.first,
    );

    saveConfigurations();
  }
}