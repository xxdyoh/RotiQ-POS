import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/stokin_service.dart';
import '../services/do_service.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../models/stokin_model.dart';
import '../widgets/base_layout.dart';
import 'add_item_modal.dart';
import 'load_do_dialog.dart';

class StokinFormScreen extends StatefulWidget {
  final Map<String, dynamic>? stokinHeader;
  final VoidCallback onStokinSaved;

  const StokinFormScreen({
    super.key,
    this.stokinHeader,
    required this.onStokinSaved,
  });

  @override
  State<StokinFormScreen> createState() => _StokinFormScreenState();
}

class _StokinFormScreenState extends State<StokinFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  // Warna utama dari POS screen - Navy/Dark Blue
  final Color _primaryDark = const Color(0xFF2C3E50); // Navy utama
  final Color _primaryLight = const Color(0xFF34495E); // Navy lebih terang
  final Color _accentGold = const Color(0xFFF6A918); // Gold aksen
  final Color _accentMint = const Color(0xFF06D6A0); // Mint
  final Color _accentCoral = const Color(0xFFFF6B6B); // Coral
  final Color _accentSky = const Color(0xFF4CC9F0); // Sky Blue

  // Soft version untuk background
  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);

  final Color _bgSoft = const Color(0xFFF8FAFC); // Light background
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<StokinItem> _allItems = [];
  List<StokinItem> _filteredItems = [];
  List<StokinItem> _selectedItems = [];

  String? _nomorStokin;

  bool _isFromPenjualan = false;
  List<String> _referensiList = [];

  bool _isFromDo = false;
  String? _currentDoNomor;

  String _barcodeBuffer = '';
  Timer? _barcodeTimer;

  // Search state
  bool _isSearching = false;

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();

    // Setup animations
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

    if (widget.stokinHeader != null) {
      _nomorStokin = widget.stokinHeader!['sti_nomor'];
      _selectedDate = DateTime.parse(widget.stokinHeader!['sti_tanggal']);
      _keteranganController.text = widget.stokinHeader!['sti_keterangan'] ?? '';

      _loadStokinDetail();
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
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _barcodeTimer?.cancel();
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    super.dispose();
  }

  void _setupAutoScanner() {
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
  }

  void _handleRawKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final logicalKey = event.logicalKey;
    final keyLabel = logicalKey.keyLabel;

    if (_isValidBarcodeCharacter(keyLabel)) {
      _barcodeBuffer += keyLabel;
      _resetBarcodeTimer();
    }
  }

  bool _isValidBarcodeCharacter(String char) {
    if (char.isEmpty || char.length > 1) return false;

    if (char == 'Enter' || char == 'Tab' || char == 'Escape') return false;

    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // angka
        (code >= 65 && code <= 90) ||    // huruf besar
        (code >= 97 && code <= 122) ||   // huruf kecil
        char == '-' || char == '.' || char == '_' || char == '/';
  }

  void _resetBarcodeTimer() {
    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(const Duration(milliseconds: 100), () {
      if (_barcodeBuffer.isNotEmpty && _barcodeBuffer.length >= 3) {
        final barcodeToProcess = _barcodeBuffer;
        _barcodeBuffer = '';
        _processBarcode(barcodeToProcess);
      } else {
        _barcodeBuffer = '';
      }
    });
  }

  void _processBarcode(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    _updateQtyFromBarcode(cleanBarcode);
  }

  void _updateQtyFromBarcode(String barcode) {
    final itemId = int.tryParse(barcode);
    if (itemId == null) {
      _showToast('Format barcode tidak valid', type: ToastType.error);
      return;
    }

    final existingIndices = <int>[];
    for (int i = 0; i < _selectedItems.length; i++) {
      if (_selectedItems[i].itemId == itemId) {
        existingIndices.add(i);
      }
    }

    if (existingIndices.isNotEmpty) {
      setState(() {
        final index = existingIndices[0];
        _selectedItems[index].qty += 1;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex >= 0) {
          _filteredItems[filteredIndex].qty = _selectedItems[index].qty;
        }

        if (_qtyControllers.containsKey(itemId)) {
          _qtyControllers[itemId]?.text = _selectedItems[index].qty.toString();
        } else {
          _qtyControllers[itemId] = TextEditingController(text: _selectedItems[index].qty.toString());
        }
      });

      _showToast('${_selectedItems[existingIndices[0]].itemNama} +1', type: ToastType.success);
      HapticFeedback.lightImpact();
    } else {
      _showToast('Item tidak ada dalam daftar', type: ToastType.error);
      HapticFeedback.heavyImpact();
    }
  }

  // Modern Toast dengan SnackBar (lebih simple)
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
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral :
        _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    _showToast(message, type: ToastType.success);
  }

  void _showErrorSnackbar(String message) {
    _showToast(message, type: ToastType.error);
  }

  void _showInfoSnackbar(String message) {
    _showToast(message, type: ToastType.info);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadStokinDetail() async {
    if (_nomorStokin == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await StokinService.getStokInDetail(_nomorStokin!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedItems = details.map((detail) {
          return StokinItem(
            itemId: detail['stid_item_id'],
            itemNama: detail['item_nama'] ?? '',
            qty: detail['stid_qty']?.toInt() ?? 0,
            referensi: detail['referensi'],
          );
        }).toList();

        _filteredItems = _selectedItems;
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
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

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        _selectedItems[index] = StokinItem(
          itemId: _selectedItems[index].itemId,
          itemNama: _selectedItems[index].itemNama,
          qty: newQty,
        );

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = StokinItem(
            itemId: _filteredItems[filteredIndex].itemId,
            itemNama: _filteredItems[filteredIndex].itemNama,
            qty: newQty,
          );
        }
      }
    });
  }

  void _showAddItemModal() async {
    HapticFeedback.selectionClick();
    final selectedItems = await showModalBottomSheet<List<StokinItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: AddItemModal(
          existingItems: _selectedItems,
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        for (var newItem in selectedItems) {
          final existingIndex = _selectedItems.indexWhere((item) => item.itemId == newItem.itemId);
          if (existingIndex >= 0) {
            _selectedItems[existingIndex].qty += newItem.qty;
          } else {
            _selectedItems.add(newItem);
          }
        }
        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
        _isFromDo = false;
        _currentDoNomor = null;
      });
      _showToast('${selectedItems.length} item ditambahkan', type: ToastType.success);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: _surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final intValue = int.tryParse(controller.text) ?? 0;
      _updateItemQty(itemId, intValue);
    }
  }

  Future<void> _saveStokin() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllQtyFromControllers();

    final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
    if (itemsWithQty.isEmpty) {
      _showToast('Minimal satu item harus memiliki quantity!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      if (_isFromPenjualan && _referensiList.isNotEmpty) {
        requestData['source'] = 'penjualan';
        requestData['referensi_list'] = _referensiList.join(',');
      }

      if (_isFromDo && _currentDoNomor != null) {
        requestData['sti_do_nomor'] = _currentDoNomor;
      }

      final result = widget.stokinHeader == null
          ? await StokinService.createStokIn(requestData)
          : await StokinService.updateStokIn({
        'nomor': _nomorStokin!,
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
        'source': _isFromPenjualan && _referensiList.isNotEmpty ? 'penjualan' : null,
        'referensi_list': _isFromPenjualan && _referensiList.isNotEmpty
            ? _referensiList.join(',')
            : null,
        'sti_do_nomor': _isFromDo ? _currentDoNomor : null,
      });

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onStokinSaved();
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

  int get _totalItemsWithQty {
    return _selectedItems.where((item) => item.qty > 0).length;
  }

  int get _totalQuantity {
    return _selectedItems.fold(0, (sum, item) => sum + item.qty);
  }

  Future<void> _loadPenjualan() async {
    final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() {
      _isLoading = true;
      _isFromDo = false;
      _currentDoNomor = null;
    });

    try {
      final penjualanData = await StokinService.loadPenjualan(tanggalStr);

      if (penjualanData.isEmpty) {
        _showToast('Tidak ada data penjualan', type: ToastType.info);
        setState(() => _isLoading = false);
        return;
      }

      final newItems = <StokinItem>[];
      final referensiList = <String>[];

      for (var data in penjualanData) {
        final itemId = int.parse(data['item_id'].toString());
        final qty = int.parse(data['qty'].toString());
        final referensi = data['referensi_list'].toString();
        final itemNama = data['item_nama'].toString();

        bool exists = false;
        for (int i = 0; i < _selectedItems.length; i++) {
          if (_selectedItems[i].itemId == itemId) {
            exists = true;
            break;
          }
        }

        if (!exists) {
          newItems.add(StokinItem(
            itemId: itemId,
            itemNama: itemNama,
            qty: qty,
            referensi: referensi,
          ));

          if (referensi.isNotEmpty) {
            final refs = referensi.split(',');
            for (var r in refs) {
              final trimmed = r.trim();
              if (trimmed.isNotEmpty) {
                referensiList.add(trimmed);
              }
            }
          }
        }
      }

      final updatedSelectedItems = List<StokinItem>.from(_selectedItems);
      updatedSelectedItems.addAll(newItems);

      setState(() {
        _selectedItems = updatedSelectedItems;
        _filteredItems = List.from(updatedSelectedItems);
        _isFromPenjualan = true;
        _referensiList = referensiList.toSet().toList();
        _initializeControllers();
      });

      _showToast('Berhasil load ${newItems.length} item', type: ToastType.success);
      HapticFeedback.lightImpact();
    } catch (e) {
      _showToast('Error: $e', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDoSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => LoadDoDialog(
        onLoad: _loadDoItems,
      ),
    );
  }

  Future<void> _loadDoItems(String doNomor) async {
    setState(() {
      _isLoading = true;
      _isFromDo = true;
      _currentDoNomor = doNomor;
      _isFromPenjualan = false;
      _referensiList.clear();
    });

    try {
      final data = await DoService.getDoDetailForStokIn(doNomor);
      final header = data['header'];
      final details = data['details'];

      final newItems = details.map<StokinItem>((detail) {
        return StokinItem(
          itemId: detail['item_id'],
          itemNama: detail['item_nama'],
          qty: 0,
        );
      }).toList();

      setState(() {
        _selectedItems = newItems;
        _filteredItems = List.from(newItems);
        _keteranganController.text = header['do_nomor'] ?? '';
        _initializeControllers();
      });

      _showToast('Berhasil load ${newItems.length} item dari DO', type: ToastType.success);
      _barcodeFocusNode.requestFocus();
      HapticFeedback.lightImpact();
    } catch (e) {
      _showToast('Error: $e', type: ToastType.error);
      setState(() {
        _isFromDo = false;
        _currentDoNomor = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.stokinHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Stock In' : 'Tambah Stock In',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: _bgSoft,
            child: Column(
              children: [
                // HAPUS HEADER "Stock In Baru" - langsung ke konten

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Info Card
                        _buildInfoCard(),

                        const SizedBox(height: 12),

                        // Items Card
                        _buildItemsCard(),
                      ],
                    ),
                  ),
                ),

                // Modern Bottom Bar
                _buildModernBottomBar(isEdit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(bool isEdit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
            child: Icon(
              isEdit ? Icons.edit_note_rounded : Icons.inventory_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Stock In' : 'Stock In Baru',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_nomorStokin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _nomorStokin!,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoading)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
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
            // Date Picker
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40, // Fixed height
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: _primaryDark,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                color: _textMedium,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
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

            // Keterangan Field - Height lebih kecil (40)
            Expanded(
              flex: 2,
              child: Container(
                height: 40, // Sama dengan date picker
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderSoft),
                ),
                child: Center(
                  child: TextFormField(
                    controller: _keteranganController,
                    textAlignVertical: TextAlignVertical.center,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textDark,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Keterangan...',
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: _textLight,
                      ),
                      prefixIcon: Icon(
                        Icons.description_rounded,
                        color: _primaryDark,
                        size: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      isDense: true,
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
          // Header
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
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: _primaryDark,
                    size: 14,
                  ),
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
                      Icon(
                        Icons.shopping_bag_rounded,
                        size: 10,
                        color: _primaryDark,
                      ),
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
                // Search & Barcode Row - dengan center rata kiri
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onChanged: _filterItems,
                            decoration: InputDecoration(
                              hintText: 'Cari item...',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textLight,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: _primaryDark,
                                size: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Barcode Field
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderSoft),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _barcodeController,
                            focusNode: _barcodeFocusNode,
                            textAlignVertical: TextAlignVertical.center,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _processBarcode(value);
                                _barcodeController.clear();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Scan barcode...',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textLight,
                              ),
                              prefixIcon: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: _accentMint,
                                size: 14,
                              ),
                              suffixIcon: _barcodeController.text.isNotEmpty
                                  ? GestureDetector(
                                onTap: () => _barcodeController.clear(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: _textLight,
                                    size: 12,
                                  ),
                                ),
                              )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // SINGLE ROW: Action Buttons + Total Item + Total Qty
                Row(
                  children: [
                    // Action Buttons
                    _buildModernActionButton(
                      label: 'Add',
                      icon: Icons.add_rounded,
                      color: _accentSky,
                      onPressed: _isFromDo ? null : _showAddItemModal,
                    ),
                    const SizedBox(width: 4),
                    _buildModernActionButton(
                      label: 'Penjualan',
                      icon: Icons.download_rounded,
                      color: _accentMint,
                      onPressed: _loadPenjualan,
                    ),
                    const SizedBox(width: 4),
                    _buildModernActionButton(
                      label: 'DO',
                      icon: Icons.local_shipping_rounded,
                      color: _accentGold,
                      onPressed: _showDoSelectionDialog,
                    ),

                    const Spacer(),

                    // Total Items
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_rounded,
                            size: 10,
                            color: _primaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedItems.length}',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Total Qty
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentMintSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            size: 10,
                            color: _accentMint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalQuantity',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accentMint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Items List
                if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
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
              mainAxisSize: MainAxisSize.min,
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

  Widget _buildModernItemCard(StokinItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }

    final controller = _qtyControllers[item.itemId]!;
    final hasQty = item.qty > 0;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft,
          width: hasQty ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Item Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasQty ? _primaryDark : _bgSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: hasQty ? Colors.white : _textLight,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Item Details
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _bgSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${item.itemId}',
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            color: _textMedium,
                          ),
                        ),
                      ),
                      if (hasQty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _accentMintSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${item.qty}',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _accentMint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Quantity Input
            Container(
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft,
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
                  color: hasQty ? _primaryDark : _textLight,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  isDense: true,
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: _textLight,
                  ),
                ),
                onChanged: (value) {
                  final intValue = int.tryParse(value) ?? 0;
                  _updateItemQty(item.itemId, intValue);
                },
                onTap: () {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
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
                ? 'Tambah item dengan tombol di atas'
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

  Widget _buildModernBottomBar(bool isEdit) {
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
            // Total Summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Item dengan QTY',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: _accentMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalItemsWithQty dari ${_selectedItems.length}',
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

            // Save Button
            Container(
              width: 120,
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
                  onTap: _isSaving ? null : _saveStokin,
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

// Toast Type enum
enum ToastType { success, error, info }