import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/minta_service.dart';
import '../widgets/base_layout.dart';
import 'add_item_modal_minta.dart';
import '../models/minta_model.dart';

class MintaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? mintaHeader;
  final VoidCallback onMintaSaved;

  const MintaFormScreen({
    super.key,
    this.mintaHeader,
    required this.onMintaSaved,
  });

  @override
  State<MintaFormScreen> createState() => _MintaFormScreenState();
}

class _MintaFormScreenState extends State<MintaFormScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

  List<MintaItem> _selectedItems = [];
  List<MintaItem> _filteredItems = [];

  String? _nomorMinta;

  @override
  void initState() {
    super.initState();

    if (widget.mintaHeader != null) {
      _nomorMinta = widget.mintaHeader!['mt_nomor'];
      _selectedDate = DateTime.parse(widget.mintaHeader!['mt_tanggal']);
      _keteranganController.text = widget.mintaHeader!['mt_keterangan'] ?? '';

      _loadMintaDetail();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keteranganController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _ketControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadMintaDetail() async {
    if (_nomorMinta == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await MintaService.getMintaDetail(_nomorMinta!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      setState(() {
        _selectedItems = details.map((detail) {
          return MintaItem(
            itemId: detail['mtd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qty: detail['mtd_qty']?.toInt() ?? 0,
            keterangan: detail['mtd_keterangan'] ?? '',
          );
        }).toList();

        _filteredItems = List.from(_selectedItems);
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail permintaan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    for (var item in _selectedItems) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qty > 0 ? item.qty.toString() : ''
      );
      _ketControllers[item.itemId] = TextEditingController(
          text: item.keterangan ?? ''
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_selectedItems);
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
        final updatedItem = MintaItem(
          itemId: _selectedItems[index].itemId,
          itemNama: _selectedItems[index].itemNama,
          qty: newQty,
          keterangan: _selectedItems[index].keterangan,
        );
        _selectedItems[index] = updatedItem;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = updatedItem;
        }
      }
    });
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    setState(() {
      final index = _selectedItems.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        final updatedItem = MintaItem(
          itemId: _selectedItems[index].itemId,
          itemNama: _selectedItems[index].itemNama,
          qty: _selectedItems[index].qty,
          keterangan: keterangan,
        );
        _selectedItems[index] = updatedItem;

        final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
        if (filteredIndex != -1) {
          _filteredItems[filteredIndex] = updatedItem;
        }
      }
    });
  }

  void _showAddItemModal() async {
    final selectedItems = await showModalBottomSheet<List<MintaItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemModalMinta(
        existingItems: _selectedItems,
      ),
    );

    if (selectedItems != null && selectedItems.isNotEmpty) {
      setState(() {
        _selectedItems.addAll(selectedItems);
        _filteredItems = List.from(_selectedItems);
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF6A918),
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
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
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
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

  Future<void> _saveMinta() async {
    if (_keteranganController.text.trim().isEmpty) {
      _showErrorSnackbar('Keterangan harus diisi!');
      return;
    }

    _updateAllQtyFromControllers();
    _updateAllKeteranganFromControllers();

    final itemsWithQty = _selectedItems.where((item) => item.qty > 0).toList();
    if (itemsWithQty.isEmpty) {
      _showErrorSnackbar('Minimal satu item harus memiliki quantity!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      final result = widget.mintaHeader == null
          ? await MintaService.createMinta(requestData)
          : await MintaService.updateMinta({
        'nomor': _nomorMinta!,
        'tanggal': tanggalStr,
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      });

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        widget.onMintaSaved();
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
    return _selectedItems.where((item) => item.qty > 0).length;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mintaHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Permintaan Barang' : 'Tambah Permintaan Barang',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_nomorMinta != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.confirmation_number, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _nomorMinta!,
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
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
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
                            const SizedBox(height: 4),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _selectDate(context),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                      const SizedBox(width: 6),
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

                      const SizedBox(width: 10),

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
                            const SizedBox(height: 4),
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _keteranganController,
                                style: GoogleFonts.montserrat(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'SHIFT 1, PERMINTAAN, dll.',
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

            const SizedBox(height: 12),

            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
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
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _showAddItemModal,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                )
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 10,
                          color: _totalItemsWithQty > 0 ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
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

            const SizedBox(height: 8),

            Expanded(
              child: _isLoading
                  ? const Center(
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
                    const SizedBox(height: 8),
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
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMinta,
                icon: _isSaving
                    ? const SizedBox(
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
                  isEdit ? 'UPDATE PERMINTAAN' : 'SIMPAN PERMINTAAN',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF6A918),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(MintaItem item) {
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Color(0xFFF6A918),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
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

                  const SizedBox(width: 8),

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
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: item.qty > 0 ? const Color(0xFFF6A918) : Colors.grey.shade600,
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
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: ketController,
                  style: GoogleFonts.montserrat(fontSize: 10),
                  decoration: InputDecoration(
                    hintText: 'Keterangan item (opsional)',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _updateItemKeterangan(item.itemId, value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}