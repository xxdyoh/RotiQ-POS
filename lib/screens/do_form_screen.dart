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
  bool _isLoadingGudang = false;
  bool _isLoadingCabang = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _nomorMutasi;
  Gudang? _selectedGudangAsal;
  Cabang? _selectedCabangTujuan;
  List<MutasiItem> _items = [];
  List<MutasiItem> _filteredItems = [];

  List<Gudang> _gudangList = [];
  List<Cabang> _cabangTujuanList = [];

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

    _loadGudangList();
    _loadCabangTujuanList();

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
        setState(() {
          final newQty = _filteredItems[i].qty + 1;
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

    if (!found) {
      _showToast('Item tidak ada dalam daftar', type: ToastType.error);
      HapticFeedback.heavyImpact();
    }

    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
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
        _cabangTujuanList = cabangData.map((c) => Cabang.fromJson(c)).toList();
      });
    } catch (e) {
      _showToast('Gagal memuat data cabang tujuan: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoadingCabang = false);
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
        _selectedCabangTujuan = _cabangTujuanList.firstWhere(
              (c) => c.kode == header['mutc_cbg_tujuan'],
          orElse: () => Cabang(kode: '', nama: '', database: '', host: '', user: '', password: '', port: '', jenis: '', aktif: 0),
        );
        _items = details.map((detail) {
          int qty = 0;
          final rawQty = detail['mutcd_qty'];
          if (rawQty is int) qty = rawQty;
          else if (rawQty is double) qty = rawQty.toInt();
          else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

          return MutasiItem(
            itemId: detail['mutcd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
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
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
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
        _items[itemIndex] = _items[itemIndex].copyWith(qty: newQty);
      }

      final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
      if (filteredIndex != -1) {
        _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qty: newQty);
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
    final selectedItems = await showModalBottomSheet<List<MutasiItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: AddItemModalMutasi(
          existingItems: _items,
        ),
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        for (var newItem in selectedItems) {
          final existingIndex = _items.indexWhere((item) => item.itemId == newItem.itemId);
          if (existingIndex >= 0) {
            _items[existingIndex].qty += newItem.qty;
          } else {
            _items.add(newItem);
          }
        }
        _filteredItems = List.from(_items);
        _initializeControllers();
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

  Future<void> _saveMutasi() async {
    if (_selectedGudangAsal == null || _selectedGudangAsal!.kode.isEmpty) {
      _showToast('Gudang asal harus dipilih!', type: ToastType.error);
      return;
    }

    if (_selectedCabangTujuan == null || _selectedCabangTujuan!.kode.isEmpty) {
      _showToast('Cabang tujuan harus dipilih!', type: ToastType.error);
      return;
    }

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
      final tanggalStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'gdg_kode': _selectedGudangAsal!.kode,
        'cbg_tujuan': _selectedCabangTujuan!.kode,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

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

    return BaseLayout(
      title: isEdit ? 'Edit Mutasi Out' : 'Tambah Mutasi Out',
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
                        _buildGudangCabangCard(),
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
            if (_nomorMutasi != null) ...[
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
                        _nomorMutasi!,
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
                                  DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate),
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
                          hintText: 'Keterangan mutasi...',
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

  Widget _buildGudangCabangCard() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentSkySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.warehouse_rounded,
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
                        'Gudang Asal',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: _textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _isLoadingGudang
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
                            'Pilih Gudang',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: _textLight,
                            ),
                          ),
                          items: _gudangList.map((gudang) {
                            return DropdownMenuItem<Gudang>(
                              value: gudang,
                              child: Text(
                                '${gudang.kode} - ${gudang.nama}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
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
                          style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentGoldSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.business_rounded,
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
                        'Cabang Tujuan',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: _textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _isLoadingCabang
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accentGold,
                        ),
                      )
                          : DropdownButtonHideUnderline(
                        child: DropdownButton<Cabang>(
                          value: _selectedCabangTujuan,
                          isExpanded: true,
                          hint: Text(
                            'Pilih Cabang Tujuan',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: _textLight,
                            ),
                          ),
                          items: _cabangTujuanList.map((cabang) {
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
                              _selectedCabangTujuan = cabang;
                            });
                          },
                          icon: Icon(Icons.arrow_drop_down, color: _accentGold, size: 20),
                          style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
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
                    _buildModernActionButton(
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
                      child: Text(
                        '${_items.length}',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentMintSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_totalQuantity',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _accentMint,
                        ),
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
                Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
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
            SizedBox(
              width: 60,
              height: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: _bgSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: hasQty ? _primaryDark.withOpacity(0.3) : _borderSoft),
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
                    controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.text.length,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  _items.removeWhere((i) => i.itemId == item.itemId);
                  _filteredItems = List.from(_items);
                  _qtyControllers[item.itemId]?.dispose();
                  _qtyControllers.remove(item.itemId);
                });
                _showToast('${item.itemNama} dihapus', type: ToastType.info);
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accentCoral.withOpacity(0.1),
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
                ? 'Tambah item dengan tombol Add atau scan barcode'
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
                  onTap: _isSaving ? null : _saveMutasi,
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

class AddItemModalMutasi extends StatefulWidget {
  final List<MutasiItem> existingItems;

  const AddItemModalMutasi({
    super.key,
    required this.existingItems,
  });

  @override
  State<AddItemModalMutasi> createState() => _AddItemModalMutasiState();
}

class _AddItemModalMutasiState extends State<AddItemModalMutasi> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final Map<int, TextEditingController> _qtyControllers = {};
  bool _isLoading = true;

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
    try {
      final items = await DoService.getItemsForMutasi();
      setState(() {
        _items = items;
        _filteredItems = items;
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
          return item['item_nama'].toString().toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _addSelectedItems() {
    final selectedItems = <MutasiItem>[];
    for (var item in _items) {
      final controller = _qtyControllers[item['item_id']];
      if (controller != null && controller.text.isNotEmpty) {
        final qty = int.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          selectedItems.add(MutasiItem(
            itemId: item['item_id'],
            itemNama: item['item_nama'],
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
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    'Tambah Item',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: GoogleFonts.montserrat(fontSize: 11),
                  onChanged: _filterItems,
                  decoration: InputDecoration(
                    hintText: 'Cari item...',
                    hintStyle: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFFA0AEC0)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF2C3E50)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    isDense: true,
                  ),
                ),
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
                  Icon(Icons.inbox, size: 48, color: const Color(0xFFA0AEC0)),
                  const SizedBox(height: 8),
                  Text(
                    'Tidak ada item',
                    style: GoogleFonts.montserrat(fontSize: 12, color: const Color(0xFF718096)),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final itemId = item['item_id'];
                final isExisting = widget.existingItems.any((i) => i.itemId == itemId);

                if (!_qtyControllers.containsKey(itemId)) {
                  _qtyControllers[itemId] = TextEditingController();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50).withOpacity(0.1),
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
                              item['item_nama'],
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A202C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isExisting)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6A918).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sudah ada di daftar',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    color: const Color(0xFFF6A918),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
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
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF718096),
                        ),
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
                          fontSize: 11,
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