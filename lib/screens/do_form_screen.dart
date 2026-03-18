import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/do_service.dart';
import '../services/cabang_service.dart';
import '../models/cabang_model.dart';
import '../models/do_model.dart';
import '../widgets/base_layout.dart';

class DoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? doHeader;
  final VoidCallback onDoSaved;

  const DoFormScreen({
    super.key,
    this.doHeader,
    required this.onDoSaved,
  });

  @override
  State<DoFormScreen> createState() => _DoFormScreenState();
}

class _DoFormScreenState extends State<DoFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};
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
  bool _isLoadingMinta = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorDo;
  Cabang? _selectedCabang;
  Map<String, dynamic>? _selectedMinta;
  List<DoItem> _items = [];
  List<DoItem> _filteredItems = [];

  List<Cabang> _cabangList = [];
  List<Map<String, dynamic>> _mintaList = [];

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

    if (widget.doHeader != null) {
      _nomorDo = widget.doHeader!['do_nomor'];
      _selectedDate = DateTime.parse(widget.doHeader!['do_tanggal']);
      _memoController.text = widget.doHeader!['do_memo'] ?? '';
      _loadDoDetail();
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
    _memoController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _ketControllers.values.forEach((controller) => controller.dispose());
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
        setState(() {
          final newQty = _filteredItems[i].qtyKirim + 1;

          _filteredItems[i] = _filteredItems[i].copyWith(qtyKirim: newQty);

          final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
          if (itemIndex != -1) {
            _items[itemIndex] = _items[itemIndex].copyWith(qtyKirim: newQty);
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

    if (!found) {
      _showToast('Item tidak ada dalam daftar', type: ToastType.error);
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

  Future<void> _loadDoDetail() async {
    if (_nomorDo == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await DoService.getDoDetail(_nomorDo!);
      final header = detail['header'];
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedMinta = {
          'mt_nomor': header['do_mt_nomor'],
        };

        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['dod_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return DoItem(
            itemId: detail['dod_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qtyMinta: 0,
            qtyKirim: qty,
            keterangan: detail['dod_keterangan'] ?? '',
            nourut: detail['dod_nourut'],
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

  Future<void> _loadMintaList() async {
    if (_selectedCabang == null) return;

    setState(() => _isLoadingMinta = true);

    try {
      final mintaData = await DoService.getMintaListByCabang(
        cabangDatabase: _selectedCabang!.database,
        startDate: DateFormat('yyyy-MM-dd').format(DateTime(2020, 1, 1)),
        endDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      setState(() {
        _mintaList = mintaData;
      });
    } catch (e) {
      _showToast('Gagal memuat data permintaan: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingMinta = false);
    }
  }

  Future<void> _loadMintaDetail(String nomor) async {
    if (_selectedCabang == null) return;

    setState(() {
      _isLoadingMinta = true;
      _items.clear();
      _qtyControllers.clear();
      _ketControllers.clear();
    });

    try {
      final mintaDetail = await DoService.getMintaDetailFromCabang(
        cabangDatabase: _selectedCabang!.database,
        nomor: nomor,
      );

      final details = List<Map<String, dynamic>>.from(mintaDetail['details']);

      setState(() {
        _items = details.map((detail) {
          int qtyMinta = 0;
          int stock = 0;

          final rawQty = detail['mtd_qty'];
          if (rawQty is int) qtyMinta = rawQty;
          else if (rawQty is double) qtyMinta = rawQty.toInt();
          else if (rawQty is String) qtyMinta = int.tryParse(rawQty) ?? 0;

          final rawStock = detail['stock_tersedia'];
          if (rawStock is int) stock = rawStock;
          else if (rawStock is double) stock = rawStock.toInt();
          else if (rawStock is String) stock = int.tryParse(rawStock) ?? 0;

          return DoItem(
            itemId: detail['mtd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qtyMinta: qtyMinta,
            qtyKirim: 0,
            keterangan: '',
            stockTersedia: stock,
          );
        }).toList();

        _filteredItems = List.from(_items);
        _initializeControllers();
      });

      _showToast('Berhasil load ${_items.length} item dari permintaan', type: ToastType.success);
    } catch (e) {
      _showToast('Gagal memuat detail permintaan: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingMinta = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyKirim > 0 ? item.qtyKirim.toString() : ''
      );
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
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
        _items[itemIndex] = _items[itemIndex].copyWith(qtyKirim: newQty);
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qtyKirim: newQty);
      }

      if (_qtyControllers.containsKey(itemId)) {
        _qtyControllers[itemId]?.text = newQty.toString();
      }
    });
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    setState(() {
      final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        _items[itemIndex] = _items[itemIndex].copyWith(keterangan: keterangan);
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(keterangan: keterangan);
      }

      if (_ketControllers.containsKey(itemId)) {
        _ketControllers[itemId]?.text = keterangan;
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

  void _showSelectMintaDialog() {
    if (_selectedCabang == null) {
      _showToast('Pilih cabang terlebih dahulu!', type: ToastType.error);
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
                        child: Icon(Icons.assignment_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pilih No. Permintaan',
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
                    child: _isLoadingMinta
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
                            'Memuat data permintaan...',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: _textMedium,
                            ),
                          ),
                        ],
                      ),
                    )
                        : _mintaList.isEmpty
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
                            'Tidak ada data permintaan',
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
                      itemCount: _mintaList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final minta = _mintaList[index];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedMinta = minta;
                            });
                            _loadMintaDetail(minta['mt_nomor']);
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
                                  child: Icon(Icons.assignment_rounded, size: 18, color: _accentGold),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        minta['mt_nomor'],
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        minta['mt_keterangan'] ?? '-',
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
                                    DateFormat('dd/MM/yy').format(DateTime.parse(minta['mt_tanggal'])),
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

  void _updateAllKeteranganFromControllers() {
    for (var entry in _ketControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      _updateItemKeterangan(itemId, controller.text);
    }
  }

  Future<void> _saveDo() async {
    if (_selectedCabang == null) {
      _showToast('Cabang harus dipilih!', type: ToastType.error);
      return;
    }

    if (_selectedMinta == null) {
      _showToast('No. Permintaan harus dipilih!', type: ToastType.error);
      return;
    }

    if (_memoController.text.trim().isEmpty) {
      _showToast('Memo harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllQtyFromControllers();
    _updateAllKeteranganFromControllers();

    final itemsWithQty = _items.where((item) => item.qtyKirim > 0).toList();

    if (itemsWithQty.isEmpty) {
      _showToast('Minimal satu item harus memiliki quantity kirim!', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'mt_nomor': _selectedMinta!['mt_nomor'],
        'cabang_database': _selectedCabang!.database,
        'memo': _memoController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
        'kode_cabang': _selectedCabang!.kode,
      };

      final result = widget.doHeader == null
          ? await DoService.createDo(requestData)
          : await DoService.updateDo(_nomorDo!, requestData);

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onDoSaved();
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
    return _items.where((item) => item.qtyKirim > 0).length;
  }

  int get _totalQuantity {
    return _items.fold(0, (sum, item) => sum + item.qtyKirim);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Pengiriman' : 'Tambah Pengiriman',
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
                        _buildMintaCard(),
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
            if (_nomorDo != null) ...[
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
                        _nomorDo!,
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
                        controller: _memoController,
                        textAlignVertical: TextAlignVertical.center,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Memo pengiriman...',
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
                    'Cabang Tujuan',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Cabang>(
                      value: _selectedCabang,
                      isExpanded: true,
                      hint: Text(
                        'Pilih Cabang',
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
                          _selectedCabang = cabang;
                          _selectedMinta = null;
                          _items.clear();
                          _filteredItems.clear();
                          _mintaList.clear();
                          _qtyControllers.clear();
                          _ketControllers.clear();
                        });
                        _loadMintaList();
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

  Widget _buildMintaCard() {
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
                Icons.assignment_rounded,
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
                    'No. Permintaan',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: _textLight,
                    ),
                  ),
                  Text(
                    _selectedMinta != null ? _selectedMinta!['mt_nomor'] : 'Belum dipilih',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedMinta != null ? _accentGold : _textLight,
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
                    _showSelectMintaDialog();
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
                if (_isLoading || _isLoadingMinta)
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
                if (_filteredItems.isEmpty && !_isLoading && !_isLoadingMinta)
                  _buildEmptyState()
                else if (!_isLoading && !_isLoadingMinta)
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

  Widget _buildModernItemCard(DoItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyKirim > 0 ? item.qtyKirim.toString() : ''
      );
    }
    if (!_ketControllers.containsKey(item.itemId)) {
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
      );
    }

    final qtyController = _qtyControllers[item.itemId]!;
    final ketController = _ketControllers[item.itemId]!;
    final hasQty = item.qtyKirim > 0;
    final isLowStock = item.stockTersedia < item.qtyMinta;

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
        child: Column(
          children: [
            Row(
              children: [
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
                              'Minta: ${item.qtyMinta}',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: _accentSky,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isLowStock ? _accentCoralSoft : _accentMintSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Stock: ${item.stockTersedia}',
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: isLowStock ? _accentCoral : _accentMint,
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
                                'Kirim: ${item.qtyKirim}',
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
                    controller: qtyController,
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
                      if (value.isEmpty) {
                        _updateItemQty(item.itemId, 0);
                      } else {
                        final intValue = int.tryParse(value);
                        if (intValue != null) {
                          _updateItemQty(item.itemId, intValue);
                        }
                      }
                    },
                    onTap: () {
                      _barcodeFocusNode.unfocus();
                      qtyController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: qtyController.text.length,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _borderSoft),
              ),
              child: TextField(
                controller: ketController,
                style: GoogleFonts.montserrat(fontSize: 10, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Keterangan item (opsional)',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: _textLight,
                  ),
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                    color: _textLight,
                    size: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                onTap: () {
                  _barcodeFocusNode.unfocus();
                },
                onChanged: (value) {
                  _updateItemKeterangan(item.itemId, value);
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
              _selectedMinta == null
                  ? Icons.assignment_rounded
                  : (_searchController.text.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded),
              size: 32,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedMinta == null
                ? 'Pilih No. Permintaan terlebih dahulu'
                : (_searchController.text.isEmpty
                ? 'Tidak ada item dari permintaan'
                : 'Item tidak ditemukan'),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedMinta == null
                ? 'Klik tombol Pilih untuk memilih permintaan'
                : (_searchController.text.isEmpty
                ? 'Item akan muncul setelah permintaan dipilih'
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
                  onTap: _isSaving ? null : _saveDo,
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