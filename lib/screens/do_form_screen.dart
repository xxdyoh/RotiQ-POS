import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

class _DoFormScreenState extends State<DoFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _bgCard = const Color(0xFFFFFFFF);
  final Color _textPrimary = const Color(0xFF1A202C);
  final Color _textSecondary = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingMinta = false;
  bool _isInfoExpanded = true;

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
    _loadCabangList();

    if (widget.doHeader != null) {
      _nomorDo = widget.doHeader!['do_nomor'];
      _selectedDate = DateTime.parse(widget.doHeader!['do_tanggal']);
      _memoController.text = widget.doHeader!['do_memo'] ?? '';
      _loadDoDetail();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _memoController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _ketControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadCabangList() async {
    try {
      final cabangList = await CabangService.getCabangList();
      setState(() {
        _cabangList = cabangList;
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data cabang: ${e.toString()}');
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
      _showErrorSnackbar('Gagal memuat detail pengiriman: ${e.toString()}');
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
      _showErrorSnackbar('Gagal memuat data permintaan: ${e.toString()}');
    } finally {
      setState(() => _isLoadingMinta = false);
    }
  }

  Future<void> _loadMintaDetail(String nomor) async {
    print(nomor);
    if (_selectedCabang == null) return;

    setState(() {
      _isLoadingMinta = true;
      _items.clear();
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
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail permintaan: ${e.toString()}');
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
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      final item = _items[itemIndex];
      // if (newQty > item.stockTersedia) {
      //   _showErrorSnackbar('Qty kirim (${newQty}) melebihi stock tersedia (${item.stockTersedia})!');
      //   return;
      // }
      _items[itemIndex] = _items[itemIndex].copyWith(qtyKirim: newQty);
    }

    final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
    if (filteredIndex != -1) {
      _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qtyKirim: newQty);
    }

    setState(() {});
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      _items[itemIndex] = _items[itemIndex].copyWith(keterangan: keterangan);
    }

    final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
    if (filteredIndex != -1) {
      _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(keterangan: keterangan);
    }

    setState(() {});
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
              primary: _accentGold,
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
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
      _showErrorSnackbar('Pilih cabang terlebih dahulu!');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 450,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryDark, _primaryLight],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment, size: 18, color: Colors.white),
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
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                      : _mintaList.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: _borderColor),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada data permintaan',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _mintaList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final minta = _mintaList[index];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedMinta = minta;
                          });
                          _loadMintaDetail(minta['mt_nomor']);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.assignment, size: 16, color: _accentGold),
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
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      minta['mt_keterangan'] ?? '-',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        color: _textSecondary,
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
                                  color: _bgLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yy').format(DateTime.parse(minta['mt_tanggal'])),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: _textSecondary,
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
                  border: Border(top: BorderSide(color: _borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: _accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: _accentMint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: _accentSky,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final intValue = int.tryParse(controller.text) ?? 0;

      final item = _items.firstWhere((item) => item.itemId == itemId);
      // if (intValue > item.stockTersedia) {
      //   _showErrorSnackbar('Qty kirim untuk item ${item.itemNama} melebihi stock tersedia (${item.stockTersedia})!');
      //   return;
      // }

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
      _showErrorSnackbar('Cabang harus dipilih!');
      return;
    }

    if (_selectedMinta == null) {
      _showErrorSnackbar('No. Permintaan harus dipilih!');
      return;
    }

    if (_memoController.text.trim().isEmpty) {
      _showErrorSnackbar('Memo harus diisi!');
      return;
    }

    _updateAllQtyFromControllers();
    _updateAllKeteranganFromControllers();

    final itemsWithQty = _items.where((item) => item.qtyKirim > 0).toList();

    if (itemsWithQty.isEmpty) {
      _showErrorSnackbar('Minimal satu item harus memiliki quantity kirim!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'mt_nomor': _selectedMinta!['mt_nomor'],
        'cabang_database': _selectedCabang!.database,
        'memo': _memoController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      final result = widget.doHeader == null
          ? await DoService.createDo(requestData)
          : await DoService.updateDo(_nomorDo!, requestData);

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        widget.onDoSaved();
        Navigator.pop(context);
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int get _totalItemsWithQty {
    return _items.where((item) => item.qtyKirim > 0).length;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Pengiriman' : 'Tambah Pengiriman',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primaryLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note : Icons.local_shipping,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Pengiriman' : 'Tambah Pengiriman Baru',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Card Informasi
                    Container(
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Expandable Header
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isInfoExpanded = !_isInfoExpanded;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _bgLight,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  border: Border(bottom: _isInfoExpanded ? BorderSide(color: _borderColor) : BorderSide.none),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _accentGold.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.local_shipping,
                                        size: 14,
                                        color: _accentGold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Informasi Pengiriman',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _isInfoExpanded ? Icons.expand_less : Icons.expand_more,
                                      size: 18,
                                      color: _textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Expanded Content
                          if (_isInfoExpanded)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (_nomorDo != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _bgLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.confirmation_number, size: 14, color: _textSecondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _nomorDo!,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // Row Tanggal dan Memo
                                  Row(
                                    children: [
                                      // Tanggal
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tanggal',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(8),
                                                onTap: () => _selectDate(context),
                                                child: Container(
                                                  height: 40,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: _bgLight,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: _borderColor),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today, size: 14, color: _accentGold),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: _textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Memo
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Memo',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: _bgLight,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _borderColor),
                                              ),
                                              child: Center(
                                                child: TextFormField(
                                                  controller: _memoController,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    color: _textPrimary,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: 'Memo pengiriman...',
                                                    hintStyle: GoogleFonts.montserrat(
                                                      fontSize: 11,
                                                      color: _textSecondary.withOpacity(0.5),
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Row Cabang dan No. Permintaan
                                  Row(
                                    children: [
                                      // Cabang
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cabang',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 40,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: _bgLight,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _borderColor),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<Cabang>(
                                                  value: _selectedCabang,
                                                  isExpanded: true,
                                                  hint: Text(
                                                    'Pilih Cabang',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 12,
                                                      color: _textSecondary.withOpacity(0.5),
                                                    ),
                                                  ),
                                                  items: _cabangList.map((cabang) {
                                                    return DropdownMenuItem<Cabang>(
                                                      value: cabang,
                                                      child: Text(
                                                        '${cabang.kode} - ${cabang.nama}',
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          color: _textPrimary,
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
                                                    });
                                                    _loadMintaList();
                                                  },
                                                  icon: Icon(Icons.arrow_drop_down, color: _textSecondary, size: 20),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // No. Permintaan
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'No. Permintaan',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    height: 40,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: _bgLight,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: _borderColor),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            _selectedMinta != null ? _selectedMinta!['mt_nomor'] : '-',
                                                            style: GoogleFonts.montserrat(
                                                              fontSize: 12,
                                                              fontWeight: _selectedMinta != null ? FontWeight.w600 : FontWeight.normal,
                                                              color: _selectedMinta != null ? _textPrimary : _textSecondary.withOpacity(0.5),
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [_accentGold, _accentGold.withOpacity(0.8)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: _accentGold.withOpacity(0.3),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ElevatedButton(
                                                    onPressed: _showSelectMintaDialog,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      foregroundColor: Colors.white,
                                                      shadowColor: Colors.transparent,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                      minimumSize: const Size(40, 40),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: const Icon(Icons.search, size: 16, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card Daftar Item
                    Container(
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header Item
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _bgLight,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: _borderColor)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _accentSky.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2,
                                        size: 14,
                                        color: _accentSky,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Daftar Item',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
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
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Search Bar
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: _bgLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.search, size: 14, color: _textSecondary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText: 'Cari item...',
                                            hintStyle: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              color: _textSecondary.withOpacity(0.5),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          style: GoogleFonts.montserrat(fontSize: 11),
                                          onChanged: _filterItems,
                                        ),
                                      ),
                                      if (_searchController.text.isNotEmpty)
                                        IconButton(
                                          icon: Icon(Icons.clear, size: 14, color: _textSecondary),
                                          onPressed: () {
                                            _searchController.clear();
                                            _filterItems('');
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Summary Item
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _bgLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.inventory, size: 12, color: _primaryDark),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_items.length} items',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _accentMint.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: _accentMint.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 10,
                                              color: _totalItemsWithQty > 0 ? _accentMint : _textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_totalItemsWithQty dengan QTY',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: _totalItemsWithQty > 0 ? _accentMint : _textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // List Items
                                if (_filteredItems.isEmpty && !_isLoading && !_isLoadingMinta)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Column(
                                      children: [
                                        Icon(
                                          _selectedMinta == null
                                              ? Icons.inbox_outlined
                                              : Icons.search_off,
                                          size: 40,
                                          color: _borderColor,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _selectedMinta == null
                                              ? 'Pilih No. Permintaan terlebih dahulu'
                                              : 'Tidak ada item',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (!_isLoading && !_isLoadingMinta)
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 400,
                                    ),
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      thickness: 6,
                                      radius: const Radius.circular(10),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: _filteredItems.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                                        itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgCard,
                border: Border(top: BorderSide(color: _borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveDo,
                  icon: _isSaving
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    isEdit ? Icons.edit : Icons.save,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isEdit ? 'UPDATE PENGIRIMAN' : 'SIMPAN PENGIRIMAN',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(DoItem item) {
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
    final isLowStock = item.stockTersedia < item.qtyMinta;

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Row Utama: Icon + Nama Item + Qty Kirim
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: _accentGold,
                  ),
                ),
                const SizedBox(width: 10),

                // Nama Item
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemNama,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${item.itemId}',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Input Qty Kirim
                Container(
                  width: 70,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _bgLight,
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.qtyKirim > 0 ? _accentGold : _textSecondary,
                      height: 1.0,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      isDense: true,
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: _textSecondary.withOpacity(0.5),
                        height: 1.0,
                      ),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 0;
                      _updateItemQty(item.itemId, intValue);
                    },
                    onTap: () {
                      qtyController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: qtyController.text.length,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row Info: Qty Minta + Stock + Keterangan
            Row(
              children: [
                // Qty Minta
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentSky.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _accentSky.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt, size: 10, color: _accentSky),
                      const SizedBox(width: 4),
                      Text(
                        'Minta: ${item.qtyMinta}',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _accentSky,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Stock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLowStock ? _accentCoral.withOpacity(0.1) : _accentMint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isLowStock ? _accentCoral.withOpacity(0.2) : _accentMint.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 10,
                        color: isLowStock ? _accentCoral : _accentMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Stock: ${item.stockTersedia}',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isLowStock ? _accentCoral : _accentMint,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Keterangan (Expanded)
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: _bgLight,
                      border: Border.all(color: _borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: ketController,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: _textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Keterangan...',
                        hintStyle: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: _textSecondary.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        isDense: true,
                      ),
                      maxLines: 1,
                      onChanged: (value) {
                        _updateItemKeterangan(item.itemId, value);
                      },
                      onTap: () {
                        ketController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: ketController.text.length,
                        );
                      },
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
}