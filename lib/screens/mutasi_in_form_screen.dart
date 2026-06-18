import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

class _MutasiInFormScreenState extends State<MutasiInFormScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final FocusNode _barcodeFocusNode = FocusNode();

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

    _loadCabangList().then((_) {
      if (widget.mutasiInHeader != null) {
        _nomorMutasiIn = widget.mutasiInHeader!['sti_nomor'];
        _selectedDate = DateTime.parse(widget.mutasiInHeader!['sti_tanggal']);
        _keteranganController.text = widget.mutasiInHeader!['sti_keterangan'] ?? '';
        _loadMutasiInDetail();
      }
    });

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
    for (var controller in _qtyControllers.values) { controller.dispose(); }
    super.dispose();
  }

  // ============ BARCODE ============

  void _processBarcode(String barcode) {
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
        final newQty = _filteredItems[i].qtyMutasi + 1;

        // Validasi tidak boleh melebihi qty out
        if (newQty > _filteredItems[i].qty) {
          _showToast(
              'Qty tidak boleh melebihi qty out (${_filteredItems[i].qty})',
              type: ToastType.error);
          return;
        }

        setState(() {
          _filteredItems[i] = _filteredItems[i].copyWith(qtyMutasi: newQty);
          final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
          if (itemIndex != -1) {
            _items[itemIndex] = _items[itemIndex].copyWith(qtyMutasi: newQty);
          }
          _qtyControllers[itemId]?.text = newQty.toString();
        });
        _showToast('${_filteredItems[i].itemNama} +1 (Mutasi: $newQty)',
            type: ToastType.success);
        HapticFeedback.lightImpact();
        found = true;
        break;
      }
    }

    if (!found) {
      _showToast('Item tidak ada dalam daftar mutasi out',
          type: ToastType.error);
      HapticFeedback.heavyImpact();
    }
  }

  // ============ LOAD DATA ============

  Future<void> _loadCabangList() async {
    try {
      final cabangList = await CabangService.getCabangList();
      setState(() => _cabangList = cabangList);
    } catch (e) {
      _showToast('Gagal memuat data cabang: ${e.toString()}',
          type: ToastType.error);
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
        final targetCabangKode = header['sti_cbg_Asal'] as String?;
        if (targetCabangKode != null && targetCabangKode.isNotEmpty && _cabangList.isNotEmpty) {
          _selectedCabangAsal = _cabangList.firstWhere(
                (c) => c.kode == targetCabangKode,
            orElse: () => Cabang(kode: '', nama: '', database: '', host: '', user: '', password: '', port: '', jenis: '', aktif: 0),
          );
          if (_selectedCabangAsal!.kode.isEmpty) _selectedCabangAsal = null;
        }

        _items = details.map((detail) {
          int qty = _parseInt(detail['stid_qty']);
          return MutasiInItem(
            itemId: detail['stid_item_id'],
            itemNama: detail['item_nama'] ?? '',
            tipe: detail['stid_tipe'] ?? 'BJ',
            qty: qty,
            qtyMutasi: qty,
            referensi: detail['referensi'],
          );
        }).toList();
        _filteredItems = List.from(_items);
        _initializeControllers();

        final targetMutasiNomor = header['sti_mutasi_nomor'] as String?;
        if (targetMutasiNomor != null) {
          _selectedMutasiOut = {'mutc_nomor': targetMutasiNomor};
          _loadMutasiOutListForEdit(targetMutasiNomor);
        }
      });
    } catch (e) {
      _showToast('Gagal memuat detail: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _loadMutasiOutListForEdit(String? targetMutasiNomor) async {
    if (_selectedCabangAsal == null) return;

    setState(() => _isLoadingMutasi = true);
    try {
      final currentCabang = SessionManager.getCurrentCabang();
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(2024, 1, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final mutasiData = await DoService.getMutasiOutByCabang(
        _selectedCabangAsal!.database, startDate, endDate,
      );

      final filteredData = mutasiData
          .where((m) => m['mutc_cbg_tujuan'] == currentCabang?.kode)
          .toList();

      setState(() {
        _mutasiOutList = filteredData;
        if (targetMutasiNomor != null && filteredData.isNotEmpty) {
          final match = filteredData.firstWhere(
                (m) => m['mutc_nomor'] == targetMutasiNomor,
            orElse: () => {},
          );
          if (match.isNotEmpty) _selectedMutasiOut = match;
        }
      });
    } catch (e) {
      _showToast('Gagal memuat data mutasi out: ${e.toString()}',
          type: ToastType.error);
    } finally {
      setState(() => _isLoadingMutasi = false);
    }
  }

  Future<void> _loadMutasiOutList() async {
    if (_selectedCabangAsal == null) return;

    setState(() => _isLoadingMutasi = true);
    try {
      final currentCabang = SessionManager.getCurrentCabang();
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime(2024, 1, 1));
      final endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final mutasiData = await DoService.getMutasiOutByCabang(
        _selectedCabangAsal!.database, startDate, endDate,
      );

      setState(() {
        _mutasiOutList = mutasiData
            .where((m) => m['mutc_cbg_tujuan'] == currentCabang?.kode)
            .toList();
      });
    } catch (e) {
      _showToast('Gagal memuat data mutasi out: ${e.toString()}',
          type: ToastType.error);
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
      final detail = await DoService.getMutasiOutDetailFromCabang(
        _selectedCabangAsal!.database, nomor,
      );
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _items = details.map((d) {
          int qty = _parseInt(d['mutcd_qty']);
          return MutasiInItem(
            itemId: d['mutcd_brg_kode'],
            itemNama: d['item_nama'] ?? '',
            tipe: d['mutcd_tipe'] ?? 'BJ',
            qty: qty,
            qtyMutasi: 0,
            referensi: d['mutcd_mt_nomor'],
          );
        }).toList();
        _filteredItems = List.from(_items);
        _initializeControllers();
      });

      _showToast('Berhasil load ${_items.length} item dari mutasi out',
          type: ToastType.success);
    } catch (e) {
      _showToast('Gagal memuat detail mutasi out: ${e.toString()}',
          type: ToastType.error);
    } finally {
      setState(() => _isLoadingMutasi = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyMutasi > 0 ? item.qtyMutasi.toString() : '');
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        final q = query.toLowerCase();
        _filteredItems = _items
            .where((item) => item.itemNama.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      _items[itemIndex] = _items[itemIndex].copyWith(qtyMutasi: newQty);
    }
    final fIdx = _filteredItems.indexWhere((item) => item.itemId == itemId);
    if (fIdx != -1) {
      _filteredItems[fIdx] = _filteredItems[fIdx].copyWith(qtyMutasi: newQty);
    }
    setState(() {});
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

  void _showSelectMutasiOutDialog() {
    if (_selectedCabangAsal == null) {
      _showToast('Pilih cabang asal terlebih dahulu!', type: ToastType.error);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.swap_horiz, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text('Pilih No. Mutasi Out',
                        style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
                            width: 32, height: 32,
                            child: CircularProgressIndicator(
                                color: _accentGold, strokeWidth: 2)),
                        const SizedBox(height: 12),
                        Text('Memuat data mutasi out...',
                            style: GoogleFonts.montserrat(
                                fontSize: 11, color: _textMedium)),
                      ],
                    ),
                  )
                      : _mutasiOutList.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                                color: _bgSoft, shape: BoxShape.circle),
                            child: Icon(Icons.inbox_rounded,
                                size: 32, color: _textLight)),
                        const SizedBox(height: 12),
                        Text('Tidak ada data mutasi out',
                            style: GoogleFonts.montserrat(
                                fontSize: 12, fontWeight: FontWeight.w500, color: _textDark)),
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
                          setState(() => _selectedMutasiOut = mutasi);
                          _loadMutasiOutDetail(mutasi['mutc_nomor']);
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
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                    color: _accentGoldSoft,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.swap_horiz, size: 18, color: _accentGold),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mutasi['mutc_nomor'],
                                        style: GoogleFonts.montserrat(
                                            fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                                    const SizedBox(height: 4),
                                    Text(mutasi['mutc_keterangan'] ?? '-',
                                        style: GoogleFonts.montserrat(
                                            fontSize: 10, color: _textMedium),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _bgSoft,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _borderSoft)),
                                child: Text(
                                    DateFormat('dd/MM/yy').format(DateTime.parse(mutasi['mutc_tanggal'])),
                                    style: GoogleFonts.montserrat(fontSize: 10, color: _textMedium)),
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
                      bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Tutup',
                          style: GoogleFonts.montserrat(
                              fontSize: 11, fontWeight: FontWeight.w500, color: _textMedium)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(type == ToastType.success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white))),
          ],
        ),
      ),
      backgroundColor: type == ToastType.success ? _accentMint : _accentCoral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final intValue = int.tryParse(entry.value.text) ?? 0;
      _updateItemQty(entry.key, intValue);
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
          'tipe': item.tipe,
          'qty': item.qtyMutasi,
          'mt_nomor': item.referensi,
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

  int get _totalItemsWithQty => _items.where((item) => item.qtyMutasi > 0).length;
  int get _totalQuantity => _items.fold(0, (sum, item) => sum + item.qtyMutasi);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mutasiInHeader != null;

    if (_selectedCabangAsal != null && _cabangList.isNotEmpty) {
      final exists = _cabangList.any((c) => c.kode == _selectedCabangAsal!.kode);
      if (!exists) _selectedCabangAsal = null;
    }

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
                        _buildFormCard(),
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

  Widget _buildFormCard() {
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
            if (_nomorMutasiIn != null) ...[
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
                    Text(_nomorMutasiIn!, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _primaryDark)),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildCabangDropdown()),
                const SizedBox(width: 10),
                Expanded(child: _buildMutasiOutSelector()),
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
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: _accentGold, size: 16),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textMedium)),
                Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeteranganField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
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
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabangDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
      child: Row(
        children: [
          Icon(Icons.business_rounded, color: _accentSky, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Cabang>(
                value: _selectedCabangAsal,
                isExpanded: true,
                hint: Text('Cabang Asal', style: GoogleFonts.montserrat(fontSize: 12, color: _textLight)),
                items: _cabangList.map<DropdownMenuItem<Cabang>>((cabang) {
                  return DropdownMenuItem<Cabang>(
                    value: cabang,
                    child: Text('${cabang.kode} - ${cabang.nama}',
                        style: GoogleFonts.montserrat(fontSize: 12, color: _textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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
                },
                icon: Icon(Icons.arrow_drop_down, color: _accentSky, size: 20),
                style: GoogleFonts.montserrat(fontSize: 12, color: _textDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutasiOutSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: _accentGold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No. Mutasi Out', style: GoogleFonts.montserrat(fontSize: 9, color: _textMedium)),
                Text(
                  _selectedMutasiOut != null ? _selectedMutasiOut!['mutc_nomor'] : 'Belum dipilih',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _selectedMutasiOut != null ? _accentGold : _textLight),
                ),
              ],
            ),
          ),
          Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentGold, _accentGold.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showSelectMutasiOutDialog,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Pilih', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.inventory_2_rounded, color: _primaryDark, size: 14),
                ),
                const SizedBox(width: 8),
                Text('Daftar Item', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                const SizedBox(height: 12),
                if (_filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _buildModernItemCard(_filteredItems[index]),
                  ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: _bgSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentMint, width: 1.5),
      ),
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
              Future.delayed(const Duration(milliseconds: 100), () {
                _barcodeFocusNode.requestFocus();
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Scan barcode...',
            hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
            prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: _accentMint, size: 14),
            suffixIcon: _barcodeController.text.isNotEmpty
                ? GestureDetector(
                onTap: () {
                  _barcodeController.clear();
                  _barcodeFocusNode.requestFocus();
                },
                child: Icon(Icons.close_rounded, color: _textLight, size: 12))
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
      decoration: BoxDecoration(
          color: (color ?? _primaryDark).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color ?? _primaryDark),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color ?? _primaryDark)),
        ],
      ),
    );
  }

  Widget _buildModernItemCard(MutasiInItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyMutasi > 0 ? item.qtyMutasi.toString() : '');
    }

    final controller = _qtyControllers[item.itemId]!;
    final hasQty = item.qtyMutasi > 0;
    final overLimit = item.qtyMutasi > item.qty;

    return Container(
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overLimit ? _accentCoral : (hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft),
          width: (hasQty || overLimit) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: hasQty ? _primaryDark : _bgSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(item.tipeIcon, color: hasQty ? Colors.white : _textLight, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.itemNama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _badge('ID: ${item.itemId}'),
                    _badge(item.tipeLabel, color: item.tipeColor),
                    _badge('Qty Out: ${item.qty}', color: _accentSky),
                    if (hasQty) _badge('Qty In: ${item.qtyMutasi}', color: _accentGold),
                    if (overLimit) _badge('Melebihi!', color: _accentCoral),
                  ]),
                ],
              ),
            ),
            SizedBox(
              width: 70, height: 38,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600,
                    color: overLimit ? _accentCoral : (hasQty ? _primaryDark : _textLight)),
                decoration: InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _borderSoft)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  isDense: true,
                ),
                onChanged: (value) {
                  final intValue = int.tryParse(value) ?? 0;
                  if (intValue > item.qty) {
                    _showToast('Qty tidak boleh melebihi qty out (${item.qty})', type: ToastType.error);
                    controller.text = item.qtyMutasi.toString();
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                    return;
                  }
                  _updateItemQty(item.itemId, intValue);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? _primaryDark).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (color ?? _primaryDark).withOpacity(0.3)),
      ),
      child: Text(text, style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: color ?? _primaryDark)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
            child: Icon(
                _selectedMutasiOut == null
                    ? Icons.swap_horiz
                    : (_searchController.text.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded),
                size: 40, color: _textLight),
          ),
          const SizedBox(height: 12),
          Text(
              _selectedMutasiOut == null
                  ? 'Pilih No. Mutasi Out terlebih dahulu'
                  : (_searchController.text.isEmpty ? 'Tidak ada item dari mutasi out' : 'Item tidak ditemukan'),
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: _textDark)),
          const SizedBox(height: 4),
          Text(
              _selectedMutasiOut == null
                  ? 'Klik tombol Pilih untuk memilih mutasi out'
                  : (_searchController.text.isEmpty ? 'Scan barcode untuk mengisi qty mutasi in' : 'Coba kata kunci lain'),
              style: GoogleFonts.montserrat(fontSize: 11, color: _textLight)),
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
                      Text('$_totalItemsWithQty dari ${_items.length}',
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 120, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _saveMutasiIn,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isEdit ? Icons.edit_rounded : Icons.save_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(isEdit ? 'Update' : 'Simpan',
                            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
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