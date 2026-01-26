import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/stokstjin_service.dart';
import '../models/stokstjin_model.dart';
import '../widgets/base_layout.dart';

class StokStjinFormScreen extends StatefulWidget {
  final Map<String, dynamic>? stokStjinHeader;
  final VoidCallback onStokStjinSaved;

  const StokStjinFormScreen({
    super.key,
    this.stokStjinHeader,
    required this.onStokStjinSaved,
  });

  @override
  State<StokStjinFormScreen> createState() => _StokStjinFormScreenState();
}

class _StokStjinFormScreenState extends State<StokStjinFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  List<StokStjinItem> _allItems = [];
  List<StokStjinItem> _filteredItems = [];
  List<StokStjinItem> _selectedItems = [];

  String? _nomorStokStjin;

  @override
  void initState() {
    super.initState();
    _loadItems();

    if (widget.stokStjinHeader != null) {
      _nomorStokStjin = widget.stokStjinHeader!['stji_nomor'];
      _selectedDate = DateTime.parse(widget.stokStjinHeader!['stji_tanggal']);
      _keteranganController.text = widget.stokStjinHeader!['stji_keterangan'] ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keteranganController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await StokStjinService.getItemsForStokStjin();
      setState(() {
        _allItems = items.map((item) => StokStjinItem.fromJson(item)).toList();
        _filteredItems = _allItems;

        if (widget.stokStjinHeader == null) {
          _selectedItems = List.from(_allItems);
          _initializeControllers();
        } else {
          _loadStokStjinDetail();
        }
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data setengah jadi: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStokStjinDetail() async {
    if (_nomorStokStjin == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final detail = await StokStjinService.getStokStjinDetail(_nomorStokStjin!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedItems = _allItems.map((item) {
          final detailItem = details.firstWhere(
                (d) => d['stjid_stj_id'] == item.stjId,
            orElse: () => {},
          );

          return StokStjinItem(
            stjId: item.stjId,
            stjNama: item.stjNama,
            qty: detailItem.isNotEmpty ? (detailItem['stjid_qty'] ?? 0) : 0,
          );
        }).toList();

        _filteredItems = _selectedItems;
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail penerimaan setengah jadi: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _qtyControllers[item.stjId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _selectedItems.where((item) {
        final searchLower = query.toLowerCase();
        return item.stjNama.toLowerCase().contains(searchLower);
      }).toList();
    });
  }

  void _updateItemQty(int stjId, int newQty) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.stjId == stjId);
      if (index != -1) {
        _selectedItems[index] = StokStjinItem(
          stjId: _selectedItems[index].stjId,
          stjNama: _selectedItems[index].stjNama,
          qty: newQty,
        );

        final filteredIndex = _filteredItems.indexWhere((item) => item.stjId == stjId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = StokStjinItem(
            stjId: _filteredItems[filteredIndex].stjId,
            stjNama: _filteredItems[filteredIndex].stjNama,
            qty: newQty,
          );
        }
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
              primary: const Color(0xFFF6A918),
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _updateAllQtyFromControllers() {
    for (var entry in _qtyControllers.entries) {
      final stjId = entry.key;
      final controller = entry.value;

      if (controller.text.isNotEmpty) {
        final intValue = int.tryParse(controller.text) ?? 0;
        final newQty = intValue;
        _updateItemQty(stjId, newQty);
      } else {
        _updateItemQty(stjId, 0);
      }
    }
  }

  Future<void> _saveStokStjin() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showErrorSnackbar('Keterangan harus diisi!');
      return;
    }

    _updateAllQtyFromControllers();

    final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
    if (itemsWithQty.isEmpty) {
      _showErrorSnackbar('Minimal satu item harus memiliki quantity!');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final itemsJson = itemsWithQty.map((item) => item.toJson()).toList();

      final result = widget.stokStjinHeader == null
          ? await StokStjinService.createStokStjin(
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      )
          : await StokStjinService.updateStokStjin(
        nomor: _nomorStokStjin!,
        tanggal: tanggalStr,
        keterangan: _keteranganController.text.trim(),
        items: itemsJson,
      );

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        widget.onStokStjinSaved();
        Navigator.pop(context);
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  int get _totalItemsWithQty {
    return _selectedItems.where((item) => item.qty > 0).length;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.stokStjinHeader != null;

    return BaseLayout( // ← GUNAKAN BASELAYOUT
      title: isEdit ? 'Edit Penerimaan' : 'Tambah Penerimaan',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== COMPACT HEADER FORM ==========
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Nomor (readonly jika edit)
                  if (_nomorStokStjin != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.confirmation_number, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _nomorStokStjin!,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                  ],

                  // Tanggal + Keterangan dalam 1 baris
                  Row(
                    children: [
                      // Tanggal - COMPACT
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _selectDate(context),
                                child: Container(
                                  height: 36,
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          DateFormat('dd/MM/yy').format(_selectedDate),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
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

                      SizedBox(width: 10),

                      // Keterangan - COMPACT (normal height)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keterangan',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _keteranganController,
                                style: GoogleFonts.montserrat(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'SHIFT 1, PRODUKSI, dll.',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                maxLines: 1,
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

            SizedBox(height: 12),

            // ========== COMPACT SEARCH SECTION ==========
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                          SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari setengah jadi...',
                                hintStyle: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
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
                              icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                              onPressed: () {
                                _searchController.clear();
                                _filterItems('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Counter badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Text(
                      '${_filteredItems.length}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ========== COMPACT SUMMARY ==========
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_selectedItems.length} items',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 10,
                          color: _totalItemsWithQty > 0 ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${_totalItemsWithQty} dengan QTY',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ========== ITEMS LIST (COMPACT) ==========
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF6A918),
                  strokeWidth: 2,
                ),
              )
                  : _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 36,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada data setengah jadi'
                          : 'Setengah jadi tidak ditemukan',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                itemCount: _filteredItems.length,
                separatorBuilder: (context, index) => SizedBox(height: 6),
                itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
              ),
            ),

            SizedBox(height: 12),

            // ========== COMPACT SAVE BUTTON ==========
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveStokStjin,
                icon: _isSaving
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  isEdit ? Icons.edit_rounded : Icons.save_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  isEdit ? 'UPDATE PENERIMAAN' : 'SIMPAN PENERIMAAN',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF6A918),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(StokStjinItem item) {
    // Pastikan controller ada untuk item ini
    if (!_qtyControllers.containsKey(item.stjId)) {
      _qtyControllers[item.stjId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
    }

    final controller = _qtyControllers[item.stjId]!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 14,
                  color: Colors.teal.shade700,
                ),
              ),
              SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.stjNama,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ID: ${item.stjId}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // QTY Input - CENTERED
              Container(
                width: 70,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.qty > 0 ? Color(0xFFF6A918) : Colors.grey.shade600,
                      height: 1.0,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        height: 1.0,
                      ),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 0;
                      final newQty = intValue;
                      _updateItemQty(item.stjId, newQty);
                    },
                    onTap: () {
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
      ),
    );
  }
}