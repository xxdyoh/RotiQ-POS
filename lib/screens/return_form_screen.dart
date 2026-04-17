import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/return_service.dart';
import '../models/return_model.dart';
import '../widgets/base_layout.dart';

class ReturnFormScreen extends StatefulWidget {
  final Map<String, dynamic>? returnHeader;
  final VoidCallback onReturnSaved;

  const ReturnFormScreen({
    super.key,
    this.returnHeader,
    required this.onReturnSaved,
  });

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
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
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _scannerActive = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorReturn;
  List<ReturnItem> _items = [];
  List<ReturnItem> _filteredItems = [];

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

    if (widget.returnHeader != null) {
      _nomorReturn = widget.returnHeader!['ret_nomor'];
      _selectedDate = DateTime.parse(widget.returnHeader!['ret_tanggal']);
      _keteranganController.text = widget.returnHeader!['ret_keterangan'] ?? '';
      _loadReturnDetail();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeTimer?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _keteranganController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _searchFocusNode.dispose();
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
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

    // Cek apakah item sudah ada di list
    bool found = false;
    for (int i = 0; i < _filteredItems.length; i++) {
      if (_filteredItems[i].itemId == itemId) {
        final currentQty = _filteredItems[i].qty;
        final newQty = currentQty + 1;
        setState(() {
          _filteredItems[i] = ReturnItem(
            itemId: _filteredItems[i].itemId,
            itemNama: _filteredItems[i].itemNama,
            qty: newQty,
          );
          final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
          if (itemIndex != -1) {
            _items[itemIndex] = ReturnItem(
              itemId: _items[itemIndex].itemId,
              itemNama: _items[itemIndex].itemNama,
              qty: newQty,
            );
          }
          if (_qtyControllers.containsKey(itemId)) {
            _qtyControllers[itemId]?.text = newQty.toString();
          }
        });
        _showToast('${_filteredItems[i].itemNama} +1', type: ToastType.success);
        HapticFeedback.lightImpact();
        found = true;
        break;
      }
    }

    // Jika belum ada, cari item di database
    if (!found) {
      setState(() => _isLoading = true);
      try {
        final items = await ReturnService.getItemsForReturn();
        Map<String, dynamic>? itemData;

        for (var item in items) {
          if (item['item_id'] == itemId) {
            itemData = item;
            break;
          }
        }

        if (itemData != null) {
          final newItem = ReturnItem(
            itemId: itemId,
            itemNama: itemData['item_nama']?.toString() ?? '',
            qty: 1,
          );

          setState(() {
            _items.add(newItem);
            _filteredItems = List.from(_items);
            _qtyControllers[itemId] = TextEditingController(text: '1');
          });

          _showToast('Item ditambahkan: ${newItem.itemNama}', type: ToastType.success);
          HapticFeedback.mediumImpact();
        } else {
          _showToast('Item dengan ID $itemId tidak ditemukan', type: ToastType.error);
          HapticFeedback.heavyImpact();
        }
      } catch (e) {
        _showToast('Error: ${e.toString()}', type: ToastType.error);
      } finally {
        setState(() => _isLoading = false);
      }
    }
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

  Widget _buildScannerToggle() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _scannerActive ? _accentMint.withOpacity(0.15) : _textMedium.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _scannerActive ? _accentMint : _textMedium,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 16,
            color: _scannerActive ? _accentMint : _textMedium,
          ),
          const SizedBox(width: 6),
          Text(
            _scannerActive ? 'SCAN ON' : 'SCAN OFF',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _scannerActive ? _accentMint : _textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadReturnDetail() async {
    if (_nomorReturn == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await ReturnService.getReturnDetail(_nomorReturn!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['retd_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return ReturnItem(
            itemId: detail['retd_item_id'],
            itemNama: detail['item_nama'] ?? '',
            qty: qty,
          );
        }).toList();
        _filteredItems = List.from(_items);
        _initializeControllers();
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      if (!_qtyControllers.containsKey(item.itemId)) {
        _qtyControllers[item.itemId] = TextEditingController(
            text: item.qty > 0 ? item.qty.toString() : ''
        );
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _items.where((item) {
          return item.itemNama.toLowerCase().contains(searchLower) ||
              item.itemId.toString().contains(searchLower);
        }).toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        _items[itemIndex] = ReturnItem(
          itemId: _items[itemIndex].itemId,
          itemNama: _items[itemIndex].itemNama,
          qty: newQty,
        );
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = ReturnItem(
          itemId: _filteredItems[filteredIndex].itemId,
          itemNama: _filteredItems[filteredIndex].itemNama,
          qty: newQty,
        );
      }
    });
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

  void _showAddItemModal() async {
    HapticFeedback.selectionClick();
    final selectedItems = await showModalBottomSheet<List<ReturnItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: AddReturnItemModal(
          existingItems: _items,
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        for (var newItem in selectedItems) {
          final existingIndex = _items.indexWhere((item) => item.itemId == newItem.itemId);
          if (existingIndex >= 0) {
            final newQty = _items[existingIndex].qty + newItem.qty;
            _items[existingIndex] = ReturnItem(
              itemId: _items[existingIndex].itemId,
              itemNama: _items[existingIndex].itemNama,
              qty: newQty,
            );
            if (_qtyControllers.containsKey(newItem.itemId)) {
              _qtyControllers[newItem.itemId]?.text = newQty.toString();
            }
          } else {
            _items.add(newItem);
            _qtyControllers[newItem.itemId] = TextEditingController(text: newItem.qty.toString());
          }
        }
        _filteredItems = List.from(_items);
      });
      _showToast('${selectedItems.length} item ditambahkan', type: ToastType.success);
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

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final intValue = int.tryParse(controller.text) ?? 0;
      _updateItemQty(itemId, intValue);
    }
  }

  Future<void> _saveReturn() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllQtyFromControllers();

    final itemsWithQty = _items.where((item) => item.qty > 0).toList();

    if (itemsWithQty.isEmpty) {
      _showToast('Minimal satu item harus memiliki quantity!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final itemsJson = itemsWithQty.map((item) => item.toJson()).toList();

      final result = widget.returnHeader == null
          ? await ReturnService.createReturn(
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      )
          : await ReturnService.updateReturn(
        nomor: _nomorReturn!,
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      );

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onReturnSaved();
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
    return _items.where((item) => item.qty > 0).length;
  }

  int get _totalQuantity {
    return _items.fold(0, (sum, item) => sum + item.qty);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.returnHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Return' : 'Tambah Return',
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
                        _buildFormCard(isEdit),
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

  Widget _buildFormCard(bool isEdit) {
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
        child: Column(
          children: [
            if (_nomorReturn != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _primaryDark.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number_rounded, size: 12, color: _primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      _nomorReturn!,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _bgSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: _accentGold, size: 16),
                          const SizedBox(width: 10),
                          Column(
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded, color: _primaryDark, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _keteranganController,
                            style: GoogleFonts.montserrat(fontSize: 12, color: _textDark),
                            decoration: InputDecoration(
                              hintText: 'Keterangan...',
                              hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textLight),
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
              ],
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
                  child: Icon(
                    Icons.assignment_return_rounded,
                    color: _primaryDark,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daftar Item Return',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentGold,
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
                            const SizedBox(width: 10),
                            Icon(Icons.search_rounded, color: _primaryDark, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: GoogleFonts.montserrat(fontSize: 12),
                                onChanged: _filterItems,
                                decoration: InputDecoration(
                                  hintText: 'Cari item...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textLight),
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
                            const SizedBox(width: 10),
                            Icon(Icons.qr_code_scanner_rounded, color: _accentMint, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                focusNode: _barcodeFocusNode,
                                style: GoogleFonts.montserrat(fontSize: 12),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    _processBarcode(value);
                                    _barcodeController.clear();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Scan barcode...',
                                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textLight),
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
                                  child: Icon(Icons.close_rounded, color: _textLight, size: 16),
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
                      label: 'Add Item',
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
                            '${_items.length}',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentGoldSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart_rounded, size: 10, color: _accentGold),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalQuantity',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentMintSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 10, color: _accentMint),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalItemsWithQty',
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
                if (_filteredItems.isEmpty && !_isLoading)
                  _buildEmptyState()
                else if (!_isLoading)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(10),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filteredItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 32,
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(ReturnItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }

    final qtyController = _qtyControllers[item.itemId]!;
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
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasQty ? _primaryDark : _bgSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: hasQty ? Colors.white : _textLight,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemNama,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _bgSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ID: ${item.itemId}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: _textMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 38,
              child: TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasQty ? _primaryDark : _textLight,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: _borderSoft),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  isDense: true,
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: _textLight,
                  ),
                ),
                onChanged: (value) {
                  final intValue = int.tryParse(value) ?? 0;
                  _updateItemQty(item.itemId, intValue);
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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _bgSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchController.text.isEmpty
                  ? Icons.assignment_return_outlined
                  : Icons.search_off_rounded,
              size: 40,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isEmpty
                ? 'Belum ada item return'
                : 'Item tidak ditemukan',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchController.text.isEmpty
                ? 'Tambah item dengan tombol Add atau scan barcode'
                : 'Coba kata kunci lain',
            style: GoogleFonts.montserrat(
              fontSize: 11,
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
                    'Item dengan QTY',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: _textLight,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: _accentMint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalItemsWithQty dari ${_items.length}',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
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
              width: 130,
              height: 44,
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
                  onTap: _isSaving ? null : _saveReturn,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
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
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? 'Update' : 'Simpan',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
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

enum ToastType { success, error, info }

// Modal untuk Add Item
class AddReturnItemModal extends StatefulWidget {
  final List<ReturnItem> existingItems;

  const AddReturnItemModal({
    super.key,
    required this.existingItems,
  });

  @override
  State<AddReturnItemModal> createState() => _AddReturnItemModalState();
}

class _AddReturnItemModalState extends State<AddReturnItemModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Map<int, TextEditingController> _qtyControllers = {};
  bool _isLoading = true;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
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
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await ReturnService.getItemsForReturn();
      setState(() {
        _items = items.map((item) {
          return {
            'item_id': item['item_id'] ?? 0,
            'item_nama': item['item_nama']?.toString() ?? 'Unknown Item',
          };
        }).toList();
        _filteredItems = List.from(_items);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _items.where((item) {
          final itemNama = item['item_nama']?.toString() ?? '';
          final itemId = item['item_id']?.toString() ?? '';
          return itemNama.toLowerCase().contains(searchLower) ||
              itemId.contains(searchLower);
        }).toList();
      }
    });
  }

  void _addSelectedItems() {
    final selectedItems = <ReturnItem>[];
    for (var item in _filteredItems) {
      final itemId = item['item_id'] as int;
      final controller = _qtyControllers[itemId];
      if (controller != null && controller.text.isNotEmpty) {
        final qty = int.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          selectedItems.add(ReturnItem(
            itemId: itemId,
            itemNama: item['item_nama']?.toString() ?? 'Unknown Item',
            qty: qty,
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
                colors: [_primaryDark, const Color(0xFF34495E)],
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tambah Item Return',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderSoft),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search_rounded, size: 16, color: _primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.montserrat(fontSize: 12),
                      onChanged: _filterItems,
                      decoration: InputDecoration(
                        hintText: 'Cari item...',
                        hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textLight),
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
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: _textLight),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada item',
                    style: GoogleFonts.montserrat(fontSize: 12, color: const Color(0xFF718096)),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final itemId = item['item_id'] as int;
                final isExisting = widget.existingItems.any((i) => i.itemId == itemId);

                if (!_qtyControllers.containsKey(itemId)) {
                  _qtyControllers[itemId] = TextEditingController();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExisting ? _accentGold : _borderSoft,
                      width: isExisting ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _primaryDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF2C3E50)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['item_nama']?.toString() ?? 'Unknown Item',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'ID: ${item['item_id']}',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                color: _textLight,
                              ),
                            ),
                            if (isExisting)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sudah ada di daftar',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    color: _accentGold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        height: 34,
                        child: TextField(
                          controller: _qtyControllers[itemId],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.montserrat(fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Qty',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: _borderSoft),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgSoft,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: _addSelectedItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Tambah',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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