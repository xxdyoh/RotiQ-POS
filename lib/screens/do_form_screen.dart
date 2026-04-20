import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/do_service.dart';
import '../services/cabang_service.dart';
import '../services/session_manager.dart';
import '../models/cabang_model.dart';
import '../models/do_model.dart';
import '../widgets/base_layout.dart';

class DoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? mutasiHeader;
  final VoidCallback onMutasiSaved;

  const DoFormScreen({
    super.key,
    this.mutasiHeader,
    required this.onMutasiSaved,
  });

  @override
  State<DoFormScreen> createState() => _DoFormScreenState();
}

class _DoFormScreenState extends State<DoFormScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

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
  bool _isLoadingGudang = false;
  bool _isLoadingCabang = false;
  bool _isLoadingMinta = false;
  bool _scannerActive = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorMutasi;
  Gudang? _selectedGudangAsal;
  Map<String, dynamic>? _selectedCabangTujuan;
  Map<String, dynamic>? _selectedMinta;
  List<MutasiItem> _items = [];
  List<MutasiItem> _filteredItems = [];

  List<Gudang> _gudangList = [];
  List<Map<String, dynamic>> _cabangTujuanList = [];
  List<Map<String, dynamic>> _mintaList = [];

  String _barcodeBuffer = '';
  Timer? _barcodeTimer;

  bool get isPusat {
    final currentCabang = SessionManager.getCurrentCabang();
    return currentCabang?.kode == '00' || currentCabang?.jenis.toLowerCase() == 'pusat';
  }

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

    _loadGudangList();
    _loadCabangTujuanList().then((_) {
      // Setelah cabang tujuan list selesai dimuat, baru load detail mutasi
      if (widget.mutasiHeader != null) {
        _nomorMutasi = widget.mutasiHeader!['mutc_nomor'];
        _selectedDate = DateTime.parse(widget.mutasiHeader!['mutc_tanggal']);
        _keteranganController.text = widget.mutasiHeader!['mutc_keterangan'] ?? '';
        _loadMutasiDetail();
      }
    });

    if (isPusat) {
      _loadMintaList();
    }

    if (widget.mutasiHeader != null) {
      _nomorMutasi = widget.mutasiHeader!['mutc_nomor'];
      _selectedDate = DateTime.parse(widget.mutasiHeader!['mutc_tanggal']);
      _keteranganController.text = widget.mutasiHeader!['mutc_keterangan'] ?? '';
      _loadMutasiDetail();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeDebounce?.cancel();
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
    for (var controller in _ketControllers.values) {
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

    bool found = false;
    for (int i = 0; i < _filteredItems.length; i++) {
      if (_filteredItems[i].itemId == itemId) {
        final currentQty = _filteredItems[i].qty;
        final newQty = currentQty + 1;
        setState(() {
          _filteredItems[i] = _filteredItems[i].copyWith(qty: newQty);
          final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
          if (itemIndex != -1) {
            _items[itemIndex] = _items[itemIndex].copyWith(qty: newQty);
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

    if (!found && !isPusat) {
      setState(() => _isLoading = true);
      try {
        final items = await DoService.getItemsForMutasi();
        Map<String, dynamic>? itemData;

        for (var item in items) {
          if (item['item_id'] == itemId) {
            itemData = item;
            break;
          }
        }

        if (itemData != null) {
          final newItem = MutasiItem(
            itemId: itemId,
            itemNama: itemData['item_nama']?.toString() ?? '',
            tipe: 'BJ', // <-- TAMBAHKAN, default BJ karena dari titem
            qty: 1,
          );

          setState(() {
            _items.add(newItem);
            _filteredItems = List.from(_items);
            _qtyControllers[itemId] = TextEditingController(text: '1');
            _ketControllers[itemId] = TextEditingController();
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
    } else if (!found && isPusat) {
      _showToast('Item tidak ada dalam daftar permintaan', type: ToastType.error);
      HapticFeedback.heavyImpact();
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

  Future<void> _loadGudangList() async {
    setState(() => _isLoadingGudang = true);
    try {
      final gudangData = await DoService.getGudangList();
      setState(() {
        _gudangList = gudangData.map((g) => Gudang.fromJson(g)).toList();
      });
    } catch (e) {
      _showToast('Gagal memuat data gudang: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingGudang = false);
    }
  }

  Future<void> _loadCabangTujuanList() async {
    final currentCabang = SessionManager.getCurrentCabang();
    if (currentCabang == null) return;

    setState(() => _isLoadingCabang = true);
    try {
      final cabangData = await DoService.getCabangTujuanList(currentCabang.kode);
      setState(() {
        _cabangTujuanList = cabangData;
        print('Cabang tujuan list loaded: $_cabangTujuanList'); // Debug
      });
    } catch (e) {
      _showToast('Gagal memuat data cabang tujuan: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingCabang = false);
    }
  }

  Future<void> _loadMintaList() async {
    if (_selectedCabangTujuan == null) return;

    setState(() => _isLoadingMinta = true);
    try {
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(2024, 1, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final mintaData = await DoService.getMintaListByCabang(
        cabangDatabase: _selectedCabangTujuan!['cbg_database'],
        startDate: startDate,
        endDate: endDate,
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
    if (_selectedCabangTujuan == null) return;

    setState(() {
      _isLoadingMinta = true;
      _items.clear();
      _filteredItems.clear();
      _qtyControllers.clear();
      _ketControllers.clear();
    });

    try {
      final mintaDetail = await DoService.getMintaDetailFromCabang(
        cabangDatabase: _selectedCabangTujuan!['cbg_database'],
        nomor: nomor,
      );

      final details = List<Map<String, dynamic>>.from(mintaDetail['details']);

      setState(() {
        _items = details.map((detail) {
          int qtyMinta = 0;
          final rawQty = detail['mtd_qty'];
          if (rawQty is int) qtyMinta = rawQty;
          else if (rawQty is double) qtyMinta = rawQty.toInt();
          else if (rawQty is String) qtyMinta = int.tryParse(rawQty) ?? 0;

          return MutasiItem(
            itemId: detail['mtd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            tipe: detail['mtd_tipe'] ?? 'BJ', // <-- TAMBAHKAN
            qtyMinta: qtyMinta,
            qty: 0,
            keterangan: '',
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

  Future<void> _loadMutasiDetail() async {
    if (_nomorMutasi == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await DoService.getMutasiDetail(_nomorMutasi!);
      final header = detail['header'];
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedGudangAsal = _gudangList.firstWhere(
              (g) => g.kode == header['mutc_gdg_kode'],
          orElse: () => Gudang(kode: '', nama: ''),
        );

        final targetCabangKode = header['mutc_cbg_tujuan'] as String?;

        if (targetCabangKode != null && _cabangTujuanList.isNotEmpty) {
          final matchingCabang = _cabangTujuanList.cast<Map<String, dynamic>>().firstWhere(
                (c) => c['cbg_kode'] == targetCabangKode,
            orElse: () => {},
          );
          _selectedCabangTujuan = matchingCabang.isNotEmpty ? matchingCabang : null;
        } else {
          _selectedCabangTujuan = null;
        }

        if (isPusat && header['mutc_mt_nomor'] != null) {
          _selectedMinta = {'mt_nomor': header['mutc_mt_nomor']};
        }

        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['mutcd_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return MutasiItem(
            itemId: detail['mutcd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            tipe: detail['mutcd_tipe'] ?? 'BJ', // <-- TAMBAHKAN TIPE
            qty: qty,
            keterangan: detail['mutcd_keterangan'] ?? '',
            nourut: detail['mutcd_nourut'],
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
      if (!_ketControllers.containsKey(item.itemId)) {
        _ketControllers[item.itemId] = TextEditingController(
            text: item.keterangan ?? ''
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
          return item.itemNama.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    setState(() {
      final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        _items[itemIndex] = _items[itemIndex].copyWith(qty: newQty);
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qty: newQty);
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
    if (_selectedCabangTujuan == null) {
      _showToast('Pilih cabang tujuan terlebih dahulu!', type: ToastType.error);
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

  void _showAddItemModal() async {
    HapticFeedback.selectionClick();

    final isPusat = SessionManager.getCurrentCabang()?.kode == '00' ||
        SessionManager.getCurrentCabang()?.jenis.toLowerCase() == 'pusat';

    final selectedItems = await showModalBottomSheet<List<MutasiItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: AddItemModalMutasi(
          existingItems: _items, // <-- GANTI _selectedItems menjadi _items
          isPusat: isPusat,
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        for (var newItem in selectedItems) {
          final existingIndex = _items.indexWhere((item) => item.itemId == newItem.itemId && item.tipe == newItem.tipe);
          if (existingIndex >= 0) {
            final newQty = _items[existingIndex].qty + newItem.qty;
            _items[existingIndex] = _items[existingIndex].copyWith(qty: newQty);
            if (_qtyControllers.containsKey(newItem.itemId)) {
              _qtyControllers[newItem.itemId]?.text = newQty.toString();
            }
          } else {
            _items.add(newItem);
            _qtyControllers[newItem.itemId] = TextEditingController(text: newItem.qty.toString());
            _ketControllers[newItem.itemId] = TextEditingController();
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

  void _updateAllKeteranganFromControllers() {
    for (var entry in _ketControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      _updateItemKeterangan(itemId, controller.text);
    }
  }

  Future<void> _saveMutasi() async {
    if (_selectedGudangAsal == null || _selectedGudangAsal!.kode.isEmpty) {
      _showToast('Gudang asal harus dipilih!', type: ToastType.error);
      return;
    }

    if (_selectedCabangTujuan == null || _selectedCabangTujuan!.isEmpty) {
      _showToast('Cabang tujuan harus dipilih!', type: ToastType.error);
      return;
    }

    if (_keteranganController.text.trim().isEmpty) {
      _showToast('Keterangan harus diisi!', type: ToastType.error);
      return;
    }

    _updateAllQtyFromControllers();
    _updateAllKeteranganFromControllers();

    final itemsWithQty = _items.where((item) => item.qty > 0).toList();

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
        'gdg_kode': _selectedGudangAsal!.kode,
        'cbg_tujuan': _selectedCabangTujuan!['cbg_kode'],
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      if (isPusat && _selectedMinta != null) {
        requestData['mt_nomor'] = _selectedMinta!['mt_nomor'];
        requestData['cabang_database'] = _selectedCabangTujuan!['cbg_database'];
      }

      final result = widget.mutasiHeader == null
          ? await DoService.createMutasi(requestData)
          : await DoService.updateMutasi(_nomorMutasi!, requestData);

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        widget.onMutasiSaved();
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
    final isEdit = widget.mutasiHeader != null;
    print('DoFormScreen build - isEdit: $isEdit, mutasiHeader: ${widget.mutasiHeader}');

    if (_selectedCabangTujuan != null && _cabangTujuanList.isNotEmpty) {
      final exists = _cabangTujuanList.any((c) => c['cbg_kode'] == _selectedCabangTujuan!['cbg_kode']);
      if (!exists) {
        _selectedCabangTujuan = null;
      }
    }

    return BaseLayout(
      title: isEdit ? 'Edit Mutasi Out' : 'Tambah Mutasi Out',
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
                _buildModernBottomBar(isEdit),
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
            if (_nomorMutasi != null) ...[
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
                      _nomorMutasi!,
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
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
                        Icon(Icons.warehouse_rounded, color: _accentSky, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isLoadingGudang
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _accentGold,
                            ),
                          )
                              : DropdownButtonHideUnderline(
                            child: DropdownButton<Gudang>(
                              value: _selectedGudangAsal,
                              isExpanded: true,
                              hint: Text(
                                'Gudang Asal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: _textLight,
                                ),
                              ),
                              items: _gudangList.map((gudang) {
                                return DropdownMenuItem<Gudang>(
                                  value: gudang,
                                  child: Text(
                                    '${gudang.kode} - ${gudang.nama}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: _textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (gudang) {
                                setState(() {
                                  _selectedGudangAsal = gudang;
                                });
                              },
                              icon: Icon(Icons.arrow_drop_down, color: _accentSky, size: 20),
                              style: GoogleFonts.montserrat(fontSize: 12, color: _textDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                        Icon(Icons.business_rounded, color: _accentGold, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isLoadingCabang
                              ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _accentGold,
                            ),
                          )
                              : DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedCabangTujuan,
                              isExpanded: true,
                              hint: Text(
                                'Cabang Tujuan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: _textLight,
                                ),
                              ),
                              items: _cabangTujuanList.map<DropdownMenuItem<Map<String, dynamic>>>((cabang) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: cabang,
                                  child: Text(
                                    '${cabang['cbg_kode']} - ${cabang['cbg_nama']}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: _textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (cabang) {
                                setState(() {
                                  _selectedCabangTujuan = cabang;
                                  _selectedMinta = null;
                                  _items.clear();
                                  _filteredItems.clear();
                                  _mintaList.clear();
                                  _qtyControllers.clear();
                                  _ketControllers.clear();
                                });
                                if (isPusat) {
                                  _loadMintaList();
                                }
                              },
                              icon: Icon(Icons.arrow_drop_down, color: _accentGold, size: 20),
                              style: GoogleFonts.montserrat(fontSize: 12, color: _textDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isPusat) ...[
              const SizedBox(height: 10),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderSoft),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment_rounded, color: _accentGold, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No. Permintaan',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              color: _textMedium,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Pilih',
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
            ],
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
                                  hintText: 'Scan barcode (opsional)...',
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
                    // if (!isPusat)
                      _buildModernActionButton(
                        label: 'Add Item',
                        icon: Icons.add_rounded,
                        color: _accentSky,
                        onPressed: _showAddItemModal, // <-- TETAP BISA, TAPI MODAL HANYA TAMPILKAN STJ
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

  Widget _buildModernActionButton({
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

  Widget _buildModernItemCard(MutasiItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }
    if (!_ketControllers.containsKey(item.itemId)) {
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
      );
    }

    final qtyController = _qtyControllers[item.itemId]!;
    final ketController = _ketControllers[item.itemId]!;
    final hasQty = item.qty > 0;
    final hasMinta = item.qtyMinta > 0;
    final selisih = item.qty - item.qtyMinta;

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
        child: Column(
          children: [
            Row(
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
                      item.tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined,
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
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
                          // Tipe badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.tipeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: item.tipeColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              item.tipeLabel,
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: item.tipeColor,
                              ),
                            ),
                          ),
                          if (hasMinta)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accentSkySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Minta: ${item.qtyMinta}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _accentSky,
                                ),
                              ),
                            ),
                          if (hasQty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accentGoldSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Kirim: ${item.qty}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _accentGold,
                                ),
                              ),
                            ),
                          if (hasMinta && selisih != 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: selisih > 0 ? _accentCoralSoft : _accentMintSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Selisih: ${selisih > 0 ? '+' : ''}$selisih',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: selisih > 0 ? _accentCoral : _accentMint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 70,
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
            const SizedBox(height: 8),
            TextField(
              controller: ketController,
              style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Keterangan item (opsional)',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _textLight,
                ),
                prefixIcon: Icon(
                  Icons.notes_rounded,
                  color: _textLight,
                  size: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _borderSoft),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) {
                _updateItemKeterangan(item.itemId, value);
              },
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
              isPusat && _selectedMinta == null
                  ? Icons.assignment_rounded
                  : (_searchController.text.isEmpty
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded),
              size: 40,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPusat && _selectedMinta == null
                ? 'Pilih No. Permintaan terlebih dahulu'
                : (_searchController.text.isEmpty
                ? 'Belum ada item'
                : 'Item tidak ditemukan'),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPusat && _selectedMinta == null
                ? 'Klik tombol Pilih untuk memilih permintaan'
                : (_searchController.text.isEmpty
                ? 'Tambah item dengan tombol Add atau scan barcode'
                : 'Coba kata kunci lain'),
            style: GoogleFonts.montserrat(
              fontSize: 11,
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
                  onTap: _isSaving ? null : _saveMutasi,
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

class AddItemModalMutasi extends StatefulWidget {
  final List<MutasiItem> existingItems;
  final bool isPusat; // <-- TAMBAHKAN

  const AddItemModalMutasi({
    super.key,
    required this.existingItems,
    required this.isPusat, // <-- TAMBAHKAN
  });

  @override
  State<AddItemModalMutasi> createState() => _AddItemModalMutasiState();
}

class _AddItemModalMutasiState extends State<AddItemModalMutasi> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Map<String, TextEditingController> _qtyControllers = {}; // Key: "id_tipe"
  bool _isLoading = true;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentSky = const Color(0xFF4CC9F0);
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
      final items = await DoService.getItemsForMutasi();
      setState(() {
        _items = items.map((item) {
          return {
            'id': item['id'] ?? 0,
            'nama': item['nama']?.toString() ?? 'Unknown Item',
            'tipe': item['tipe']?.toString() ?? 'BJ',
          };
        }).toList();

        // JIKA PUSAT, HANYA TAMPILKAN ITEM SETENGAH JADI (STJ)
        if (widget.isPusat) {
          _items = _items.where((item) => item['tipe'] == 'STJ').toList();
        }

        _filteredItems = List.from(_items);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading items: $e');
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
          final itemNama = item['nama']?.toString() ?? '';
          return itemNama.toLowerCase().contains(searchLower) ||
              item['id'].toString().contains(searchLower);
        }).toList();
      }
    });
  }

  String _getControllerKey(int id, String tipe) {
    return '${id}_$tipe';
  }

  void _addSelectedItems() {
    final selectedItems = <MutasiItem>[];
    for (var item in _filteredItems) {
      final id = item['id'] as int;
      final tipe = item['tipe'] as String;
      final key = _getControllerKey(id, tipe);
      final controller = _qtyControllers[key];
      if (controller != null && controller.text.isNotEmpty) {
        final qty = int.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          selectedItems.add(MutasiItem(
            itemId: id,
            itemNama: item['nama']?.toString() ?? 'Unknown Item',
            tipe: tipe,
            qty: qty,
            keterangan: '',
          ));
        }
      }
    }
    Navigator.pop(context, selectedItems);
  }

  Color _getTipeColor(String tipe) {
    return tipe == 'BJ' ? _accentSky : _accentMint;
  }

  String _getTipeLabel(String tipe) {
    return tipe == 'BJ' ? 'Barang Jadi' : 'Setengah Jadi';
  }

  IconData _getTipeIcon(String tipe) {
    return tipe == 'BJ' ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined;
  }

  @override
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Item',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.isPusat) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Hanya item Setengah Jadi (STJ)',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
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
                final itemId = item['id'] as int;
                final tipe = item['tipe'] as String;
                final key = _getControllerKey(itemId, tipe);
                final isExisting = widget.existingItems.any((i) => i.itemId == itemId && i.tipe == tipe);
                final tipeColor = _getTipeColor(tipe);

                if (!_qtyControllers.containsKey(key)) {
                  _qtyControllers[key] = TextEditingController();
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
                          color: tipeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getTipeIcon(tipe), size: 18, color: tipeColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nama']?.toString() ?? 'Unknown Item',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 4,
                              children: [
                                Text(
                                  'ID: $itemId',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    color: _textLight,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: tipeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getTipeLabel(tipe),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: tipeColor,
                                    ),
                                  ),
                                ),
                              ],
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
                          controller: _qtyControllers[key],
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