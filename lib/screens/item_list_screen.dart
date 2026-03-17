import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/item_service.dart';
import '../services/category_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

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

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late Map<String, double> _columnWidths = {
    'no': 120,
    'nama': 250,
    'category': 180,
    'harga': 180,
    'stok': 130,
    'nilai': 200,
    'aksi': 140,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  late ItemDataSource _dataSource;

  int _totalFilteredStock = 0;
  double _totalFilteredValue = 0;
  int _totalFilteredItems = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final [items, categories] = await Future.wait([
        ItemService.getItems(),
        CategoryService.getCategories(),
      ]);

      setState(() {
        _items = items;
        _categories = categories;
        _calculateTotals(items);
        _dataSource = ItemDataSource(
          items: items,
          onEdit: _openEditItem,
          onDelete: _deleteItem,
          formatCurrency: currencyFormat,
          numberFormat: _numberFormat,
          primaryDark: _primaryDark,
          accentGold: _accentGold,
          accentCoral: _accentCoral,
          accentSky: _accentSky,
          borderColor: _borderColor,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> items) {
    _totalFilteredItems = items.length;
    _totalFilteredStock = items.fold(0, (sum, item) {
      return sum + (int.tryParse(item['Stok']?.toString() ?? '0') ?? 0);
    });
    _totalFilteredValue = items.fold(0.0, (sum, item) {
      final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
      return sum + (price * stock);
    });
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        final filteredRows = _dataSource.effectiveRows!;

        List<Map<String, dynamic>> filteredData = [];

        for (var row in filteredRows) {
          final cells = row.getCells();
          final aksiCell = cells.firstWhere(
                (cell) => cell.columnName == 'aksi',
            orElse: () => DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: null),
          );

          if (aksiCell.value != null) {
            filteredData.add(aksiCell.value as Map<String, dynamic>);
          }
        }

        setState(() {
          _totalFilteredItems = filteredData.length;
          _totalFilteredStock = filteredData.fold(0, (sum, item) {
            return sum + (int.tryParse(item['Stok']?.toString() ?? '0') ?? 0);
          });
          _totalFilteredValue = filteredData.fold(0.0, (sum, item) {
            final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
            final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
            return sum + (price * stock);
          });
        });
      }
    });
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

  void _openAddItem() {
    Navigator.pushNamed(
      context,
      AppRoutes.itemForm,
      arguments: {
        'categories': _categories,
        'onSaved': _loadData,
      },
    );
  }

  void _openEditItem(Map<String, dynamic> item) {
    Navigator.pushNamed(
      context,
      AppRoutes.itemForm,
      arguments: {
        'categories': _categories,
        'item': item,
        'onSaved': _loadData,
      },
    );
  }

  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _accentCoral, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Item?', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${item['Nama']}"?',
            style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentCoral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final result = await ItemService.deleteItem(item['id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadData();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final currentState = _key.currentState;
      if (currentState == null) return;

      final visibleRows = _dataSource.effectiveRows ?? _dataSource.rows;

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Item';

      // Set column widths
      sheet.getRangeByIndex(1, 1).columnWidth = 8;  // No
      sheet.getRangeByIndex(1, 2).columnWidth = 35; // Nama
      sheet.getRangeByIndex(1, 3).columnWidth = 25; // Kategori
      sheet.getRangeByIndex(1, 4).columnWidth = 20; // Harga
      sheet.getRangeByIndex(1, 5).columnWidth = 10; // Stok
      sheet.getRangeByIndex(1, 6).columnWidth = 25; // Nilai

      // Header style
      final headerRange = sheet.getRangeByIndex(1, 1, 1, 6);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 11;

      // Headers
      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama Item');
      sheet.getRangeByName('C1').setText('Kategori');
      sheet.getRangeByName('D1').setText('Harga');
      sheet.getRangeByName('E1').setText('Stok');
      sheet.getRangeByName('F1').setText('Nilai Stok');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String nama = '';
        String kategori = '';
        String harga = '';
        int stok = 0;
        double nilai = 0;

        for (var cell in cells) {
          if (cell.columnName == 'no') {
            no = cell.value.toString();
          } else if (cell.columnName == 'nama') {
            nama = cell.value.toString();
          } else if (cell.columnName == 'category') {
            kategori = cell.value.toString();
          } else if (cell.columnName == 'harga') {
            harga = cell.value.toString();
          } else if (cell.columnName == 'stok') {
            stok = cell.value as int;
          } else if (cell.columnName == 'nilai') {
            nilai = cell.value as double;
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nama);
        sheet.getRangeByName('C$rowIndex').setText(kategori);
        sheet.getRangeByName('D$rowIndex').setText(harga);
        sheet.getRangeByName('E$rowIndex').setNumber(stok.toDouble());
        sheet.getRangeByName('F$rowIndex').setNumber(nilai);

        // Style for data rows
        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6);
        dataRange.cellStyle.fontSize = 10;
        dataRange.cellStyle.vAlign = VAlignType.center;

        // Alignment
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.right;

        // Stok rendah styling
        if (stok <= 10) {
          sheet.getRangeByName('E$rowIndex').cellStyle.fontColor = '#FF6B6B';
          sheet.getRangeByName('E$rowIndex').cellStyle.bold = true;
        }

        // Alternating row colors
        if (rowIndex % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8F9FA';
        }

        rowIndex++;
      }

      // Add total row
      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#E9ECEF';

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredItems Item');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#E9ECEF';

      sheet.getRangeByName('C$totalRow').setText('${_categories.length} Kategori');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#E9ECEF';

      sheet.getRangeByName('D$totalRow').setText('Total Stok:');
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByName('E$totalRow').setNumber(_totalFilteredStock.toDouble());
      sheet.getRangeByName('E$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('E$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('E$totalRow').cellStyle.fontColor = '#4CC9F0';
      sheet.getRangeByName('E$totalRow').cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByName('F$totalRow').setNumber(_totalFilteredValue);
      sheet.getRangeByName('F$totalRow').numberFormat = '"Rp "#,##0';
      sheet.getRangeByName('F$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('F$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('F$totalRow').cellStyle.fontColor = '#F6A918';
      sheet.getRangeByName('F$totalRow').cellStyle.hAlign = HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Item_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Item_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showSuccessSnackbar('File Excel berhasil disimpan');
      }
    } catch (e) {
      print('Error export Excel: $e');
      _showErrorSnackbar('Gagal export Excel: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 36,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentMint, _accentMint.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _accentMint.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.table_chart, size: 14, color: Colors.white),
                    label: Text(
                      'Export Excel',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryDark, _primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryDark.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openAddItem,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      isMobile ? 'Tambah' : 'Tambah Item',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: _accentGold,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Memuat data item...',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _bgLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 35,
                      color: _textSecondary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada data item',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Klik tombol Tambah Item untuk memulai',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : Padding(
              padding: EdgeInsets.only(
                left: isTablet ? 16 : 12,
                right: isTablet ? 16 : 12,
                bottom: isTablet ? 16 : 12,
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: SfDataGrid(
                          key: _key,
                          controller: _dataGridController,
                          source: _dataSource,
                          allowColumnsResizing: true,
                          columnResizeMode: ColumnResizeMode.onResizeEnd,
                          onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                            setState(() {
                              _columnWidths[details.column.columnName] = details.width;
                            });
                            return true;
                          },
                          columnWidthMode: ColumnWidthMode.fill,
                          columnWidthCalculationRange: ColumnWidthCalculationRange.allRows,
                          headerRowHeight: 32,
                          rowHeight: 28,
                          allowSorting: true,
                          allowFiltering: true,
                          onFilterChanged: _onFilterChanged,
                          gridLinesVisibility: GridLinesVisibility.both,
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          selectionMode: SelectionMode.none,
                          columns: [
                            GridColumn(
                              columnName: 'no',
                              width: _columnWidths['no'] ?? 120,
                              minimumWidth: 80,
                              maximumWidth: 150,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'No',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'nama',
                              width: _columnWidths['nama'] ?? 250,
                              minimumWidth: 150,
                              maximumWidth: 400,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Nama Item',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'category',
                              width: _columnWidths['category'] ?? 180,
                              minimumWidth: 120,
                              maximumWidth: 300,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Kategori',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'harga',
                              width: _columnWidths['harga'] ?? 180,
                              minimumWidth: 120,
                              maximumWidth: 250,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Harga',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'stok',
                              width: _columnWidths['stok'] ?? 130,
                              minimumWidth: 80,
                              maximumWidth: 150,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Stok',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (!isMobile)
                              GridColumn(
                                columnName: 'nilai',
                                width: _columnWidths['nilai'] ?? 200,
                                minimumWidth: 140,
                                maximumWidth: 300,
                                label: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Nilai',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            GridColumn(
                              columnName: 'aksi',
                              width: _columnWidths['aksi'] ?? 140,
                              minimumWidth: 100,
                              maximumWidth: 180,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Aksi',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _bgLight,
                        border: Border(
                          top: BorderSide(color: _borderColor),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: screenWidth - (isTablet ? 52 : 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: _columnWidths['no'] ?? 120,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Total',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                width: _columnWidths['nama'] ?? 250,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2, size: 11, color: _primaryDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_totalFilteredItems Item',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: _columnWidths['category'] ?? 180,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${_categories.length} Kategori',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                width: (_columnWidths['harga'] ?? 180) + (_columnWidths['stok'] ?? 130) - 16,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Total Stok: ${_numberFormat.format(_totalFilteredStock)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _accentSky,
                                  ),
                                ),
                              ),
                              if (!isMobile)
                                Container(
                                  width: _columnWidths['nilai'] ?? 200,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    currencyFormat.format(_totalFilteredValue),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _accentGold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              Container(
                                width: _columnWidths['aksi'] ?? 140,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: _totalFilteredItems < _items.length
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_items.length - _totalFilteredItems} filter',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: _accentGold,
                                    ),
                                  ),
                                )
                                    : const SizedBox(),
                              ),
                            ],
                          ),
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
    );
  }
}

class ItemDataSource extends DataGridSource {
  ItemDataSource({
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required NumberFormat formatCurrency,
    required NumberFormat numberFormat,
    required Color primaryDark,
    required Color accentGold,
    required Color accentCoral,
    required Color accentSky,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatCurrency = formatCurrency;
    _numberFormat = numberFormat;
    _primaryDark = primaryDark;
    _accentGold = accentGold;
    _accentCoral = accentCoral;
    _accentSky = accentSky;
    _borderColor = borderColor;
    _textPrimary = textPrimary;
    _textSecondary = textSecondary;

    _originalItems = items;
    _updateDataSource(items);
  }

  List<Map<String, dynamic>> _originalItems = [];
  List<DataGridRow> _data = [];
  late NumberFormat _formatCurrency;
  late NumberFormat _numberFormat;
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late Color _primaryDark;
  late Color _accentGold;
  late Color _accentCoral;
  late Color _accentSky;
  late Color _borderColor;
  late Color _textPrimary;
  late Color _textSecondary;

  void _updateDataSource(List<Map<String, dynamic>> items) {
    _data = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      final name = item['Nama']?.toString() ?? '-';
      final category = item['Category']?.toString() ?? '-';
      final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
      final totalValue = price * stock;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<String>(columnName: 'category', value: category),
        DataGridCell<String>(columnName: 'harga', value: _formatCurrency.format(price)),
        DataGridCell<int>(columnName: 'stok', value: stock),
        DataGridCell<double>(columnName: 'nilai', value: totalValue),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: item),
      ]);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'aksi') {
          final item = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: _primaryDark),
                    onPressed: () => _onEdit(item),
                    padding: EdgeInsets.zero,
                    iconSize: 12,
                    tooltip: 'Edit',
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentCoral.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: _accentCoral),
                    onPressed: () => _onDelete(item),
                    padding: EdgeInsets.zero,
                    iconSize: 12,
                    tooltip: 'Hapus',
                  ),
                ),
              ],
            ),
          );
        }

        final isLowStock = cell.columnName == 'stok' &&
            (cell.value is int ? cell.value : 0) <= 10;

        Color textColor = _textPrimary;
        FontWeight fontWeight = FontWeight.normal;

        if (cell.columnName == 'stok' && isLowStock) {
          textColor = _accentCoral;
          fontWeight = FontWeight.w600;
        } else if (cell.columnName == 'no') {
          textColor = _textSecondary;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            cell.columnName == 'nilai'
                ? _formatCurrency.format(cell.value)
                : cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: fontWeight,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return TextAlign.right;
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }
}