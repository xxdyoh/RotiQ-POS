import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/koreksi_service.dart';
import '../models/koreksi_model.dart';
import '../widgets/base_layout.dart';

class KoreksiFormScreen extends StatefulWidget {
  final Map<String, dynamic>? koreksiHeader;
  final VoidCallback onKoreksiSaved;

  const KoreksiFormScreen({
    super.key,
    this.koreksiHeader,
    required this.onKoreksiSaved,
  });

  @override
  State<KoreksiFormScreen> createState() => _KoreksiFormScreenState();
}

class _KoreksiFormScreenState extends State<KoreksiFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _stokFisikControllers = {};
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingStok = false;
  bool _scannerActive = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<KoreksiItem> _allItems = [];
  List<KoreksiItem> _filteredItems = [];
  List<KoreksiItem> _selectedItems = [];

  String? _nomorKoreksi;

  String _barcodeBuffer = '';
  Timer? _barcodeTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    _setupAutoScanner();

    if (widget.koreksiHeader != null) {
      _nomorKoreksi = widget.koreksiHeader!['kor_nomor'];
      _selectedDate = DateTime.parse(widget.koreksiHeader!['kor_tanggal']);
      _keteranganController.text = widget.koreksiHeader!['kor_keterangan'] ?? '';
      _loadKoreksiDetail();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _keteranganController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _searchFocusNode.dispose();
    _stokFisikControllers.values.forEach((controller) => controller.dispose());
    _barcodeTimer?.cancel();
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    super.dispose();
  }

  void _setupAutoScanner() {
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
  }

  void _handleRawKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    if (!_scannerActive) return;

    final logicalKey = event.logicalKey;
    final keyLabel = logicalKey.keyLabel;

    if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.tab) {
      _processBarcodeFromBuffer();
      return;
    }

    if (_isValidBarcodeCharacter(keyLabel)) {
      _barcodeBuffer += keyLabel;
      _resetBarcodeTimer();
    }
  }

  bool _isValidBarcodeCharacter(String char) {
    if (char.isEmpty || char.length > 1) return false;
    if (char == 'Enter' || char == 'Tab' || char == 'Escape') return false;

    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '-' || char == '.' || char == '_' || char == '/';
  }

  void _resetBarcodeTimer() {
    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(const Duration(milliseconds: 100), () {
      if (_barcodeBuffer.isNotEmpty && _barcodeBuffer.length >= 3) {
        _processBarcodeFromBuffer();
      } else {
        _barcodeBuffer = '';
      }
    });
  }

  void _processBarcodeFromBuffer() {
    if (_barcodeBuffer.isEmpty) return;
    final barcode = _barcodeBuffer.trim();
    _barcodeBuffer = '';
    _processBarcode(barcode);
  }

  Future<void> _processBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final itemId = int.tryParse(cleanBarcode);
    if (itemId == null) {
      _showToast('Format barcode tidak valid', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingIndex = _selectedItems.indexWhere((item) => item.itemId == itemId);

      if (existingIndex >= 0) {
        final existingItem = _selectedItems[existingIndex];
        final newStokFisik = existingItem.stokFisik + 1;
        _stokFisikControllers[itemId]?.text = newStokFisik.toStringAsFixed(0);
        _updateItemStokFisik(itemId, newStokFisik);
        _showToast('${existingItem.itemNama} +1', type: ToastType.success);
        HapticFeedback.lightImpact();
      } else {
        final items = await KoreksiService.getItemsForKoreksi();
        Map<String, dynamic>? itemData;

        for (var item in items) {
          if (item['item_id'] == itemId) {
            itemData = item;
            break;
          }
        }

        if (itemData != null) {
          final newItem = KoreksiItem(
            itemId: itemId,
            itemNama: itemData['item_nama']?.toString() ?? '',
            hpp: (itemData['item_hpp'] ?? 0).toDouble(),
            stokSistem: 0,
            stokFisik: 1,
            selisih: 1,
          );

          setState(() {
            _selectedItems.add(newItem);
            _filteredItems = List.from(_selectedItems);
          });

          _stokFisikControllers[itemId] = TextEditingController(text: '1');

          final stokSistem = await KoreksiService.getStokSistem(itemId);
          setState(() {
            final index = _selectedItems.indexWhere((i) => i.itemId == itemId);
            if (index >= 0) {
              _selectedItems[index].stokSistem = stokSistem;
              _selectedItems[index].selisih = 1 - stokSistem;
              _filteredItems[index].stokSistem = stokSistem;
              _filteredItems[index].selisih = 1 - stokSistem;
            }
          });

          _showToast('Item ditambahkan: ${newItem.itemNama}', type: ToastType.success);
          HapticFeedback.mediumImpact();
        } else {
          _showToast('Item dengan ID $itemId tidak ditemukan', type: ToastType.error);
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                type == ToastType.success ? Icons.check_circle_rounded :
                type == ToastType.error ? Icons.error_rounded :
                Icons.info_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral : _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadKoreksiDetail() async {
    if (_nomorKoreksi == null) return;
    setState(() => _isLoading = true);

    try {
      final detail = await KoreksiService.getKoreksiDetail(_nomorKoreksi!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedItems = details.map((detail) {
          return KoreksiItem(
            itemId: detail['kord_item_id'],
            itemNama: detail['item_nama'] ?? '',
            stokSistem: detail['kord_stok']?.toDouble() ?? 0,
            hpp: detail['kord_hpp']?.toDouble() ?? 0,
            stokFisik: (detail['kord_stok']?.toDouble() ?? 0) + (detail['kord_qty']?.toDouble() ?? 0),
            selisih: detail['kord_qty']?.toDouble() ?? 0,
          );
        }).toList();

        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _stokFisikControllers[item.itemId] = TextEditingController(
          text: item.stokFisik > 0 ? item.stokFisik.toStringAsFixed(0) : '0'
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _selectedItems;
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _selectedItems.where((item) {
          return item.itemNama.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _updateItemStokFisik(int itemId, double newStokFisik) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        _selectedItems[index].stokFisik = newStokFisik;
        _selectedItems[index].selisih = newStokFisik - _selectedItems[index].stokSistem;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex].stokFisik = newStokFisik;
          _filteredItems[filteredIndex].selisih = newStokFisik - _filteredItems[filteredIndex].stokSistem;
        }
      }
    });
  }

  void _showAddItemModal() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<List<KoreksiItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddItemModal(
        existingItems: _selectedItems,
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (var newItem in result) {
          final existingIndex = _selectedItems.indexWhere((item) => item.itemId == newItem.itemId);
          if (existingIndex >= 0) {
            _selectedItems[existingIndex].stokFisik = newItem.stokFisik;
          } else {
            _selectedItems.add(newItem);
          }
        }
        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
      });

      _loadAllStokSistem();
      _showToast('${result.length} item ditambahkan', type: ToastType.success);
    }
  }

  Future<void> _loadAllStokSistem() async {
    setState(() => _isLoadingStok = true);

    for (var item in _selectedItems) {
      if (item.stokSistem == 0) {
        try {
          final stok = await KoreksiService.getStokSistem(item.itemId);
          item.stokSistem = stok;
          item.selisih = item.stokFisik - stok;
        } catch (e) {
          print('Error load stok untuk ${item.itemNama}: $e');
        }
      }
    }

    setState(() => _isLoadingStok = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _updateAllStokFisikFromControllers() {
    for (var entry in _stokFisikControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final value = double.tryParse(controller.text) ?? 0;
      _updateItemStokFisik(itemId, value);
    }
  }

  void _deleteItem(KoreksiItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Item', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
        content: Text(
          'Hapus ${item.itemNama}?',
          style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedItems.removeWhere((i) => i.itemId == item.itemId);
                _filteredItems = List.from(_selectedItems);
                _stokFisikControllers[item.itemId]?.dispose();
                _stokFisikControllers.remove(item.itemId);
              });
              Navigator.pop(context);
              _showToast('${item.itemNama} dihapus', type: ToastType.info);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveKoreksi() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllStokFisikFromControllers();

    final itemsWithSelisih = _selectedItems.where((item) => item.selisih != 0).toList();
    if (itemsWithSelisih.isEmpty) {
      _showToast('Tidak ada perubahan stok (selisih 0)!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final requestData = {
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithSelisih.map((item) => {
          'item_id': item.itemId,
          'item_nama': item.itemNama,
          'stok_sistem': item.stokSistem,
          'stok_fisik': item.stokFisik,
          'selisih': item.selisih,
          'hpp': item.hpp,
        }).toList(),
      };

      final result = widget.koreksiHeader == null
          ? await KoreksiService.createKoreksi(requestData)
          : await KoreksiService.updateKoreksi({
        'nomor': _nomorKoreksi!,
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithSelisih.map((item) => {
          'item_id': item.itemId,
          'selisih': item.selisih,
          'stok_sistem': item.stokSistem,
          'hpp': item.hpp,
        }).toList(),
      });

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onKoreksiSaved();
        Navigator.pop(context);
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int get _totalItemsWithSelisih {
    return _selectedItems.where((item) => item.selisih != 0).length;
  }

  int get _totalItems {
    return _selectedItems.length;
  }

  Widget _buildScannerToggle() {
    return GestureDetector(
      onTap: _toggleScanner,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _scannerActive ? _accentMint.withOpacity(0.15) : _textMedium.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _scannerActive ? _accentMint : _textMedium,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 14,
              color: _scannerActive ? _accentMint : _textMedium,
            ),
            const SizedBox(width: 4),
            Text(
              _scannerActive ? 'ON' : 'OFF',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _scannerActive ? _accentMint : _textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleScanner() {
    setState(() {
      _scannerActive = !_scannerActive;
      if (_scannerActive) {
        _showToast('Mode scan aktif', type: ToastType.success);
      } else {
        _showToast('Mode scan nonaktif', type: ToastType.info);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.koreksiHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Koreksi Stok' : 'Koreksi Stok',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      actions: [
        _buildScannerToggle(),
      ],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: _bgSoft,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 12),
                        _buildItemsCard(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(isEdit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _primaryDark, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textMedium)),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderSoft),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.description_rounded, color: _primaryDark, size: 14),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _keteranganController,
                        style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
                        decoration: InputDecoration(
                          hintText: 'Keterangan...',
                          hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: _primaryDark, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daftar Item',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag_rounded, size: 10, color: _primaryDark),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedItems.length} items',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.search_rounded, color: _primaryDark, size: 14),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterItems,
                                decoration: InputDecoration(
                                  hintText: 'Cari item...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.qr_code_scanner_rounded, color: _accentMint, size: 14),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                focusNode: _barcodeFocusNode,
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    _processBarcode(value);
                                    _barcodeController.clear();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Scan barcode...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_barcodeController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _barcodeController.clear(),
                                  child: Icon(Icons.close_rounded, color: _textLight, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildActionButton(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      color: _accentSky,
                      onPressed: _showAddItemModal,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_rounded, size: 10, color: _primaryDark),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalItems',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(icon, size: 11, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(KoreksiItem item) {
    if (!_stokFisikControllers.containsKey(item.itemId)) {
      _stokFisikControllers[item.itemId] = TextEditingController(
          text: item.stokFisik > 0 ? item.stokFisik.toStringAsFixed(0) : '0'
      );
    }

    final controller = _stokFisikControllers[item.itemId]!;
    final hasSelisih = item.selisih != 0;
    final selisihColor = item.selisih > 0 ? _accentMint : (item.selisih < 0 ? _accentCoral : _textLight);
    final selisihIcon = item.selisih > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasSelisih ? _primaryDark.withOpacity(0.3) : _borderSoft,
          width: hasSelisih ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasSelisih ? _primaryDark : _bgSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: hasSelisih ? Colors.white : _textLight,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemNama,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.computer_rounded, size: 8, color: _primaryDark),
                            const SizedBox(width: 2),
                            if (_isLoadingStok && item.stokSistem == 0)
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: _accentGold),
                              )
                            else
                              Text(
                                'Stok Sistem: ${item.stokSistem.toStringAsFixed(0)}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: _primaryDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (hasSelisih)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.selisih > 0 ? _accentMintSoft : _accentCoralSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(selisihIcon, size: 8, color: selisihColor),
                              const SizedBox(width: 2),
                              Text(
                                'Selisih: ${item.selisih > 0 ? '+' : ''}${item.selisih.toStringAsFixed(0)}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: selisihColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              height: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasSelisih ? _primaryDark.withOpacity(0.3) : _borderSoft,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasSelisih ? _primaryDark : _textLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Fisik',
                    hintStyle: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final newValue = double.tryParse(value) ?? 0;
                    _updateItemStokFisik(item.itemId, newValue);
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _deleteItem(item),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accentCoralSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline, size: 14, color: _accentCoral),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _bgSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchController.text.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 32,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Belum ada item'
                : 'Item tidak ditemukan',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _searchController.text.isEmpty
                ? 'Tambah item dengan tombol di atas atau scan barcode'
                : 'Coba kata kunci lain',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: _textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isEdit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        border: Border(top: BorderSide(color: _borderSoft)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Item dengan selisih',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        size: 12,
                        color: _accentGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalItemsWithSelisih dari $_totalItems',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 110,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _primaryDark.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _saveKoreksi,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isEdit ? Icons.edit_rounded : Icons.save_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEdit ? 'Update' : 'Simpan',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemModal extends StatefulWidget {
  final List<KoreksiItem> existingItems;

  const _AddItemModal({
    required this.existingItems,
  });

  @override
  State<_AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<_AddItemModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Set<int> _selectedItemIds = {};
  final Map<int, TextEditingController> _qtyControllers = {};
  bool _isLoading = false;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await KoreksiService.getItemsForKoreksi();
      setState(() {
        _items = items.map((item) {
          return {
            'item_id': item['item_id'] ?? 0,
            'item_nama': item['item_nama']?.toString() ?? '',
            'item_hpp': item['item_hpp'] ?? 0.0,
          };
        }).toList();
        _filteredItems = List.from(_items);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _items;
      } else {
        _filteredItems = _items.where((item) {
          return item['item_nama'].toString().toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleSelection(Map<String, dynamic> item) {
    final itemId = item['item_id'] as int;
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
        _qtyControllers[itemId]?.dispose();
        _qtyControllers.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
        _qtyControllers[itemId] = TextEditingController(text: '0');
      }
    });
  }

  void _addSelectedItems() {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu item'), backgroundColor: Colors.orange),
      );
      return;
    }

    final selectedItems = <KoreksiItem>[];

    for (var item in _items) {
      final itemId = item['item_id'] as int;
      if (_selectedItemIds.contains(itemId)) {
        final controller = _qtyControllers[itemId]!;
        final stokFisik = double.tryParse(controller.text) ?? 0;

        if (stokFisik > 0) {
          selectedItems.add(KoreksiItem(
            itemId: itemId,
            itemNama: item['item_nama']?.toString() ?? '',
            hpp: (item['item_hpp'] ?? 0).toDouble(),
            stokSistem: 0,
            stokFisik: stokFisik,
            selisih: stokFisik,
          ));
        }
      }
    }

    Navigator.pop(context, selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tambah Item Koreksi',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderSoft),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search_rounded, color: _primaryDark, size: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.montserrat(fontSize: 11),
                      onChanged: _filterItems,
                      decoration: InputDecoration(
                        hintText: 'Cari item...',
                        hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(color: _accentGold),
            )
                : _filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: _textLight),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada item',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _textMedium,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final itemId = item['item_id'] as int;
                final isSelected = _selectedItemIds.contains(itemId);
                final controller = _qtyControllers[itemId];

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentGold.withOpacity(0.05) : _surfaceWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _accentGold : _borderSoft,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(item),
                          activeColor: _accentGold,
                          checkColor: Colors.white,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['item_nama'] ?? '').toString(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${item['item_id'] ?? 0}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  color: _textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          SizedBox(
                            width: 90,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: _bgSoft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _borderSoft),
                              ),
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.montserrat(fontSize: 10),
                                decoration: InputDecoration(
                                  labelText: 'Stok Fisik',
                                  labelStyle: GoogleFonts.montserrat(fontSize: 8, color: _textLight),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _borderSoft)),
              color: _surfaceWhite,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedItemIds.length} item dipilih',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textMedium,
                    ),
                  ),
                ),
                Container(
                  width: 90,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryDark, _primaryLight],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: _addSelectedItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Tambah',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum ToastType { success, error, info }