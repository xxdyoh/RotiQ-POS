import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
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

  // Color Palette - Minimalis dengan aksen primary
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _primaryLight = Color(0xFF34495E);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentMint = Color(0xFF06D6A0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _accentSky = Color(0xFF4CC9F0);

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late Map<String, double> _columnWidths = {
    'no': 100,
    'nama': 200,
    'printer_type': 150,
    'discount_percent': 150,
    'discount_rp': 150,
    'is_print': 100,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  late CategoryDataSource _dataSource;

  int _totalFilteredCategories = 0;
  double _totalDiscountPercent = 0;
  double _totalDiscountRp = 0;
  int _totalPrintEnabled = 0;

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
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data kategori', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> categories) {
    _totalFilteredCategories = categories.length;
    _totalDiscountPercent = categories.fold(0.0, (sum, cat) => sum + (double.tryParse(cat['ct_disc']?.toString() ?? '0') ?? 0));
    _totalDiscountRp = categories.fold(0.0, (sum, cat) => sum + (double.tryParse(cat['ct_disc_rp']?.toString() ?? '0') ?? 0));
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
          if (aksiCell.value != null) filteredData.add(aksiCell.value as Map<String, dynamic>);
        }
        setState(() {
          _totalFilteredCategories = filteredData.length;
          _totalDiscountPercent = filteredData.fold(0.0, (sum, cat) => sum + (double.tryParse(cat['ct_disc']?.toString() ?? '0') ?? 0));
          _totalDiscountRp = filteredData.fold(0.0, (sum, cat) => sum + (double.tryParse(cat['ct_disc_rp']?.toString() ?? '0') ?? 0));
          _totalPrintEnabled = filteredData.where((cat) => (cat['ct_isprint'] ?? 0) == 1).length;
        });
      }
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
        backgroundColor: isError ? _accentRed : _accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openAddCategory() {
    Navigator.pushNamed(context, AppRoutes.categoryForm, arguments: {'onSaved': _loadCategories});
  }

  void _openEditCategory(Map<String, dynamic> category) {
    Navigator.pushNamed(context, AppRoutes.categoryForm, arguments: {'category': category, 'onSaved': _loadCategories});
  }

  void _deleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Kategori', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${category['ct_nama']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(category);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> category) async {
    setState(() => _isLoading = true);
    try {
      final result = await CategoryService.deleteCategory(category['ct_id'].toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadCategories();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
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

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 30;
      sheet.getRangeByIndex(1, 3).columnWidth = 15;
      sheet.getRangeByIndex(1, 4).columnWidth = 12;
      sheet.getRangeByIndex(1, 5).columnWidth = 18;
      sheet.getRangeByIndex(1, 6).columnWidth = 8;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 6);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama Kategori');
      sheet.getRangeByName('C1').setText('Tipe Printer');
      sheet.getRangeByName('D1').setText('Diskon %');
      sheet.getRangeByName('E1').setText('Diskon Rp');
      sheet.getRangeByName('F1').setText('Print');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();
        String no = '', nama = '', printerType = '';
        double discountPercent = 0, discountRp = 0;
        bool isPrint = false;
        for (var cell in cells) {
          if (cell.columnName == 'no') no = cell.value.toString();
          else if (cell.columnName == 'nama') nama = cell.value.toString();
          else if (cell.columnName == 'printer_type') printerType = cell.value.toString();
          else if (cell.columnName == 'discount_percent') discountPercent = cell.value as double;
          else if (cell.columnName == 'discount_rp') discountRp = cell.value as double;
          else if (cell.columnName == 'is_print') isPrint = cell.value as bool;
        }
        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nama);
        sheet.getRangeByName('C$rowIndex').setText(printerType);
        sheet.getRangeByName('D$rowIndex').setNumber(discountPercent);
        sheet.getRangeByName('E$rowIndex').setNumber(discountRp);
        sheet.getRangeByName('F$rowIndex').setText(isPrint ? '✓' : '-');

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6);
        dataRange.cellStyle.fontSize = 9;
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.center;
        if (rowIndex % 2 == 0) dataRange.cellStyle.backColor = '#F8FAFC';
        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredCategories Kategori');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').setText('$_totalPrintEnabled Print');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('D$totalRow').setNumber(_totalDiscountPercent);
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('D$totalRow').cellStyle.fontColor = '#F6A918';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('E$totalRow').setNumber(_totalDiscountRp);
      sheet.getRangeByName('E$totalRow').numberFormat = '"Rp "#,##0';
      sheet.getRangeByName('E$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('E$totalRow').cellStyle.fontColor = '#4CC9F0';
      sheet.getRangeByName('E$totalRow').cellStyle.hAlign = HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Category_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Category_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showSnackbar('File Excel berhasil disimpan');
      }
    } catch (e) {
      _showSnackbar('Gagal export Excel', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Kategori',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(icon: Icons.download_outlined, label: 'Export', color: _accentBlue, onPressed: _exportToExcel, isMobile: isMobile),
                  const SizedBox(width: 8),
                  _buildActionButton(icon: Icons.add, label: isMobile ? 'Tambah' : 'Tambah Kategori', color: _primaryDark, onPressed: _openAddCategory, isMobile: isMobile),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _categories.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                padding: EdgeInsets.only(left: isTablet ? 16 : 12, right: isTablet ? 16 : 12, bottom: isTablet ? 16 : 12),
                child: Container(
                  decoration: BoxDecoration(color: _surfaceWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SfDataGrid(
                            key: _key,
                            controller: _dataGridController,
                            source: _dataSource,
                            allowColumnsResizing: true,
                            columnResizeMode: ColumnResizeMode.onResizeEnd,
                            onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                              setState(() => _columnWidths[details.column.columnName] = details.width);
                              return true;
                            },
                            columnWidthMode: ColumnWidthMode.fill,
                            headerRowHeight: 32,
                            rowHeight: 28,
                            allowSorting: true,
                            allowFiltering: true,
                            onFilterChanged: _onFilterChanged,
                            gridLinesVisibility: GridLinesVisibility.both,
                            headerGridLinesVisibility: GridLinesVisibility.both,
                            selectionMode: SelectionMode.none,
                            columns: [
                              _buildGridColumn('no', 'No', width: _columnWidths['no'], alignment: Alignment.center),
                              _buildGridColumn('nama', 'Nama Kategori', width: _columnWidths['nama']),
                              _buildGridColumn('printer_type', 'Tipe Printer', width: _columnWidths['printer_type'], alignment: Alignment.center),
                              _buildGridColumn('discount_percent', 'Diskon %', width: _columnWidths['discount_percent'], alignment: Alignment.centerRight),
                              _buildGridColumn('discount_rp', 'Diskon Rp', width: _columnWidths['discount_rp'], alignment: Alignment.centerRight),
                              _buildGridColumn('is_print', 'Print', width: _columnWidths['is_print'], alignment: Alignment.center),
                              _buildGridColumn('aksi', 'Aksi', width: _columnWidths['aksi'], alignment: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: _bgLight, border: Border(top: BorderSide(color: _borderColor)), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                        child: Row(
                          children: [
                            Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textPrimary)),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(Icons.category_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$_totalFilteredCategories Kategori', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(Icons.print_outlined, size: 12, color: _accentSky),
                                const SizedBox(width: 4),
                                Text('$_totalPrintEnabled Print', style: GoogleFonts.montserrat(fontSize: 10, color: _accentSky)),
                              ],
                            ),
                            const Spacer(),
                            Text('Diskon %: ${_numberFormat.format(_totalDiscountPercent)}%', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _accentGold)),
                            const SizedBox(width: 16),
                            Text('Diskon Rp: ${_currencyFormat.format(_totalDiscountRp)}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _accentMint)),
                          ],
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
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed, required bool isMobile}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  GridColumn _buildGridColumn(String name, String label, {double? width, Alignment alignment = Alignment.centerLeft}) {
    return GridColumn(
      columnName: name,
      width: width ?? double.nan,
      label: Container(padding: const EdgeInsets.symmetric(horizontal: 12), alignment: alignment, child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 10, color: _textSecondary))),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: _bgLight, shape: BoxShape.circle), child: Icon(Icons.category_outlined, size: 28, color: _textTertiary)),
          const SizedBox(height: 16),
          Text('Belum ada data kategori', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah Kategori" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class CategoryDataSource extends DataGridSource {
  CategoryDataSource({
    required List<Map<String, dynamic>> categories,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required NumberFormat formatCurrency,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatCurrency = formatCurrency;
    _updateDataSource(categories);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit, _onDelete;
  late NumberFormat _formatCurrency;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentMint = Color(0xFF06D6A0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRedLight = Color(0xFFEF4444);

  String _getPrinterTypeBadge(String printerName) {
    switch (printerName) {
      case 'DRINK': return 'MINUMAN';
      case 'FOOD': return 'MAKANAN';
      default: return 'LAINNYA';
    }
  }

  void _updateDataSource(List<Map<String, dynamic>> categories) {
    _data = categories.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final category = entry.value;
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: category['ct_nama']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'printer_type', value: _getPrinterTypeBadge(category['ct_PrinterName']?.toString() ?? '-')),
        DataGridCell<double>(columnName: 'discount_percent', value: double.tryParse(category['ct_disc']?.toString() ?? '0') ?? 0),
        DataGridCell<double>(columnName: 'discount_rp', value: double.tryParse(category['ct_disc_rp']?.toString() ?? '0') ?? 0),
        DataGridCell<bool>(columnName: 'is_print', value: (category['ct_isprint'] ?? 0) == 1),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(category), color: _primaryDark),
                const SizedBox(width: 4),
                _buildIconButton(Icons.delete_outlined, () => _onDelete(category), color: _accentRed),
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
              decoration: BoxDecoration(color: isPrint ? _accentMint.withOpacity(0.1) : _bgLight, borderRadius: BorderRadius.circular(4), border: Border.all(color: isPrint ? _accentMint.withOpacity(0.5) : _borderColor)),
              child: isPrint ? Icon(Icons.check, size: 12, color: _accentMint) : null,
            ),
          );
        }
        if (cell.columnName == 'printer_type') {
          final printerType = cell.value.toString();
          Color color = _textSecondary, bgColor = _bgLight;
          if (printerType == 'MINUMAN') { color = _accentBlue; bgColor = const Color(0xFFE3F2FD); }
          else if (printerType == 'MAKANAN') { color = _accentRedLight; bgColor = const Color(0xFFFFEBEE); }
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(printerType, style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w700, color: color)),
            ),
          );
        }
        if (cell.columnName == 'discount_percent') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(value > 0 ? '${value.toStringAsFixed(0)}%' : '-', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal, color: value > 0 ? _accentGold : _textPrimary)),
          );
        }
        if (cell.columnName == 'discount_rp') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(value > 0 ? _formatCurrency.format(value) : '-', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal, color: value > 0 ? _accentMint : _textPrimary)),
          );
        }
        Color textColor = _textPrimary;
        if (cell.columnName == 'no') textColor = _textSecondary;
        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(cell.value.toString(), style: GoogleFonts.montserrat(fontSize: 11, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.all(5), child: Icon(icon, size: 15, color: color ?? _textSecondary))));
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'discount_percent' || columnName == 'discount_rp') return Alignment.centerRight;
    if (columnName == 'aksi' || columnName == 'is_print' || columnName == 'printer_type' || columnName == 'no') return Alignment.center;
    return Alignment.centerLeft;
  }
}