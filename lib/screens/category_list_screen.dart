import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/category_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Warna konsisten dengan ItemListScreen
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

  late Map<String, double> _columnWidths = {
    'no': 80,
    'nama': 200,
    'printer_type': 120,
    'discount_percent': 100,
    'discount_rp': 150,
    'is_print': 80,
    'aksi': 100,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  late CategoryDataSource _dataSource;

  int _totalFilteredCategories = 0;
  double _totalDiscountPercent = 0;
  double _totalDiscountRp = 0;
  int _totalPrintEnabled = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    try {
      final categories = await CategoryService.getCategories();

      setState(() {
        _categories = categories;
        _calculateTotals(categories);
        _dataSource = CategoryDataSource(
          categories: categories,
          onEdit: _openEditCategory,
          onDelete: _deleteCategory,
          formatCurrency: _currencyFormat,
          primaryDark: _primaryDark,
          accentGold: _accentGold,
          accentCoral: _accentCoral,
          accentSky: _accentSky,
          accentMint: _accentMint,
          bgLight: _bgLight,
          borderColor: _borderColor,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data kategori: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> categories) {
    _totalFilteredCategories = categories.length;
    _totalDiscountPercent = categories.fold(0.0, (sum, cat) {
      return sum + (double.tryParse(cat['ct_disc']?.toString() ?? '0') ?? 0);
    });
    _totalDiscountRp = categories.fold(0.0, (sum, cat) {
      return sum + (double.tryParse(cat['ct_disc_rp']?.toString() ?? '0') ?? 0);
    });
    _totalPrintEnabled = categories.where((cat) => (cat['ct_isprint'] ?? 0) == 1).length;
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
          _totalFilteredCategories = filteredData.length;
          _totalDiscountPercent = filteredData.fold(0.0, (sum, cat) {
            return sum + (double.tryParse(cat['ct_disc']?.toString() ?? '0') ?? 0);
          });
          _totalDiscountRp = filteredData.fold(0.0, (sum, cat) {
            return sum + (double.tryParse(cat['ct_disc_rp']?.toString() ?? '0') ?? 0);
          });
          _totalPrintEnabled = filteredData.where((cat) => (cat['ct_isprint'] ?? 0) == 1).length;
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

  void _openAddCategory() {
    Navigator.pushNamed(
      context,
      AppRoutes.categoryForm,
      arguments: {
        'onSaved': _loadCategories,
      },
    );
  }

  void _openEditCategory(Map<String, dynamic> category) {
    Navigator.pushNamed(
      context,
      AppRoutes.categoryForm,
      arguments: {
        'category': category,
        'onSaved': _loadCategories,
      },
    );
  }

  void _deleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _accentCoral, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Kategori?', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${category['ct_nama']}"?',
            style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(category);
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

  Future<void> _performDelete(Map<String, dynamic> category) async {
    setState(() => _isLoading = true);
    try {
      final result = await CategoryService.deleteCategory(category['ct_id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadCategories();
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
      sheet.name = 'Data Kategori';

      // Set column widths
      sheet.getRangeByIndex(1, 1).columnWidth = 8;   // No
      sheet.getRangeByIndex(1, 2).columnWidth = 30;  // Nama
      sheet.getRangeByIndex(1, 3).columnWidth = 15;  // Tipe Printer
      sheet.getRangeByIndex(1, 4).columnWidth = 12;  // Diskon %
      sheet.getRangeByIndex(1, 5).columnWidth = 18;  // Diskon Rp
      sheet.getRangeByIndex(1, 6).columnWidth = 8;   // Print

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
      sheet.getRangeByName('B1').setText('Nama Kategori');
      sheet.getRangeByName('C1').setText('Tipe Printer');
      sheet.getRangeByName('D1').setText('Diskon %');
      sheet.getRangeByName('E1').setText('Diskon Rp');
      sheet.getRangeByName('F1').setText('Print');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String nama = '';
        String printerType = '';
        double discountPercent = 0;
        double discountRp = 0;
        bool isPrint = false;

        for (var cell in cells) {
          if (cell.columnName == 'no') {
            no = cell.value.toString();
          } else if (cell.columnName == 'nama') {
            nama = cell.value.toString();
          } else if (cell.columnName == 'printer_type') {
            printerType = cell.value.toString();
          } else if (cell.columnName == 'discount_percent') {
            discountPercent = cell.value as double;
          } else if (cell.columnName == 'discount_rp') {
            discountRp = cell.value as double;
          } else if (cell.columnName == 'is_print') {
            isPrint = cell.value as bool;
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nama);
        sheet.getRangeByName('C$rowIndex').setText(printerType);
        sheet.getRangeByName('D$rowIndex').setNumber(discountPercent);
        sheet.getRangeByName('E$rowIndex').setNumber(discountRp);
        sheet.getRangeByName('F$rowIndex').setText(isPrint ? '✓' : '-');

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
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.center;

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

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredCategories Kategori');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#E9ECEF';

      sheet.getRangeByName('C$totalRow').setText('$_totalPrintEnabled Print');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#E9ECEF';

      sheet.getRangeByName('D$totalRow').setNumber(_totalDiscountPercent);
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('D$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('D$totalRow').cellStyle.fontColor = '#F6A918';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByName('E$totalRow').setNumber(_totalDiscountRp);
      sheet.getRangeByName('E$totalRow').numberFormat = '"Rp "#,##0';
      sheet.getRangeByName('E$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('E$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('E$totalRow').cellStyle.fontColor = '#4CC9F0';
      sheet.getRangeByName('E$totalRow').cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByName('F$totalRow').setText('${_totalFilteredCategories} rows');
      sheet.getRangeByName('F$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('F$totalRow').cellStyle.hAlign = HAlignType.center;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Category_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Category_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
      title: 'Category',
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
                    onPressed: _openAddCategory,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      isMobile ? 'Tambah' : 'Tambah Kategori',
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
                    'Memuat data kategori...',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _categories.isEmpty
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
                      Icons.category_outlined,
                      size: 35,
                      color: _textSecondary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada data kategori',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Klik tombol Tambah Kategori untuk memulai',
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
                              width: _columnWidths['no'] ?? 80,
                              minimumWidth: 60,
                              maximumWidth: 100,
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
                              width: _columnWidths['nama'] ?? 200,
                              minimumWidth: 150,
                              maximumWidth: 300,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Nama Kategori',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'printer_type',
                              width: _columnWidths['printer_type'] ?? 120,
                              minimumWidth: 100,
                              maximumWidth: 150,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Tipe Printer',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'discount_percent',
                              width: _columnWidths['discount_percent'] ?? 100,
                              minimumWidth: 80,
                              maximumWidth: 130,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Diskon %',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'discount_rp',
                              width: _columnWidths['discount_rp'] ?? 150,
                              minimumWidth: 120,
                              maximumWidth: 200,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Diskon Rp',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'is_print',
                              width: _columnWidths['is_print'] ?? 80,
                              minimumWidth: 70,
                              maximumWidth: 100,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Print',
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
                              width: _columnWidths['aksi'] ?? 100,
                              minimumWidth: 90,
                              maximumWidth: 120,
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
                                width: _columnWidths['no'] ?? 80,
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
                                width: _columnWidths['nama'] ?? 200,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Icon(Icons.category, size: 11, color: _primaryDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_totalFilteredCategories Kategori',
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
                                width: _columnWidths['printer_type'] ?? 120,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Icon(Icons.print, size: 11, color: _accentSky),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_totalPrintEnabled Print',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _accentSky,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: _columnWidths['discount_percent'] ?? 100,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${_numberFormat.format(_totalDiscountPercent)}%',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _accentGold,
                                  ),
                                ),
                              ),
                              Container(
                                width: _columnWidths['discount_rp'] ?? 150,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _currencyFormat.format(_totalDiscountRp),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _accentMint,
                                  ),
                                ),
                              ),
                              Container(
                                width: _columnWidths['is_print'] ?? 80,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: _totalFilteredCategories < _categories.length
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_categories.length - _totalFilteredCategories} filter',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: _accentGold,
                                    ),
                                  ),
                                )
                                    : const SizedBox(),
                              ),
                              Container(
                                width: _columnWidths['aksi'] ?? 100,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: const SizedBox(),
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

class CategoryDataSource extends DataGridSource {
  CategoryDataSource({
    required List<Map<String, dynamic>> categories,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required NumberFormat formatCurrency,
    required Color primaryDark,
    required Color accentGold,
    required Color accentCoral,
    required Color accentSky,
    required Color accentMint,
    required Color bgLight,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatCurrency = formatCurrency;
    _primaryDark = primaryDark;
    _accentGold = accentGold;
    _accentCoral = accentCoral;
    _accentSky = accentSky;
    _accentMint = accentMint;
    _bgLight = bgLight;
    _borderColor = borderColor;
    _textPrimary = textPrimary;
    _textSecondary = textSecondary;

    _originalCategories = categories;
    _updateDataSource(categories);
  }

  List<Map<String, dynamic>> _originalCategories = [];
  List<DataGridRow> _data = [];
  late NumberFormat _formatCurrency;
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late Color _primaryDark;
  late Color _accentGold;
  late Color _accentCoral;
  late Color _accentSky;
  late Color _accentMint;
  late Color _bgLight;
  late Color _borderColor;
  late Color _textPrimary;
  late Color _textSecondary;

  String _getPrinterTypeBadge(String printerName) {
    switch (printerName) {
      case 'DRINK':
        return 'MINUMAN';
      case 'FOOD':
        return 'MAKANAN';
      default:
        return 'LAINNYA';
    }
  }

  void _updateDataSource(List<Map<String, dynamic>> categories) {
    _data = categories.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final category = entry.value;

      final name = category['ct_nama']?.toString() ?? '-';
      final printerName = category['ct_PrinterName']?.toString() ?? '-';
      final isPrint = (category['ct_isprint'] ?? 0) == 1;
      final discountPercent = double.tryParse(category['ct_disc']?.toString() ?? '0') ?? 0;
      final discountRp = double.tryParse(category['ct_disc_rp']?.toString() ?? '0') ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<String>(columnName: 'printer_type', value: _getPrinterTypeBadge(printerName)),
        DataGridCell<double>(columnName: 'discount_percent', value: discountPercent),
        DataGridCell<double>(columnName: 'discount_rp', value: discountRp),
        DataGridCell<bool>(columnName: 'is_print', value: isPrint),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: category),
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
          final category = cell.value as Map<String, dynamic>;
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
                    onPressed: () => _onEdit(category),
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
                    onPressed: () => _onDelete(category),
                    padding: EdgeInsets.zero,
                    iconSize: 12,
                    tooltip: 'Hapus',
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'is_print') {
          final isPrint = cell.value == true;
          return Container(
            alignment: Alignment.center,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isPrint ? _accentMint.withOpacity(0.1) : _bgLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isPrint ? _accentMint.withOpacity(0.5) : _borderColor,
                  width: 1,
                ),
              ),
              child: isPrint
                  ? Icon(Icons.check, size: 12, color: _accentMint)
                  : null,
            ),
          );
        }

        if (cell.columnName == 'printer_type') {
          final printerType = cell.value.toString();
          Color color;
          Color bgColor;
          switch (printerType) {
            case 'MINUMAN':
              color = const Color(0xFF2196F3); // Biru terang
              bgColor = const Color(0xFFE3F2FD); // Biru muda
              break;
            case 'MAKANAN':
              color = const Color(0xFFF44336); // Merah terang
              bgColor = const Color(0xFFFFEBEE); // Merah muda
              break;
            default:
              color = _textSecondary;
              bgColor = _bgLight;
          }

          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Text(
                printerType,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          );
        }

        if (cell.columnName == 'discount_percent') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              value > 0 ? '${value.toStringAsFixed(0)}%' : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
                color: value > 0 ? _accentGold : _textPrimary,
              ),
            ),
          );
        }

        if (cell.columnName == 'discount_rp') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              value > 0 ? _formatCurrency.format(value) : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
                color: value > 0 ? _accentMint : _textPrimary,
              ),
            ),
          );
        }

        Color textColor = _textPrimary;
        if (cell.columnName == 'no') {
          textColor = _textSecondary;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.normal,
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
      case 'discount_percent':
      case 'discount_rp':
        return Alignment.centerRight;
      case 'aksi':
      case 'is_print':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'discount_percent':
      case 'discount_rp':
        return TextAlign.right;
      case 'aksi':
      case 'is_print':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }
}