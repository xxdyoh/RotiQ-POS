import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
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

class _SerahTerimaFormScreenState extends State<SerahTerimaFormScreen> {
  final TextEditingController _keteranganController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};
  final DataGridController _dataGridController = DataGridController();
  late SerahTerimaItemDataSource _itemDataSource;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingSpk = false;

  String? _nomorSerahTerima;
  Map<String, dynamic>? _selectedSpk;
  List<SerahTerimaItem> _items = [];
  List<SerahTerimaItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();

    if (widget.serahTerimaHeader != null) {
      _nomorSerahTerima = widget.serahTerimaHeader!['stbj_nomor'];
      _selectedDate = DateTime.parse(widget.serahTerimaHeader!['stbj_tanggal']);
      _keteranganController.text = widget.serahTerimaHeader!['stbj_keterangan'] ?? '';
      _selectedSpk = {
        'spk_nomor': widget.serahTerimaHeader!['stbj_spk_nomor'],
      };
      _loadSerahTerimaDetail();
    }

    _itemDataSource = SerahTerimaItemDataSource(
      items: _items,
      onQtyChanged: _updateItemQty,
      onKeteranganChanged: _updateItemKeterangan,
    );
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    _qtyControllers.values.forEach((controller) => controller.dispose());
    _ketControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadSerahTerimaDetail() async {
    if (_nomorSerahTerima == null) return;

    setState(() => _isLoading = true);

    try {
      final detail = await SerahTerimaService.getSerahTerimaDetail(_nomorSerahTerima!);
      final details = List<Map<String, dynamic>>.from(detail['details']);

      // Load juga detail SPK untuk mendapatkan qty SPK asli
      final spkDetail = await SerahTerimaService.getSpkDetail(_selectedSpk!['spk_nomor']);
      final spkDetails = Map.fromIterable(
        spkDetail['details'],
        key: (item) => item['spkd_brg_kode'],
        value: (item) => item['spkd_qty'],
      );

      setState(() {
        _items = details.map((detail) {
          int qtySpk = 0;
          var rawQty = spkDetails[detail['stbjd_brg_kode']];
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
        _itemDataSource = SerahTerimaItemDataSource(
          items: _filteredItems,
          onQtyChanged: _updateItemQty,
          onKeteranganChanged: _updateItemKeterangan,
        );
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail serah terima: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSpkDetail(String spkNomor) async {
    setState(() {
      _isLoadingSpk = true;
      _items.clear();
    });

    try {
      final spkDetail = await SerahTerimaService.getSpkDetail(spkNomor);
      final details = List<Map<String, dynamic>>.from(spkDetail['details']);

      setState(() {
        _items = details.map((detail) {
          // Parse qty SPK dengan benar
          int qtySpk = 0;
          var rawQty = detail['spkd_qty'];
          if (rawQty is int) qtySpk = rawQty;
          else if (rawQty is double) qtySpk = rawQty.toInt();
          else if (rawQty is String) qtySpk = int.tryParse(rawQty) ?? 0;

          print('Item: ${detail['item_nama']}, Qty SPK: $qtySpk'); // Debug

          return SerahTerimaItem(
            itemId: detail['spkd_brg_kode'],
            itemNama: detail['item_nama'] ?? '',
            qtySpk: qtySpk, // Gunakan hasil parsing
            qtyTerima: 0,
            keterangan: '',
          );
        }).toList();

        _filteredItems = List.from(_items);
        _itemDataSource = SerahTerimaItemDataSource(
          items: _filteredItems,
          onQtyChanged: _updateItemQty,
          onKeteranganChanged: _updateItemKeterangan,
        );
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat detail SPK: ${e.toString()}');
    } finally {
      setState(() => _isLoadingSpk = false);
    }
  }

  void _initializeControllers() {
    for (var item in _items) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyTerima > 0 ? item.qtyTerima.toString() : ''
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
      _itemDataSource.updateItems(_filteredItems);
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    print('Updating item $itemId to qty: $newQty');

    // Update di _items
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      print('Found item at index $itemIndex, old qty: ${_items[itemIndex]
          .qtyTerima}');
      _items[itemIndex] = _items[itemIndex].copyWith(qtyTerima: newQty);
      print('New qty: ${_items[itemIndex].qtyTerima}');
    }

    // Update di _filteredItems
    final filteredIndex = _filteredItems.indexWhere((item) =>
    item.itemId == itemId);
    if (filteredIndex != -1) {
      _filteredItems[filteredIndex] =
          _filteredItems[filteredIndex].copyWith(qtyTerima: newQty);
    }

    // Update DataSource
    _itemDataSource.updateItems(_filteredItems);

    setState(() {});
  }

  void _updateItemKeterangan(int itemId, String keterangan) {
    // Update di _items
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      _items[itemIndex] = _items[itemIndex].copyWith(keterangan: keterangan);
    }

    // Update di _filteredItems
    final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
    if (filteredIndex != -1) {
      _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(keterangan: keterangan);
    }

    // Update DataSource
    _itemDataSource.updateItems(_filteredItems);

    // Trigger rebuild untuk update tampilan
    setState(() {});
  }

  Future<void> _selectSpk() async {
    final selectedSpk = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpkSelectionDialog(
        onSpkSelected: (spk) {
          Navigator.pop(context, spk);
        },
      ),
    );

    if (selectedSpk != null) {
      print('SPK selected: ${selectedSpk['spk_nomor']}');
      setState(() {
        _selectedSpk = selectedSpk;
      });
      await _loadSpkDetail(selectedSpk['spk_nomor']);
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
            colorScheme: const ColorScheme.light(primary: Color(0xFFF6A918), onPrimary: Colors.white),
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
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
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
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
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

  Future<void> _saveSerahTerima() async {
    if (_selectedSpk == null) {
      _showErrorSnackbar('SPK harus dipilih!');
      return;
    }

    // Ambil nilai terbaru dari TextField di grid
    // Data sudah otomatis terupdate melalui _updateItemQty

    final itemsWithQty = _items.where((item) => item.qtyTerima > 0).toList();

    print('Items with qty: ${itemsWithQty.length}'); // Untuk debug
    for (var item in itemsWithQty) {
      print('Item: ${item.itemNama}, Qty: ${item.qtyTerima}');
    }

    if (itemsWithQty.isEmpty) {
      _showErrorSnackbar('Minimal satu item harus memiliki quantity terima!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> requestData = {
        'tanggal': tanggalStr,
        'spk_nomor': _selectedSpk!['spk_nomor'],
        'keterangan': _keteranganController.text.trim(),
        'items': itemsWithQty.map((item) => item.toJson()).toList(),
      };

      final result = widget.serahTerimaHeader == null
          ? await SerahTerimaService.createSerahTerima(requestData)
          : await SerahTerimaService.updateSerahTerima(_nomorSerahTerima!, requestData);

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        widget.onSerahTerimaSaved();
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
    return _items.where((item) => item.qtyTerima > 0).length;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.serahTerimaHeader != null;

    return BaseLayout(
        title: isEdit ? 'Edit Serah Terima' : 'Tambah Serah Terima',
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_nomorSerahTerima != null) ...[
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
                          _nomorSerahTerima!,
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
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
                        Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
                                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
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
                        Text('Keterangan', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
                              hintText: 'Keterangan serah terima...',
                              hintStyle: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade500),
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No. SPK', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSpk != null ? _selectedSpk!['spk_nomor'] : 'Belum dipilih',
                            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: _selectSpk,
                        icon: Icon(Icons.search, size: 14, color: Colors.white),
                        label: Text('Pilih SPK', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1))],
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
                          decoration: InputDecoration(
                            hintText: 'Cari item...',
                            hintStyle: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500),
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
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(
            'Total: ${_items.length} items',
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF6A918).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 10, color: _totalItemsWithQty > 0 ? Colors.green : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${_totalItemsWithQty} dengan QTY',
                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
              ],
            ),
        ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading || _isLoadingSpk
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918), strokeWidth: 2))
                    : _filteredItems.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _selectedSpk == null
                            ? 'Pilih SPK terlebih dahulu'
                            : 'Tidak ada data items',
                        style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SfDataGrid(
                      source: _itemDataSource,
                      controller: _dataGridController,
                      allowColumnsResizing: true,
                      columnResizeMode: ColumnResizeMode.onResize,
                      columnWidthMode: ColumnWidthMode.auto,
                      headerRowHeight: 36,
                      rowHeight: 40,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      columns: [
                        GridColumn(
                          columnName: 'no',
                          minimumWidth: 50,
                          maximumWidth: 60,
                          label: Container(
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: const Text(
                              'No',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'item_nama',
                          minimumWidth: 200,
                          maximumWidth: 300,
                          label: Container(
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nama Item',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'qty_spk',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: const Text(
                              'Qty SPK',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'qty_terima',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: const Text(
                              'Qty Terima',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'keterangan',
                          minimumWidth: 200,
                          maximumWidth: 300,
                          label: Container(
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Keterangan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSerahTerima,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isEdit ? Icons.edit_rounded : Icons.save_rounded, size: 16, color: Colors.white),
                  label: Text(
                    isEdit ? 'UPDATE SERAH TERIMA' : 'SIMPAN SERAH TERIMA',
                    style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6A918),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildItemCard(SerahTerimaItem item) {
    if (!_qtyControllers.containsKey(item.itemId)) {
      _qtyControllers[item.itemId] = TextEditingController(
          text: item.qtyTerima > 0 ? item.qtyTerima.toString() : ''
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1))],
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
                    child: const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFFF6A918)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemNama,
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${item.itemId} | SPK: ${item.qtySpk}',
                          style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Container(
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
                            color: item.qtyTerima > 0 ? const Color(0xFFF6A918) : Colors.grey.shade600,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade400, height: 1.0),
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
                    hintStyle: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade400),
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

class SerahTerimaItemDataSource extends DataGridSource {
  SerahTerimaItemDataSource({
    required List<SerahTerimaItem> items,
    required Function(int, int) onQtyChanged,
    required Function(int, String) onKeteranganChanged,
  }) {
    _items = items;
    _onQtyChanged = onQtyChanged;
    _onKeteranganChanged = onKeteranganChanged;
    _buildRows();
  }

  List<SerahTerimaItem> _items = [];
  List<DataGridRow> _data = [];
  late Function(int, int) _onQtyChanged;
  late Function(int, String) _onKeteranganChanged;

  void _buildRows() {
    _data = _items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'item_nama', value: item.itemNama),
        DataGridCell<int>(columnName: 'qty_spk', value: item.qtySpk),
        DataGridCell<int>(columnName: 'qty_terima', value: item.qtyTerima),
        DataGridCell<String>(columnName: 'keterangan', value: item.keterangan ?? ''),
      ]);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _data.indexOf(row);
    if (rowIndex < 0 || rowIndex >= _items.length) {
      return DataGridRowAdapter(cells: []);
    }

    final item = _items[rowIndex];
    final cells = row.getCells();

    return DataGridRowAdapter(
      cells: cells.map<Widget>((cell) {
        if (cell.columnName == 'qty_terima') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextFormField(
              initialValue: cell.value.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cell.value > 0 ? const Color(0xFFF6A918) : Colors.grey.shade600,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                isDense: true,
              ),
              onChanged: (value) {
                final intValue = int.tryParse(value) ?? 0;
                _onQtyChanged(item.itemId, intValue);
              },
            ),
          );
        }

        if (cell.columnName == 'keterangan') {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextFormField(
              initialValue: cell.value,
              style: GoogleFonts.montserrat(fontSize: 11),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                isDense: true,
              ),
              onChanged: (value) {
                _onKeteranganChanged(item.itemId, value);
              },
            ),
          );
        }

        return Container(
          alignment: cell.columnName == 'no' || cell.columnName == 'qty_spk'
              ? Alignment.center
              : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: cell.columnName == 'qty_spk' ? FontWeight.w600 : FontWeight.normal,
              color: cell.columnName == 'qty_spk' ? Colors.blue.shade700 : Colors.black87,
            ),
            textAlign: cell.columnName == 'no' || cell.columnName == 'qty_spk'
                ? TextAlign.center
                : TextAlign.left,
          ),
        );
      }).toList(),
    );
  }

  void updateItems(List<SerahTerimaItem> items) {
    _items = items;
    _buildRows();
    notifyListeners();
  }
}