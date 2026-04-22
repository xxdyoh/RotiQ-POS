import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/serah_terima_service.dart';
import '../widgets/base_layout.dart';
import '../widgets/spk_selection_dialog.dart';
import '../models/serah_terima_model.dart';

class SerahTerimaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? serahTerimaHeader;
  final VoidCallback onSerahTerimaSaved;

  const SerahTerimaFormScreen({
    super.key,
    this.serahTerimaHeader,
    required this.onSerahTerimaSaved,
  });

  @override
  State<SerahTerimaFormScreen> createState() => _SerahTerimaFormScreenState();
}

class _SerahTerimaFormScreenState extends State<SerahTerimaFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};
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
  final Color _accentSkySoft = const Color(0xFF4CC9F0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingSpk = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorSerahTerima;
  Map<String, dynamic>? _selectedSpk;
  List<SerahTerimaItem> _items = [];
  List<SerahTerimaItem> _filteredItems = [];

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

    if (widget.serahTerimaHeader != null) {
      _nomorSerahTerima = widget.serahTerimaHeader!['stbj_nomor'];
      _selectedDate = DateTime.parse(widget.serahTerimaHeader!['stbj_tanggal']);
      _keteranganController.text = widget.serahTerimaHeader!['stbj_keterangan'] ?? '';
      _selectedSpk = {'spk_nomor': widget.serahTerimaHeader!['stbj_spk_nomor']};
      _loadSerahTerimaDetail();
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
    _qtyControllers.values.forEach((c) => c.dispose());
    _ketControllers.values.forEach((c) => c.dispose());
    _barcodeTimer?.cancel();
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    super.dispose();
  }

  void _setupAutoScanner() {
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
  }

  void _handleRawKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    final keyLabel = event.logicalKey.keyLabel;
    if (_isValidBarcodeCharacter(keyLabel)) {
      _barcodeBuffer += keyLabel;
      _resetBarcodeTimer();
    }
  }

  bool _isValidBarcodeCharacter(String char) {
    if (char.isEmpty || char.length > 1) return false;
    if (char == 'Enter' || char == 'Tab' || char == 'Escape') return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
        char == '-' || char == '.' || char == '_' || char == '/';
  }

  void _resetBarcodeTimer() {
    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(const Duration(milliseconds: 100), () {
      if (_barcodeBuffer.isNotEmpty && _barcodeBuffer.length >= 3) {
        final barcode = _barcodeBuffer;
        _barcodeBuffer = '';
        _processBarcode(barcode);
      } else {
        _barcodeBuffer = '';
      }
    });
  }

  void _processBarcode(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;
    final itemId = int.tryParse(cleanBarcode);
    if (itemId == null) {
      _showToast('Format barcode tidak valid', type: ToastType.error);
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (existingIndex != -1) {
      final newQty = _items[existingIndex].qtyTerima + 1;
      setState(() {
        _items[existingIndex] = _items[existingIndex].copyWith(qtyTerima: newQty);
        _filteredItems = List.from(_items);
        _qtyControllers[itemId]?.text = newQty.toString();
      });
      _showToast('${_items[existingIndex].itemNama} +1', type: ToastType.success);
      HapticFeedback.lightImpact();
    } else {
      _showToast('Item tidak ada dalam daftar SPK', type: ToastType.error);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _loadSerahTerimaDetail() async {
    if (_nomorSerahTerima == null) return;
    setState(() => _isLoading = true);

    try {
      final detail = await SerahTerimaService.getSerahTerimaDetail(_nomorSerahTerima!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      final spkDetail = await SerahTerimaService.getSpkDetail(_selectedSpk!['spk_nomor']);
      final spkDetails = Map.fromIterable(
        spkDetail['details'],
        key: (item) => item['spkd_brg_kode'],
        value: (item) => item['spkd_qty'],
      );

      setState(() {
        _items = details.map((detail) {
          int qtySpk = 0;
          final rawQty = spkDetails[detail['stbjd_brg_kode']];
          if (rawQty is int) qtySpk = rawQty;
          else if (rawQty is double) qtySpk = rawQty.toInt();
          else if (rawQty is String) qtySpk = int.tryParse(rawQty) ?? 0;

          return SerahTerimaItem(
            itemId: detail['stbjd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qtySpk: qtySpk,
            qtyTerima: detail['stbjd_qty']?.toInt() ?? 0,
            keterangan: detail['stbjd_keterangan'] ?? '',
            nourut: detail['stbjd_nourut'],
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

  Future<void> _loadSpkDetail(String spkNomor) async {
    setState(() {
      _isLoadingSpk = true;
      _items.clear();
      _qtyControllers.clear();
      _ketControllers.clear();
    });

    try {
      final spkDetail = await SerahTerimaService.getSpkDetail(spkNomor);
      final details = List<Map<String, dynamic>>.from(spkDetail['details']);

      setState(() {
        _items = details.map((detail) {
          int qtySpk = 0;
          final rawQty = detail['spkd_qty'];
          if (rawQty is int) qtySpk = rawQty;
          else if (rawQty is double) qtySpk = rawQty.toInt();
          else if (rawQty is String) qtySpk = int.tryParse(rawQty) ?? 0;

          return SerahTerimaItem(
            itemId: detail['spkd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qtySpk: qtySpk,
            qtyTerima: 0,
            keterangan: '',
          );
        }).toList();

        _filteredItems = List.from(_items);
        _initializeControllers();
      });

      _showToast('Berhasil load ${_items.length} item dari SPK', type: ToastType.success);
    } catch (e) {
      _showToast('Gagal memuat detail SPK: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingSpk = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      _qtyControllers[item.itemId] = TextEditingController(text: item.qtyTerima > 0 ? item.qtyTerima.toString() : '');
      _ketControllers[item.itemId] = TextEditingController(text: item.keterangan ?? '');
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _items.where((item) => item.itemNama.toLowerCase().contains(searchLower)).toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        _items[itemIndex] = _items[itemIndex].copyWith(qtyTerima: newQty);
      }
      _filteredItems = List.from(_items);
    });
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      _items[itemIndex] = _items[itemIndex].copyWith(keterangan: keterangan);
    }
    _filteredItems = List.from(_items);
  }

  Future<void> _selectSpk() async {
    HapticFeedback.selectionClick();
    final selectedSpk = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpkSelectionDialog(
        onSpkSelected: (spk) => Navigator.pop(context, spk),
      ),
    );

    if (selectedSpk != null) {
      setState(() => _selectedSpk = selectedSpk);
      await _loadSpkDetail(selectedSpk['spk_nomor']);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _primaryDark, onPrimary: Colors.white),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
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
                type == ToastType.success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white))),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint : _accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _saveSerahTerima() async {
    if (_selectedSpk == null) {
      _showToast('SPK harus dipilih!', type: ToastType.error);
      return;
    }

    // Sync keterangan dari controller (qty sudah real-time)
    for (var entry in _ketControllers.entries) {
      _updateItemKeterangan(entry.key, entry.value.text);
    }

    final itemsWithQty = _items.where((item) => item.qtyTerima > 0).toList();
    if (itemsWithQty.isEmpty) {
      _showToast('Minimal satu item harus memiliki quantity terima!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final requestData = {
        'tanggal': tanggalStr,
        'spk_nomor': _selectedSpk!['spk_nomor'],
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      final result = widget.serahTerimaHeader == null
          ? await SerahTerimaService.createSerahTerima(requestData)
          : await SerahTerimaService.updateSerahTerima(_nomorSerahTerima!, requestData);

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onSerahTerimaSaved();
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

  int get _totalItemsWithQty => _items.where((item) => item.qtyTerima > 0).length;
  int get _totalQuantity => _items.fold(0, (sum, item) => sum + item.qtyTerima);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.serahTerimaHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Serah Terima' : 'Tambah Serah Terima',
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
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildInfoCard(isEdit),
                        const SizedBox(height: 12),
                        _buildSpkCard(),
                        const SizedBox(height: 12),
                        _buildItemsCard(),
                      ],
                    ),
                  ),
                ),
                _buildModernBottomBar(isEdit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isEdit) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_nomorSerahTerima != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryDark.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number_rounded, size: 14, color: _primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_nomorSerahTerima!, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(child: _buildDateField()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _buildKeteranganField()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: _accentGold, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textMedium)),
                  Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeteranganField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
      child: Center(
        child: TextFormField(
          controller: _keteranganController,
          textAlignVertical: TextAlignVertical.center,
          style: GoogleFonts.montserrat(fontSize: 11, color: _textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Keterangan serah terima...',
            hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
            prefixIcon: Icon(Icons.description_rounded, color: _primaryDark, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildSpkCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _accentSkySoft, borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.inventory_rounded, color: _accentSky, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No. SPK', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                  Text(
                    _selectedSpk != null ? _selectedSpk!['spk_nomor'] : 'Belum dipilih',
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _selectedSpk != null ? _accentSky : _textLight),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentSky, _accentSky.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: _accentSky.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectSpk,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Pilih SPK', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
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

  Widget _buildItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSoft),
        boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildSearchField()),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildBarcodeField()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    _buildStatChip(Icons.inventory_rounded, '${_items.length}'),
                    const SizedBox(width: 4),
                    _buildStatChip(Icons.shopping_cart_rounded, '$_totalQuantity', color: _accentGold),
                    const SizedBox(width: 4),
                    _buildStatChip(Icons.check_circle_rounded, '$_totalItemsWithQty', color: _accentMint),
                  ],
                ),
              ],
            ),
          ),
          if (_filteredItems.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
      child: Center(
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          style: GoogleFonts.montserrat(fontSize: 11),
          onChanged: _filterItems,
          decoration: InputDecoration(
            hintText: 'Cari item...',
            hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
            prefixIcon: Icon(Icons.search_rounded, color: _primaryDark, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
      child: Center(
        child: TextField(
          controller: _barcodeController,
          focusNode: _barcodeFocusNode,
          textAlignVertical: TextAlignVertical.center,
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
            prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: _accentMint, size: 14),
            suffixIcon: _barcodeController.text.isNotEmpty
                ? GestureDetector(
              onTap: () => _barcodeController.clear(),
              child: Container(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: _textLight, size: 12)),
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: (color ?? _primaryDark).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color ?? _primaryDark),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: color ?? _primaryDark)),
        ],
      ),
    );
  }

  Widget _buildModernItemCard(SerahTerimaItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(text: item.qtyTerima > 0 ? item.qtyTerima.toString() : '');
    }
    if (!_ketControllers.containsKey(item.itemId)) {
      _ketControllers[item.itemId] = TextEditingController(text: item.keterangan ?? '');
    }

    final qtyController = _qtyControllers[item.itemId]!;
    final ketController = _ketControllers[item.itemId]!;
    final hasQty = item.qtyTerima > 0;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft, width: hasQty ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: hasQty ? _primaryDark : _bgSoft, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Icon(Icons.inventory_2_outlined, color: hasQty ? Colors.white : _textLight, size: 16)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemNama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(4)),
                            child: Text('ID: ${item.itemId}', style: GoogleFonts.montserrat(fontSize: 8, color: _textMedium)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: _accentSkySoft, borderRadius: BorderRadius.circular(4)),
                            child: Text('SPK: ${item.qtySpk}', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: _accentSky)),
                          ),
                          if (hasQty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: _accentGoldSoft, borderRadius: BorderRadius.circular(4)),
                              child: Text('Terima: ${item.qtyTerima}', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: _accentGold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft)),
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: hasQty ? _primaryDark : _textLight),
                      decoration: InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                        isDense: true,
                        hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                      ),
                      onChanged: (value) {
                        final intValue = int.tryParse(value) ?? 0;
                        _updateItemQty(item.itemId, intValue);
                      },
                      onTap: () => qtyController.selection = TextSelection(baseOffset: 0, extentOffset: qtyController.text.length),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 28,
              decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(4), border: Border.all(color: _borderSoft)),
              child: TextField(
                controller: ketController,
                style: GoogleFonts.montserrat(fontSize: 10, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Keterangan item (opsional)',
                  hintStyle: GoogleFonts.montserrat(fontSize: 9, color: _textLight),
                  prefixIcon: Icon(Icons.notes_rounded, color: _textLight, size: 12),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                onChanged: (value) => _updateItemKeterangan(item.itemId, value),
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
            decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
            child: Icon(_searchController.text.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded, size: 32, color: _textLight),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedSpk == null ? 'Pilih SPK terlebih dahulu' : (_searchController.text.isEmpty ? 'Tidak ada item dari SPK' : 'Item tidak ditemukan'),
            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: _textDark),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedSpk == null ? 'Klik tombol Pilih SPK untuk memulai' : (_searchController.text.isEmpty ? 'Item akan muncul setelah SPK dipilih' : 'Coba kata kunci lain'),
            style: GoogleFonts.montserrat(fontSize: 10, color: _textLight),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Item dengan QTY', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: _accentMint),
                      const SizedBox(width: 4),
                      Text('$_totalItemsWithQty dari ${_items.length}', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _saveSerahTerima,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isEdit ? Icons.edit_rounded : Icons.save_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(isEdit ? 'Update' : 'Simpan', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
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