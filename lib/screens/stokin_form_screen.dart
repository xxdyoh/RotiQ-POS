import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/stokin_service.dart';
import '../models/stokin_model.dart';
import '../widgets/base_layout.dart';
import 'add_item_modal.dart';

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

class _StokinFormScreenState extends State<StokinFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  List<StokinItem> _allItems = [];
  List<StokinItem> _filteredItems = [];
  List<StokinItem> _selectedItems = [];

  String? _nomorStokin;

  bool _isFromPenjualan = false;
  List<String> _referensiList = [];

  @override
  void initState() {
    super.initState();
    // _loadItems();

    if (widget.stokinHeader != null) {
      _nomorStokin = widget.stokinHeader!['sti_nomor'];
      _selectedDate = DateTime.parse(widget.stokinHeader!['sti_tanggal']);
      _keteranganController.text = widget.stokinHeader!['sti_keterangan'] ?? '';

      _loadStokinDetail();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keteranganController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadStokinDetail() async {
    if (_nomorStokin == null) return;

    setState(() {
      _isLoading = true;
    });

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
      _showErrorSnackbar('Gagal memuat detail stock in: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> _loadStokinDetail() async {
  //   if (_nomorStokin == null) return;
  //
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     final detail = await StokinService.getStokInDetail(_nomorStokin!);
  //     final details = List<Map<String, dynamic>>.from(detail['details']);
  //
  //     setState(() {
  //       _selectedItems = _allItems.map((item) {
  //         final detailItem = details.firstWhere(
  //               (d) => d['stid_item_id'] == item.itemId,
  //           orElse: () => {},
  //         );
  //
  //         return StokinItem(
  //           itemId: item.itemId,
  //           itemNama: item.itemNama,
  //           qty: detailItem.isNotEmpty ? (detailItem['stid_qty'] ?? 0) : 0,
  //         );
  //       }).toList();
  //
  //       _filteredItems = _selectedItems;
  //       _initializeControllers();
  //     });
  //   } catch (e) {
  //     _showErrorSnackbar('Gagal memuat detail stock in: ${e.toString()}');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toInt().toString() : ''
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
    final selectedItems = await showModalBottomSheet<List<StokinItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemModal(
        existingItems: _selectedItems,
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        _selectedItems.addAll(selectedItems);
        _filteredItems = _selectedItems;
        _initializeControllers();
      });
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
      final itemId = entry.key;
      final controller = entry.value;

      if (controller.text.isNotEmpty) {
        final intValue = int.tryParse(controller.text) ?? 0;
        final newQty = intValue;
        _updateItemQty(itemId, newQty);
      } else {
        _updateItemQty(itemId, 0);
      }
    }
  }

  // Future<void> _saveStokin() async {
  //   if (_keteranganController.text.trim().isEmpty) {
  //     _showErrorSnackbar('Keterangan harus diisi!');
  //     return;
  //   }
  //
  //   _updateAllQtyFromControllers();
  //
  //   final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
  //   if (itemsWithQty.isEmpty) {
  //     _showErrorSnackbar('Minimal satu item harus memiliki quantity!');
  //     return;
  //   }
  //
  //   setState(() {
  //     _isSaving = true;
  //   });
  //
  //   try {
  //     final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
  //     final Map<String, dynamic> requestData = {
  //       'tanggal': tanggalStr,
  //       'keterangan': _keteranganController.text.trim(),
  //       'items': itemsWithQty.map((item) => item.toJson()).toList(),
  //     };
  //
  //     // Tambah data penjualan jika ada
  //     if (_isFromPenjualan && _referensiList.isNotEmpty) {
  //       requestData['source'] = 'penjualan';
  //       requestData['referensi_list'] = _referensiList.join(',');
  //     }
  //
  //     final result = widget.stokinHeader == null
  //         ? await StokinService.createStokIn(requestData)
  //         : await StokinService.updateStokIn(
  //       nomor: _nomorStokin!,
  //       tanggal: tanggalStr,
  //       keterangan: _keteranganController.text.trim(),
  //       items: itemsWithQty.map((item) => item.toJson()).toList(),
  //       // Untuk update, mungkin perlu logic berbeda
  //     );
  //
  //     if (result['success']) {
  //       _showSuccessSnackbar(result['message']);
  //       widget.onStokinSaved();
  //       Navigator.pop(context);
  //     } else {
  //       _showErrorSnackbar(result['message']);
  //     }
  //
  //     final itemsJson = itemsWithQty.map((item) => item.toJson()).toList();
  //
  //     final result = widget.stokinHeader == null
  //         ? await StokinService.createStokIn(
  //       tanggal: tanggalStr,
  //       keterangan: _keteranganController.text.trim(),
  //       items: itemsJson,
  //     )
  //         : await StokinService.updateStokIn(
  //       nomor: _nomorStokin!,
  //       tanggal: tanggalStr,
  //       keterangan: _keteranganController.text.trim(),
  //       items: itemsJson,
  //     );
  //
  //     if (result['success']) {
  //       _showSuccessSnackbar(result['message']);
  //       widget.onStokinSaved();
  //       Navigator.pop(context);
  //     } else {
  //       _showErrorSnackbar(result['message']);
  //     }
  //   } catch (e) {
  //     _showErrorSnackbar('Error: ${e.toString()}');
  //   } finally {
  //     setState(() {
  //       _isSaving = false;
  //     });
  //   }
  // }

  Future<void> _saveStokin() async {
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

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      if (_isFromPenjualan && _referensiList.isNotEmpty) {
        requestData['source'] = 'penjualan';
        requestData['referensi_list'] = _referensiList.join(',');
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
      });

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        widget.onStokinSaved();
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
    final isEdit = widget.stokinHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Stock In' : 'Tambah Stock In',
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
                  if (_nomorStokin != null) ...[
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
                              _nomorStokin!,
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
                                  hintText: 'SHIFT 1, STOK AWAL, dll.',
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
                                  hintText: 'Cari item...',
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
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Tombol Add Item
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _showAddItemModal,
                        icon: Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text(
                          'Add Item',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Tombol Load Penjualan
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _loadPenjualan,
                        icon: Icon(Icons.download, size: 14, color: Colors.white),
                        label: Text(
                          'Load Penjualan',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                )
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
                          ? 'Tidak ada data items'
                          : 'Item tidak ditemukan',
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
                onPressed: _isSaving ? null : _saveStokin,
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
                  isEdit ? 'UPDATE STOCK IN' : 'SIMPAN STOCK IN',
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

  Widget _buildItemCard(StokinItem item) {
    // Pastikan controller ada untuk item ini
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toInt().toString() : ''
      );
    }

    final controller = _qtyControllers[item.itemId]!;

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
                  color: Color(0xFFF6A918).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Color(0xFFF6A918),
                ),
              ),
              SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemNama,
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
                      'ID: ${item.itemId}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // QTY Input - FIXED CENTERING
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
                    textAlignVertical: TextAlignVertical.center, // ← INI YANG PENTING
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.qty > 0 ? Color(0xFFF6A918) : Colors.grey.shade600,
                      height: 1.0, // ← PASTIKAN HEIGHT 1.0
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero, // ← NOLKAN SEMUA PADDING
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
                      _updateItemQty(item.itemId, newQty);
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

  Future<void> _loadPenjualan() async {
    final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() => _isLoading = true);

    try {
      final penjualanData = await StokinService.loadPenjualan(tanggalStr);

      if (penjualanData.isEmpty) {
        _showInfoSnackbar('Tidak ada data penjualan');
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

        // CEK EXISTING - MANUAL TANPA .any()
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

      // UPDATE - PASTIKAN COPY LIST
      final updatedSelectedItems = List<StokinItem>.from(_selectedItems);
      updatedSelectedItems.addAll(newItems);

      setState(() {
        _selectedItems = updatedSelectedItems;
        _filteredItems = List.from(updatedSelectedItems);
        _isFromPenjualan = true;
        _referensiList = referensiList.toSet().toList();
        _initializeControllers();
      });

      _showSuccessSnackbar('Berhasil load ${newItems.length} item');

    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Tambah fungsi snackbar info
  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}