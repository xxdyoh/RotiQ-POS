import 'package:flutter/material.dart';
import '../services/printer_config_service.dart';

class PrinterConfigScreen extends StatefulWidget {
  const PrinterConfigScreen({super.key});

  @override
  State<PrinterConfigScreen> createState() => _PrinterConfigScreenState();
}

class _PrinterConfigScreenState extends State<PrinterConfigScreen> {
  final PrinterConfigService _configService = PrinterConfigService();
  List<PrinterConfig> _configs = [];
  PrinterConfig? _activeConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  Future<void> _loadConfigurations() async {
    await _configService.loadConfigurations();
    setState(() {
      _configs = _configService.configs;
      _activeConfig = _configService.activeConfig;
      _isLoading = false;
    });
  }

  Future<void> _setActiveConfig(PrinterConfig config) async {
    await _configService.setActiveConfig(config.name);
    setState(() {
      _activeConfig = config;
    });
    _showSnackBar('Konfigurasi printer aktif diubah ke ${config.name}');
  }

  Future<void> _addNewConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPrinterConfigScreen(),
      ),
    );

    if (result == true) {
      await _loadConfigurations();
    }
  }

  Future<void> _editConfig(PrinterConfig config) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPrinterConfigScreen(editConfig: config),
      ),
    );

    if (result == true) {
      await _loadConfigurations();
    }
  }

  Future<void> _deleteConfig(PrinterConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Konfigurasi'),
        content: Text('Apakah Anda yakin ingin menghapus "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _configService.removeConfig(config.name);
      await _loadConfigurations();
      _showSnackBar('Konfigurasi berhasil dihapus');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFF6A918),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Konfigurasi Printer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFFC107),
                Color(0xFFFFD54F),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
          : Column(
        children: [
          // Active Configuration Card
          if (_activeConfig != null)
            Card(
              margin: EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF6A918).withOpacity(0.1),
                      Color(0xFFFFC107).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.print,
                          color: Color(0xFFF6A918),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Konfigurasi Aktif',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF6A918),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _activeConfig!.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tipe: ${_activeConfig!.type.toString().split('.').last} | '
                          'Format: ${_activeConfig!.format.toString().split('.').last}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

          // Configurations List
          Expanded(
            child: _configs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.print_disabled,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada konfigurasi printer',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tambahkan konfigurasi baru untuk memulai',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _configs.length,
              itemBuilder: (context, index) {
                final config = _configs[index];
                final isActive = _activeConfig?.name == config.name;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isActive
                        ? BorderSide(color: Color(0xFFF6A918), width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Icon(
                      isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isActive ? Color(0xFFF6A918) : Colors.grey,
                    ),
                    title: Text(config.name),
                    subtitle: Text(
                      'Tipe: ${config.type.toString().split('.').last} | '
                          'Format: ${config.format.toString().split('.').last}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'activate',
                          child: Text('Set sebagai Aktif'),
                          enabled: !isActive,
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Hapus'),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'activate':
                            _setActiveConfig(config);
                            break;
                          case 'edit':
                            _editConfig(config);
                            break;
                          case 'delete':
                            _deleteConfig(config);
                            break;
                        }
                      },
                    ),
                    onTap: () => _setActiveConfig(config),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewConfig,
        backgroundColor: Color(0xFFF6A918),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddPrinterConfigScreen extends StatefulWidget {
  final PrinterConfig? editConfig;

  const AddPrinterConfigScreen({super.key, this.editConfig});

  @override
  State<AddPrinterConfigScreen> createState() => _AddPrinterConfigScreenState();
}

class _AddPrinterConfigScreenState extends State<AddPrinterConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final PrinterConfigService _configService = PrinterConfigService();

  PrinterType _selectedType = PrinterType.thermal80mm;
  TicketFormat _selectedFormat = TicketFormat.standard;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.editConfig != null) {
      _nameController.text = widget.editConfig!.name;
      _selectedType = widget.editConfig!.type;
      _selectedFormat = widget.editConfig!.format;
      _isDefault = widget.editConfig!.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = PrinterConfig(
      name: _nameController.text.trim(),
      type: _selectedType,
      format: _selectedFormat,
      isDefault: _isDefault,
    );

    if (widget.editConfig != null) {
      await _configService.updateConfig(widget.editConfig!.name, config);
    } else {
      await _configService.addConfig(config);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.editConfig != null ? 'Edit Konfigurasi' : 'Tambah Konfigurasi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFFC107),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Konfigurasi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFFF6A918)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harap masukkan nama konfigurasi';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 24),

                      // Printer Type
                      Text(
                        'Tipe Printer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<PrinterType>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFFF6A918)),
                          ),
                        ),
                        value: _selectedType,
                        items: PrinterType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getPrinterTypeName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),

                      SizedBox(height: 24),

                      // Ticket Format
                      Text(
                        'Format Struk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<TicketFormat>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFFF6A918)),
                          ),
                        ),
                        value: _selectedFormat,
                        items: TicketFormat.values.map((format) {
                          return DropdownMenuItem(
                            value: format,
                            child: Text(_getTicketFormatName(format)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFormat = value!;
                          });
                        },
                      ),

                      SizedBox(height: 24),

                      // Default checkbox
                      CheckboxListTile(
                        title: Text('Jadikan Default'),
                        value: _isDefault,
                        onChanged: (value) {
                          setState(() {
                            _isDefault = value ?? false;
                          });
                        },
                        activeColor: Color(0xFFF6A918),
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(),

              // Save button
              ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF6A918),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.editConfig != null ? 'Update Konfigurasi' : 'Tambah Konfigurasi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPrinterTypeName(PrinterType type) {
    switch (type) {
      case PrinterType.thermal80mm:
        return 'Thermal 80mm';
      case PrinterType.thermal58mm:
        return 'Thermal 58mm';
      case PrinterType.dotMatrix:
        return 'Dot Matrix';
      case PrinterType.inkjet:
        return 'Inkjet';
    }
  }

  String _getTicketFormatName(TicketFormat format) {
    switch (format) {
      case TicketFormat.standard:
        return 'Standard';
      case TicketFormat.compact:
        return 'Compact';
      case TicketFormat.detailed:
        return 'Detailed';
      case TicketFormat.custom:
        return 'Custom';
    }
  }
}