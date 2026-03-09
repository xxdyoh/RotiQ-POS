import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
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
  final TextEditingController _memoController = TextEditingController();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _ketControllers = {};

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingMinta = false;

  String? _nomorDo;
  Cabang? _selectedCabang;
  Map<String, dynamic>? _selectedMinta;
  List<DoItem> _items = [];
  List<DoItem> _filteredItems = [];

  List<Cabang> _cabangList = [];
  List<Map<String, dynamic>> _mintaList = [];

  final DataGridController _dataGridController = DataGridController();
  late DoItemDataSource _itemDataSource;

  @override
  void initState() {
    super.initState();
    _loadCabangList();

    if (widget.doHeader != null) {
      _nomorDo = widget.doHeader!['do_nomor'];
      _selectedDate = DateTime.parse(widget.doHeader!['do_tanggal']);
      _memoController.text = widget.doHeader!['do_memo'] ?? '';
      _loadDoDetail();
    } else {
      _itemDataSource = DoItemDataSource(
        items: _items,
        onQtyChanged: _updateItemQty,
        onKeteranganChanged: _updateItemKeterangan,
      );
    }
  }

  @override
  void dispose() {
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
        _itemDataSource = DoItemDataSource(
          items: _filteredItems,
          onQtyChanged: _updateItemQty,
          onKeteranganChanged: _updateItemKeterangan,
        );
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
        _itemDataSource = DoItemDataSource(
          items: _filteredItems,
          onQtyChanged: _updateItemQty,
          onKeteranganChanged: _updateItemKeterangan,
        );
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
      _itemDataSource.updateItems(_filteredItems);
    });
  }

  void _updateItemQty(int itemId, int newQty) {
    final itemIndex = _items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex != -1) {
      final item = _items[itemIndex];
      if (newQty > item.stockTersedia) {
        _showErrorSnackbar('Qty kirim (${newQty}) melebihi stock tersedia (${item.stockTersedia})!');
        return;
      }
      _items[itemIndex] = _items[itemIndex].copyWith(qtyKirim: newQty);
    }

    final filteredIndex = _filteredItems.indexWhere((item) => item.itemId == itemId);
    if (filteredIndex != -1) {
      _filteredItems[filteredIndex] = _filteredItems[filteredIndex].copyWith(qtyKirim: newQty);
    }

    _itemDataSource.updateItems(_filteredItems);
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

    _itemDataSource.updateItems(_filteredItems);
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

  void _showSelectMintaDialog() {
    if (_selectedCabang == null) {
      _showErrorSnackbar('Pilih cabang terlebih dahulu!');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment, color: Color(0xFFF6A918), size: 20),
            const SizedBox(width: 8),
            Text('Pilih No. Permintaan', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Container(
          width: 400,
          height: 400,
          child: _isLoadingMinta
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
              : _mintaList.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Tidak ada data permintaan', style: GoogleFonts.montserrat(color: Colors.grey.shade500)),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _mintaList.length,
            itemBuilder: (context, index) {
              final minta = _mintaList[index];
              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedMinta = minta;
                  });
                  _loadMintaDetail(minta['mt_nomor']);
                },
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6A918).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.assignment, color: Color(0xFFF6A918), size: 16),
                ),
                title: Text(
                  minta['mt_nomor'],
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  minta['mt_keterangan'] ?? '-',
                  style: GoogleFonts.montserrat(fontSize: 10),
                ),
                trailing: Text(
                  DateFormat('dd/MM/yy').format(DateTime.parse(minta['mt_tanggal'])),
                  style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade600),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: GoogleFonts.montserrat(fontSize: 12)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      final item = _items.firstWhere((item) => item.itemId == itemId);
      if (intValue > item.stockTersedia) {
        _showErrorSnackbar('Qty kirim untuk item ${item.itemNama} melebihi stock tersedia (${item.stockTersedia})!');
        return;
      }

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
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doHeader != null;

    return BaseLayout(
      title: isEdit ? 'Edit Pengiriman' : 'Tambah Pengiriman',
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
                  if (_nomorDo != null) ...[
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
                              _nomorDo!,
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
                            Text('Memo', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
                                controller: _memoController,
                                style: GoogleFonts.montserrat(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'Memo pengiriman...',
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cabang', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Cabang>(
                                  value: _selectedCabang,
                                  isExpanded: true,
                                  hint: Text('Pilih Cabang', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500)),
                                  items: _cabangList.map((cabang) {
                                    return DropdownMenuItem<Cabang>(
                                      value: cabang,
                                      child: Text(
                                        '${cabang.kode} - ${cabang.nama}',
                                        style: GoogleFonts.montserrat(fontSize: 11),
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
                            Text('No. Permintaan', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedMinta != null ? _selectedMinta!['mt_nomor'] : '-',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: _selectedMinta != null ? FontWeight.w600 : FontWeight.normal,
                                              color: _selectedMinta != null ? Colors.black87 : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: _showSelectMintaDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF6A918),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      minimumSize: const Size(36, 36),
                                    ),
                                    child: const Icon(Icons.search, size: 16),
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
              child: _isLoading || _isLoadingMinta
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918), strokeWidth: 2))
                  : _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _selectedMinta == null
                          ? 'Pilih No. Permintaan terlebih dahulu'
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
                        columnName: 'qty_minta',
                        minimumWidth: 80,
                        maximumWidth: 100,
                        label: Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: const Text(
                            'Qty Minta',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'stock',
                        minimumWidth: 80,
                        maximumWidth: 100,
                        label: Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: const Text(
                            'Stock',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'qty_kirim',
                        minimumWidth: 100,
                        maximumWidth: 120,
                        label: Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: const Text(
                            'Qty Kirim',
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
                onPressed: _isSaving ? null : _saveDo,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isEdit ? Icons.edit_rounded : Icons.save_rounded, size: 16, color: Colors.white),
                label: Text(
                  isEdit ? 'UPDATE PENGIRIMAN' : 'SIMPAN PENGIRIMAN',
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
}

class DoItemDataSource extends DataGridSource {
  DoItemDataSource({
    required List<DoItem> items,
    required Function(int, int) onQtyChanged,
    required Function(int, String) onKeteranganChanged,
  }) {
    _items = items;
    _onQtyChanged = onQtyChanged;
    _onKeteranganChanged = onKeteranganChanged;
    _buildRows();
  }

  List<DoItem> _items = [];
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
        DataGridCell<int>(columnName: 'qty_minta', value: item.qtyMinta),
        DataGridCell<int>(columnName: 'stock', value: item.stockTersedia),
        DataGridCell<int>(columnName: 'qty_kirim', value: item.qtyKirim),
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
        if (cell.columnName == 'qty_kirim') {
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

        if (cell.columnName == 'stock') {
          final stock = cell.value;
          final isLowStock = stock < item.qtyMinta;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              stock.toString(),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLowStock ? Colors.orange.shade700 : Colors.green.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Container(
          alignment: cell.columnName == 'no' || cell.columnName == 'qty_minta'
              ? Alignment.center
              : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: cell.columnName == 'qty_minta' ? FontWeight.w600 : FontWeight.normal,
              color: cell.columnName == 'qty_minta' ? Colors.blue.shade700 : Colors.black87,
            ),
            textAlign: cell.columnName == 'no' || cell.columnName == 'qty_minta' || cell.columnName == 'stock'
                ? TextAlign.center
                : TextAlign.left,
          ),
        );
      }).toList(),
    );
  }

  void updateItems(List<DoItem> items) {
    _items = items;
    _buildRows();
    notifyListeners();
  }
}