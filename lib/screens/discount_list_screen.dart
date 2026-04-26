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
import '../services/discount_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class DiscountListScreen extends StatefulWidget {
  const DiscountListScreen({super.key});

  @override
  State<DiscountListScreen> createState() => _DiscountListScreenState();
}

class _DiscountListScreenState extends State<DiscountListScreen> {
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

  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late Map<String, double> _columnWidths = {
    'no': 100,
    'id': 100,
    'nama': 300,
    'percentage': 150,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _discounts = [];
  late DiscountDataSource _dataSource;

  int _totalFilteredDiscounts = 0;
  double _totalPercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  Future<void> _loadDiscounts() async {
    setState(() => _isLoading = true);
    try {
      final discounts = await DiscountService.getDiscounts();
      setState(() {
        _discounts = discounts;
        _calculateTotals(discounts);
        _dataSource = DiscountDataSource(
          discounts: discounts,
          onEdit: _openEditDiscount,
          onDelete: _deleteDiscount,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data discount', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> discounts) {
    _totalFilteredDiscounts = discounts.length;
    _totalPercentage = discounts.fold(0.0, (sum, disc) => sum + (double.tryParse(disc['disc_persen']?.toString() ?? '0') ?? 0));
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
          _totalFilteredDiscounts = filteredData.length;
          _totalPercentage = filteredData.fold(0.0, (sum, disc) => sum + (double.tryParse(disc['disc_persen']?.toString() ?? '0') ?? 0));
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

  void _openAddDiscount() {
    Navigator.pushNamed(context, AppRoutes.discountForm, arguments: {'onSaved': _loadDiscounts});
  }

  void _openEditDiscount(Map<String, dynamic> discount) {
    Navigator.pushNamed(context, AppRoutes.discountForm, arguments: {'discount': discount, 'onSaved': _loadDiscounts});
  }

  void _deleteDiscount(Map<String, dynamic> discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Discount', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${discount['disc_nama']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(discount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> discount) async {
    setState(() => _isLoading = true);
    try {
      final result = await DiscountService.deleteDiscount(discount['disc_id'].toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadDiscounts();
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
      sheet.name = 'Data Discount';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 10;
      sheet.getRangeByIndex(1, 3).columnWidth = 35;
      sheet.getRangeByIndex(1, 4).columnWidth = 15;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 4);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('ID');
      sheet.getRangeByName('C1').setText('Nama Discount');
      sheet.getRangeByName('D1').setText('Diskon %');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();
        String no = '', id = '', nama = '';
        double percentage = 0;
        for (var cell in cells) {
          if (cell.columnName == 'no') no = cell.value.toString();
          else if (cell.columnName == 'id') id = cell.value.toString();
          else if (cell.columnName == 'nama') nama = cell.value.toString();
          else if (cell.columnName == 'percentage') percentage = cell.value as double;
        }
        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(id);
        sheet.getRangeByName('C$rowIndex').setText(nama);
        sheet.getRangeByName('D$rowIndex').setNumber(percentage);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
        dataRange.cellStyle.fontSize = 9;
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.right;
        if (rowIndex % 2 == 0) dataRange.cellStyle.backColor = '#F8FAFC';
        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredDiscounts Discount');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').setText('Total Diskon:');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('D$totalRow').setNumber(_totalPercentage);
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('D$totalRow').cellStyle.fontColor = '#F6A918';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Discount_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Discount_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
      title: 'Discount',
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
                  _buildActionButton(icon: Icons.add, label: isMobile ? 'Tambah' : 'Tambah Discount', color: _primaryDark, onPressed: _openAddDiscount, isMobile: isMobile),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _discounts.isEmpty
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
                              _buildGridColumn('id', 'ID', width: _columnWidths['id'], alignment: Alignment.center),
                              _buildGridColumn('nama', 'Nama Discount', width: _columnWidths['nama']),
                              _buildGridColumn('percentage', 'Diskon %', width: _columnWidths['percentage'], alignment: Alignment.centerRight),
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
                                const Icon(Icons.discount_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$_totalFilteredDiscounts Discount', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            Text('Total Diskon: ${_numberFormat.format(_totalPercentage)}%', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentGold)),
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
          Container(width: 64, height: 64, decoration: BoxDecoration(color: _bgLight, shape: BoxShape.circle), child: Icon(Icons.discount_outlined, size: 28, color: _textTertiary)),
          const SizedBox(height: 16),
          Text('Belum ada data discount', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah Discount" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class DiscountDataSource extends DataGridSource {
  DiscountDataSource({
    required List<Map<String, dynamic>> discounts,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _updateDataSource(discounts);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit, _onDelete;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _primaryDark = Color(0xFF2C3E50);

  void _updateDataSource(List<Map<String, dynamic>> discounts) {
    _data = discounts.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final discount = entry.value;
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'id', value: discount['disc_id']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'nama', value: discount['disc_nama']?.toString() ?? '-'),
        DataGridCell<double>(columnName: 'percentage', value: double.tryParse(discount['disc_persen']?.toString() ?? '0') ?? 0),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: discount),
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
          final discount = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(discount), color: _primaryDark),
                const SizedBox(width: 4),
                _buildIconButton(Icons.delete_outlined, () => _onDelete(discount), color: _accentRed),
              ],
            ),
          );
        }
        if (cell.columnName == 'percentage') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(value > 0 ? '${value.toStringAsFixed(0)}%' : '-', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal, color: value > 0 ? _accentGold : _textPrimary)),
          );
        }
        Color textColor = _textPrimary;
        if (cell.columnName == 'no' || cell.columnName == 'id') textColor = _textSecondary;
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
    if (columnName == 'percentage') return Alignment.centerRight;
    if (columnName == 'aksi' || columnName == 'no' || columnName == 'id') return Alignment.center;
    return Alignment.centerLeft;
  }
}