import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/item_service.dart';
import '../widgets/base_layout.dart';

class BarcodeCustomScreen extends StatefulWidget {
  const BarcodeCustomScreen({super.key});

  @override
  State<BarcodeCustomScreen> createState() => _BarcodeCustomScreenState();
}

class _BarcodeCustomScreenState extends State<BarcodeCustomScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final List<_BarcodeItem> _selectedItems = [];
  bool _isLoading = false;

  String _dayCode = '';
  final TextEditingController _dayCodeController = TextEditingController();

  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentMint = Color(0xFF06D6A0);

  @override
  void initState() {
    super.initState();
    _dayCode = _getDayCode(DateTime.now());
    _dayCodeController.text = _dayCode;
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _dayCodeController.dispose();
    super.dispose();
  }

  String _getDayCode(DateTime date) {
    const dayCodes = {
      DateTime.monday: 'R8',
      DateTime.tuesday: 'R9',
      DateTime.wednesday: 'R10',
      DateTime.thursday: 'R11',
      DateTime.friday: 'R12',
      DateTime.saturday: 'R13',
      DateTime.sunday: 'R14',
    };
    return dayCodes[date.weekday] ?? 'R?';
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ItemService.getItemsForBarcode();
      setState(() {
        _allItems = items;
        _filteredItems = List.from(items);
      });
    } catch (e) {
      _showSnackbar('Gagal memuat item', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems.where((item) {
          final nama = item['nama']?.toString().toLowerCase() ?? '';
          return nama.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _addItem(Map<String, dynamic> item) {
    final qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) {
      _showSnackbar('Jumlah minimal 1', isError: true);
      return;
    }

    final id = item['id']?.toString() ?? '';
    final nama = item['nama']?.toString() ?? '-';
    final harga = double.tryParse(item['harga']?.toString() ?? '0') ?? 0;

    // Cek apakah item sudah ada
    final existingIndex = _selectedItems.indexWhere((s) => s.kode == id);
    if (existingIndex >= 0) {
      _selectedItems[existingIndex].qty += qty;
    } else {
      _selectedItems.add(_BarcodeItem(kode: id, nama: nama, harga: harga, qty: qty));
    }
    setState(() {});
  }

  void _updateQty(int index, int newQty) {
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }
    setState(() {
      _selectedItems[index].qty = newQty;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  int get _totalBarcode {
    return _selectedItems.fold(0, (sum, item) => sum + item.qty);
  }

  void _showPrintDialog() {
    if (_selectedItems.isEmpty) {
      _showSnackbar('Belum ada item', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Print Barcode', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Tampilkan harga pada barcode?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _printBarcode(withPrice: false);
            },
            child: Text('Tanpa Harga', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _printBarcode(withPrice: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Dengan Harga', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _printBarcode({required bool withPrice}) async {
    final dayCode = _dayCodeController.text.isNotEmpty ? _dayCodeController.text : _dayCode;

    final List<Map<String, dynamic>> items = [];
    for (var sel in _selectedItems) {
      for (int i = 0; i < sel.qty; i++) {
        items.add({'kode': sel.kode, 'nama': sel.nama, 'harga': sel.harga});
      }
    }

    if (items.isEmpty) {
      _showSnackbar('Tidak ada barcode untuk dicetak', isError: true);
      return;
    }

    final pdf = pw.Document();
    const double pageWidth = 204.0;
    const double pageHeight = 48.0;
    const double colWidth = 95.0;
    const double gap = 24.0;

    for (int i = 0; i < items.length; i += 2) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: colWidth,
                  height: pageHeight,
                  padding: pw.EdgeInsets.only(left: 10, top: 1, bottom: 1),
                  child: _buildLabel(items[i], dayCode, withPrice),
                ),
                pw.SizedBox(width: gap),
                if (i + 1 < items.length)
                  pw.Container(
                    width: colWidth,
                    height: pageHeight,
                    padding: pw.EdgeInsets.only(right: 2, top: 1, bottom: 1),
                    child: _buildLabel(items[i + 1], dayCode, withPrice),
                  )
                else
                  pw.Spacer(),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Barcode_Custom_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      usePrinterSettings: true,
    );
  }

  pw.Widget _buildLabel(Map<String, dynamic> item, String dayCode, bool withPrice) {
    final nama = item['nama']?.toString() ?? '-';
    final kode = item['kode']?.toString() ?? '-';
    final harga = (item['harga'] ?? 0).toDouble();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(nama, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold), maxLines: 1, overflow: pw.TextOverflow.clip),
        pw.SizedBox(height: 1),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.BarcodeWidget(data: kode, barcode: pw.Barcode.code128(), width: 70, height: 16),
            pw.SizedBox(width: 2),
            pw.Container(
              width: 18,
              alignment: pw.Alignment.topCenter,
              padding: pw.EdgeInsets.only(top: 2),
              child: pw.Text(dayCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(kode, style: pw.TextStyle(fontSize: 6)),
            pw.Text(withPrice ? 'Rp.${NumberFormat('#,##0').format(harga)}' : '', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
        backgroundColor: isError ? _accentRed : _accentMint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isWide = MediaQuery.of(context).size.width > 900;

    return BaseLayout(
      title: 'Cetak Barcode',
      showBackButton: true,
      showSidebar: !isMobile,
      isFormScreen: true,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Search + DayCode
            Container(
              padding: const EdgeInsets.all(12),
              color: _surfaceWhite,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterItems,
                        style: GoogleFonts.montserrat(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Cari item...',
                          hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary),
                          prefixIcon: Icon(Icons.search, size: 16, color: _textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 55,
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: _accentGold)),
                      child: TextField(
                        controller: _dayCodeController,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: _accentGold),
                        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom bar (Print button)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _surfaceWhite,
              child: Row(
                children: [
                  Text('${_selectedItems.length} item • $_totalBarcode barcode', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary)),
                  const Spacer(),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _selectedItems.isEmpty ? null : _showPrintDialog,
                      icon: const Icon(Icons.print, size: 18),
                      label: Text('Print', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main content: kiri = selected items, kanan = list item
            Expanded(
              child: isWide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panel kiri - Selected Items
                  SizedBox(
                    width: 320,
                    child: _buildSelectedItemsPanel(),
                  ),
                  Container(width: 1, color: _borderColor),
                  // Panel kanan - Item List
                  Expanded(child: _buildItemList()),
                ],
              )
                  : Column(
                children: [
                  // Selected items (compact)
                  if (_selectedItems.isNotEmpty) _buildSelectedItemsPanel(),
                  const Divider(height: 1),
                  // Item list
                  Expanded(child: _buildItemList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedItemsPanel() {
    if (_selectedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.qr_code_2, size: 40, color: _textSecondary.withOpacity(0.5)),
              const SizedBox(height: 8),
              Text('Belum ada item dipilih', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
              const SizedBox(height: 4),
              Text('Klik item di daftar untuk menambah', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Item Terpilih', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedItems.length,
              itemBuilder: (context, index) {
                final item = _selectedItems[index];
                final qtyCtrl = TextEditingController(text: '${item.qty}');
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surfaceWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: Text('${index + 1}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryDark))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.nama, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('ID: ${item.kode} • Rp.${NumberFormat('#,##0').format(item.harga)}', style: GoogleFonts.montserrat(fontSize: 9, color: _textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Qty input - diperlebar
                      SizedBox(
                        width: 65,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _bgLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _borderColor),
                          ),
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryDark),
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                            onChanged: (value) {
                              final qty = int.tryParse(value);
                              if (qty != null) _updateQty(index, qty);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeItem(index),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: _accentRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Icon(Icons.delete_outline, color: _accentRed, size: 16),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredItems.isEmpty) {
      return Center(child: Text('Item tidak ditemukan', style: GoogleFonts.montserrat(color: _textSecondary)));
    }

    return ListView.builder(
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final id = item['id']?.toString() ?? '';
        final nama = item['nama']?.toString() ?? '-';
        final harga = double.tryParse(item['harga']?.toString() ?? '0') ?? 0;
        final alreadyAdded = _selectedItems.any((s) => s.kode == id);

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: alreadyAdded ? _accentMint : _borderColor,
            child: Icon(alreadyAdded ? Icons.check : Icons.add, size: 16, color: Colors.white),
          ),
          title: Text(nama, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
          subtitle: Text('ID: $id • Rp.${NumberFormat('#,##0').format(harga)}', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
          trailing: alreadyAdded
              ? IconButton(
            icon: Icon(Icons.remove_circle_outline, color: _accentRed, size: 20),
            onPressed: () {
              final idx = _selectedItems.indexWhere((s) => s.kode == id);
              if (idx >= 0) _removeItem(idx);
            },
          )
              : null,
          onTap: alreadyAdded ? null : () => _addItem(item),
        );
      },
    );
  }
}

class _BarcodeItem {
  final String kode;
  final String nama;
  final double harga;
  int qty;

  _BarcodeItem({required this.kode, required this.nama, required this.harga, required this.qty});
}