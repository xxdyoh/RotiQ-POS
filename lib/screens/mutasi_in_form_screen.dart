import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/do_service.dart';
import '../services/cabang_service.dart';
import '../services/session_manager.dart';
import '../services/stokin_service.dart';
import '../models/cabang_model.dart';
import '../models/mutasi_in_model.dart';
import '../widgets/base_layout.dart';

class MutasiInFormScreen extends StatefulWidget {
  final Map<String, dynamic>? mutasiInHeader;
  final VoidCallback onMutasiInSaved;

  const MutasiInFormScreen({
    super.key,
    this.mutasiInHeader,
    required this.onMutasiInSaved,
  });

  @override
  State<MutasiInFormScreen> createState() => _MutasiInFormScreenState();
}

class _MutasiInFormScreenState extends State<MutasiInFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final FocusNode _barcodeFocusNode = FocusNode();

  Timer? _barcodeDebounce;

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
  bool _isLoadingMutasi = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorMutasiIn;
  Cabang? _selectedCabangAsal;
  Map<String, dynamic>? _selectedMutasiOut;
  List<MutasiInItem> _items = [];
  List<MutasiInItem> _filteredItems = [];

  List<Cabang> _cabangList = [];
  List<Map<String, dynamic>> _mutasiOutList = [];

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

    _loadCabangList();

    if (widget.mutasiInHeader != null) {
      _nomorMutasiIn = widget.mutasiInHeader!['sti_nomor'];
      _selectedDate = DateTime.parse(widget.mutasiInHeader!['sti_tanggal']);
      _keteranganController.text = widget.mutasiInHeader!['sti_keterangan'] ?? '';
      _loadMutasiInDetail();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _keteranganController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _onBarcodeChanged(String value) {
    if (_barcodeDebounce?.isActive ?? false) _barcodeDebounce?.cancel();

    _barcodeDebounce = Timer(const Duration(milliseconds: 300), () {
      if (value.isNotEmpty) {
        _processBarcode(value);
      }
    });
  }

  void _processBarcode(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final itemId = int.tryParse(cleanBarcode);
    if (itemId == null) {
      _showToast('Format barcode tidak valid', type: ToastType.error);
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    bool found = false;
    for (int i = 0; i < _filteredItems.length; i++) {
      if (_filteredItems[i].itemId == itemId) {
        final currentQtyMutasi = _filteredItems[i].qtyMutasi;
        final newQtyMutasi = currentQtyMutasi + 1;
        setState(() {
          _filteredItems[i] = _filteredItems[i].copyWith(qtyMutasi: newQtyMutasi);
          final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
          if (itemIndex != -1) {
            _items[itemIndex] = _items[itemIndex].copyWith(qtyMutasi: newQtyMutasi);
          }
          if (_qtyControllers.containsKey(itemId)) {
            _qtyControllers[itemId]?.text = newQtyMutasi.toString();
          }
        });
        _showToast('${_filteredItems[i].itemNama} +1 (Mutasi: $newQtyMutasi)', type: ToastType.success);
        HapticFeedback.lightImpact();
        found = true;
        break;
      }
    }

    if (!found) {
      _showToast('Item tidak ada dalam daftar mutasi out', type: ToastType.error);
      HapticFeedback.heavyImpact();
    }

    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _loadCabangList() async {
    try {
      final cabangList = await CabangService.getCabangList();
      setState(() {
        _cabangList = cabangList;
      });
    } catch (e) {
      _showToast('Gagal memuat data cabang: ${e.toString()}', type: ToastType.error);
    }
  }

  Future<void> _loadMutasiInDetail() async {
    if (_nomorMutasiIn == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await StokinService.getStokInDetail(_nomorMutasiIn!);
      final header = detail['header'];
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedCabangAsal = _cabangList.firstWhere(
              (c) => c.kode == header['sti_cbg_asal'],
          orElse: () => Cabang(kode: '', nama: '', database: '', host: '', user: '', password: '', port: '', jenis: '', aktif: 0),
        );
        _selectedMutasiOut = {
          'mutc_nomor': header['sti_mutasi_nomor'],
        };
        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['stid_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return MutasiInItem(
            itemId: detail['stid_item_id'],
            itemNama: detail['item_nama'] ?? '',
            qty: qty,
            qtyMutasi: detail['qty_mutasi'] ?? 0,
            referensi: detail['referensi'],
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

  Future<void> _loadMutasiOutList() async {
    if (_selectedCabangAsal == null) return;

    setState(() => _isLoadingMutasi = true);

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(2024, 1, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final mutasiData = await DoService.getMutasiOutByCabang(
        _selectedCabangAsal!.database,
        startDate,
        endDate,
      );
      setState(() {
        _mutasiOutList = mutasiData;
      });
    } catch (e) {
      _showToast('Gagal memuat data mutasi out: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingMutasi = false);
    }
  }

  Future<void> _loadMutasiOutDetail(String nomor) async {
    if (_selectedCabangAsal == null) return;

    setState(() {
      _isLoadingMutasi = true;
      _items.clear();
      _qtyControllers.clear();
    });

    try {
      final mutasiDetail = await DoService.getMutasiOutDetailFromCabang(
        _selectedCabangAsal!.database,
        nomor,
      );

      final details = List<Map<String, dynamic>>.from(mutasiDetail['details']);

      setState(() {
        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['mutcd_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return MutasiInItem(
            itemId: detail['mutcd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qty: qty,
            qtyMutasi: 0,
            referensi: '',
          );
        }).toList();
        _filteredItems = List.from(_items);
        _initializeControllers();
      });

      _showToast('Berhasil load ${_items.length} item dari mutasi out', type: ToastType.success);
    } catch (e) {
      _showToast('Gagal memuat detail mutasi out: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingMutasi = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyMutasi > 0 ? item.qtyMutasi.toString() : ''
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final searchLower = query.toLowerCase();
        _filteredItems = _items.where((item) {
          return item.itemNama.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        _items[itemIndex] = _items[itemIndex].copyWith(qtyMutasi: newQty);
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qtyMutasi: newQty);
      }

      if (_qtyControllers.containsKey(itemId)) {
        _qtyControllers[itemId]?.text = newQty.toString();
      }
    });
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

  void _showSelectMutasiOutDialog() {
    if (_selectedCabangAsal == null) {
      _showToast('Pilih cabang asal terlebih dahulu!', type: ToastType.error);
      return;
    }

    _barcodeFocusNode.unfocus();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          _barcodeFocusNode.requestFocus();
          return true;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: _surfaceWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryDark, _primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.swap_horiz, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pilih No. Mutasi Out',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: _isLoadingMutasi
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color: _accentGold,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Memuat data mutasi out...',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: _textMedium,
                            ),
                          ),
                        ],
                      ),
                    )
                        : _mutasiOutList.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _bgSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.inbox_rounded, size: 32, color: _textLight),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada data mutasi out',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _mutasiOutList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final mutasi = _mutasiOutList[index];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedMutasiOut = mutasi;
                            });
                            _loadMutasiOutDetail(mutasi['mutc_nomor']);
                            _barcodeFocusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _surfaceWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _borderSoft),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _accentGoldSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.swap_horiz, size: 18, color: _accentGold),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mutasi['mutc_nomor'],
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        mutasi['mutc_keterangan'] ?? '-',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: _textMedium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _bgSoft,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _borderSoft),
                                  ),
                                  child: Text(
                                    DateFormat('dd/MM/yy').format(DateTime.parse(mutasi['mutc_tanggal'])),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: _textMedium,
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
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgSoft,
                    border: Border(top: BorderSide(color: _borderSoft)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _barcodeFocusNode.requestFocus();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _textMedium,
                          ),
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
    );
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

  Future<void> _saveMutasiIn() async {
    if (_selectedCabangAsal == null) {
      _showToast('Cabang asal harus dipilih!', type: ToastType.error);
      return;
    }

    if (_selectedMutasiOut == null) {
      _showToast('No. Mutasi Out harus dipilih!', type: ToastType.error);
      return;
    }

    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllQtyFromControllers();

    final itemsWithQty = _items.where((item) => item.qtyMutasi > 0).toList();

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
        'cbg_asal': _selectedCabangAsal!.kode,
        'cbg_tujuan': SessionManager.getCurrentCabang()?.kode,
        'mutasi_nomor': _selectedMutasiOut!['mutc_nomor'],
        'items': itemsWithQty.map((item) => {
          'item_id': item.itemId,
          'item_nama': item.itemNama,
          'qty': item.qtyMutasi,
        }).toList(),
      };

      final result = widget.mutasiInHeader == null
          ? await StokinService.createStokIn(requestData)
          : await StokinService.updateStokIn({
        'nomor': _nomorMutasiIn!,
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => ({
          'item_id': item.itemId,
          'item_nama': item.itemNama,
          'qty': item.qtyMutasi,
        })).toList(),
      });

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onMutasiInSaved();
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
    return _items.where((item) => item.qtyMutasi > 0).length;
  }

  int get _totalQuantity {
    return _items.fold(0, (sum, item) => sum + item.qtyMutasi);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mutasiInHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Mutasi In' : 'Tambah Mutasi In',
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
                        _buildCabangCard(),
                        const SizedBox(height: 12),
                        _buildMutasiCard(),
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
            if (_nomorMutasiIn != null) ...[
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
                      child: Text(
                        _nomorMutasiIn!,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primaryDark,
                        ),
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
                      height: 40,
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
                            color: _accentGold,
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
                          hintText: 'Keterangan mutasi in...',
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
          ],
        ),
      ),
    );
  }

  Widget _buildCabangCard() {
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentSkySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.business_rounded,
                color: _accentSky,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cabang Asal (Mutasi Out)',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Cabang>(
                      value: _selectedCabangAsal,
                      isExpanded: true,
                      hint: Text(
                        'Pilih Cabang Asal',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textLight,
                        ),
                      ),
                      items: _cabangList.map((cabang) {
                        return DropdownMenuItem<Cabang>(
                          value: cabang,
                          child: Text(
                            '${cabang.kode} - ${cabang.nama}',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: _textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (cabang) {
                        setState(() {
                          _selectedCabangAsal = cabang;
                          _selectedMutasiOut = null;
                          _items.clear();
                          _filteredItems.clear();
                          _mutasiOutList.clear();
                          _qtyControllers.clear();
                        });
                        _loadMutasiOutList();
                        _barcodeFocusNode.requestFocus();
                      },
                      icon: Icon(Icons.arrow_drop_down, color: _accentSky, size: 20),
                      style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMutasiCard() {
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentGoldSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.swap_horiz,
                color: _accentGold,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No. Mutasi Out',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  Text(
                    _selectedMutasiOut != null ? _selectedMutasiOut!['mutc_nomor'] : 'Belum dipilih',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedMutasiOut != null ? _accentGold : _textLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentGold, _accentGold.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: _accentGold.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _barcodeFocusNode.unfocus();
                    _showSelectMutasiOutDialog();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Pilih',
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
                if (_isLoading || _isLoadingMutasi)
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
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onChanged: _filterItems,
                            onTap: () {
                              _barcodeFocusNode.unfocus();
                            },
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
                            onChanged: _onBarcodeChanged,
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
                                onTap: () {
                                  _barcodeController.clear();
                                  _barcodeFocusNode.requestFocus();
                                },
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
                Row(
                  children: [
                    const Spacer(),
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
                          Icon(
                            Icons.shopping_cart_rounded,
                            size: 10,
                            color: _accentGold,
                          ),
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
                          Icon(
                            Icons.check_circle_rounded,
                            size: 10,
                            color: _accentMint,
                          ),
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
                if (_filteredItems.isEmpty && !_isLoading && !_isLoadingMutasi)
                  _buildEmptyState()
                else if (!_isLoading && !_isLoadingMutasi)
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
                        itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
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

  Widget _buildModernItemCard(MutasiInItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyMutasi > 0 ? item.qtyMutasi.toString() : ''
      );
    }

    final controller = _qtyControllers[item.itemId]!;
    final hasQty = item.qtyMutasi > 0;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQty ? _primaryDark.withOpacity(0.3) : _accentCoral.withOpacity(0.5),
          width: hasQty ? 1.5 : 1,
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
                color: hasQty ? _primaryDark : _accentCoralSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: hasQty ? Colors.white : _accentCoral,
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
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _accentSkySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Qty Out: ${item.qty}',
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: _accentSky,
                          ),
                        ),
                      ),
                      if (hasQty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _accentGoldSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty In: ${item.qtyMutasi}',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _accentGold,
                            ),
                          ),
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
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasQty ? _primaryDark.withOpacity(0.3) : _accentCoral.withOpacity(0.5),
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
                    color: hasQty ? _primaryDark : _accentCoral,
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
                    if (value.isEmpty) {
                      _updateItemQty(item.itemId, 0);
                    } else {
                      final intValue = int.tryParse(value);
                      if (intValue != null) {
                        if (intValue > item.qty) {
                          _showToast('Qty tidak boleh melebihi qty out (${item.qty})', type: ToastType.error);
                          controller.text = item.qtyMutasi.toString();
                          return;
                        }
                        _updateItemQty(item.itemId, intValue);
                      }
                    }
                  },
                  onTap: () {
                    _barcodeFocusNode.unfocus();
                    controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.text.length,
                    );
                  },
                ),
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
              _selectedMutasiOut == null
                  ? Icons.swap_horiz
                  : (_searchController.text.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded),
              size: 32,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedMutasiOut == null
                ? 'Pilih No. Mutasi Out terlebih dahulu'
                : (_searchController.text.isEmpty
                ? 'Tidak ada item dari mutasi out'
                : 'Item tidak ditemukan'),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedMutasiOut == null
                ? 'Klik tombol Pilih untuk memilih mutasi out'
                : (_searchController.text.isEmpty
                ? 'Scan barcode untuk mengisi qty mutasi in'
                : 'Coba kata kunci lain'),
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
                        '$_totalItemsWithQty dari ${_items.length}',
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
                  onTap: _isSaving ? null : _saveMutasiIn,
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

enum ToastType { success, error, info }