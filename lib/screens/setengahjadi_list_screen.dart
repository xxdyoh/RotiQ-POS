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
import '../services/setengahjadi_service.dart';
import '../models/setengahjadi.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class SetengahJadiListScreen extends StatefulWidget {
  const SetengahJadiListScreen({super.key});

  @override
  State<SetengahJadiListScreen> createState() => _SetengahJadiListScreenState();
}

class _SetengahJadiListScreenState extends State<SetengahJadiListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Color Palette - Minimalis
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);

  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late Map<String, double> _columnWidths = {
    'no': 60,
    'nama': 300,
    'stok': 120,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<SetengahJadi> _items = [];
  late SetengahJadiDataSource _dataSource;

  int _totalFilteredItems = 0;
  double _totalFilteredStock = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await SetengahJadiService.getSetengahJadi();
      setState(() {
        _items = items;
        _calculateTotals(items);
        _dataSource = SetengahJadiDataSource(
          items: items,
          onEdit: _openEditSetengahJadi,
          onDelete: _deleteSetengahJadi,
          numberFormat: _numberFormat,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<SetengahJadi> items) {
    _totalFilteredItems = items.length;
    _totalFilteredStock = items.fold(0.0, (sum, item) => sum + item.stjStock);
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        final filteredRows = _dataSource.effectiveRows!;
        setState(() {
          _totalFilteredItems = filteredRows.length;
          _totalFilteredStock = filteredRows.fold(0.0, (sum, row) {
            final cells = row.getCells();
            for (var cell in cells) {
              if (cell.columnName == 'stok') {
                return sum + (cell.value as double);
              }
            }
            return sum;
          });
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

  void _openAddSetengahJadi() {
    Navigator.pushNamed(
      context,
      AppRoutes.setengahJadiForm,
      arguments: {'onSaved': _loadData},
    );
  }

  void _openEditSetengahJadi(SetengahJadi item) {
    Navigator.pushNamed(
      context,
      AppRoutes.setengahJadiForm,
      arguments: {
        'setengahJadi': item,
        'onSaved': _loadData,
      },
    );
  }

  void _deleteSetengahJadi(SetengahJadi item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Setengah Jadi', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${item.stjNama}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(SetengahJadi item) async {
    setState(() => _isLoading = true);
    try {
      final result = await SetengahJadiService.deleteSetengahJadi(item.stjId.toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadData();
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
      sheet.name = 'Data Setengah Jadi';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 35;
      sheet.getRangeByIndex(1, 3).columnWidth = 12;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 3);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama Setengah Jadi');
      sheet.getRangeByName('C1').setText('Stok');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();
        String no = '', nama = '', stok = '';
        for (var cell in cells) {
          if (cell.columnName == 'no') no = cell.value.toString();
          else if (cell.columnName == 'nama') nama = cell.value.toString();
          else if (cell.columnName == 'stok') stok = cell.value.toString();
        }
        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nama);
        sheet.getRangeByName('C$rowIndex').setText(stok);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 3);
        dataRange.cellStyle.fontSize = 9;
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.center;
        if (rowIndex % 2 == 0) dataRange.cellStyle.backColor = '#F8FAFC';
        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredItems Item');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').setText('Stok: $_totalFilteredStock');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('C$totalRow').cellStyle.fontColor = '#3B82F6';

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'SetengahJadi_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/SetengahJadi_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
      title: 'Item St. Jadi',
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
                  // Export Button
                  _buildActionButton(
                    icon: Icons.download_outlined,
                    label: 'Export',
                    color: _accentBlue,
                    onPressed: _exportToExcel,
                    isMobile: isMobile,
                  ),
                  const SizedBox(width: 8),
                  // Add Button
                  _buildActionButton(
                    icon: Icons.add,
                    label: isMobile ? 'Tambah' : 'Tambah',
                    color: _primaryDark,
                    onPressed: _openAddSetengahJadi,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _items.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                padding: EdgeInsets.only(
                  left: isTablet ? 16 : 12,
                  right: isTablet ? 16 : 12,
                  bottom: isTablet ? 16 : 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor, width: 1),
                  ),
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
                              _buildGridColumn('nama', 'Nama Setengah Jadi', width: _columnWidths['nama']),
                              _buildGridColumn('stok', 'Stok', width: _columnWidths['stok'], alignment: Alignment.center),
                              _buildGridColumn('aksi', 'Aksi', width: _columnWidths['aksi'], alignment: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          border: Border(top: BorderSide(color: _borderColor)),
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textPrimary)),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$_totalFilteredItems item', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            Text('Stok: ${_numberFormat.format(_totalFilteredStock)}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500)),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isMobile,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              if (!isMobile) ...[
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
              ],
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
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: alignment,
        child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 10, color: _textSecondary)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: _bgLight, shape: BoxShape.circle),
            child: Icon(Icons.precision_manufacturing_outlined, size: 28, color: _textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada data setengah jadi', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class SetengahJadiDataSource extends DataGridSource {
  SetengahJadiDataSource({
    required List<SetengahJadi> items,
    required Function(SetengahJadi) onEdit,
    required Function(SetengahJadi) onDelete,
    required NumberFormat numberFormat,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _numberFormat = numberFormat;
    _updateDataSource(items);
  }

  List<DataGridRow> _data = [];
  late Function(SetengahJadi) _onEdit;
  late Function(SetengahJadi) _onDelete;
  late NumberFormat _numberFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _stockZero = Color(0xFFDC2626);
  static const Color _stockNormal = Color(0xFF059669);

  void _updateDataSource(List<SetengahJadi> items) {
    _data = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item.stjNama),
        DataGridCell<double>(columnName: 'stok', value: item.stjStock),
        DataGridCell<SetengahJadi>(columnName: 'aksi', value: item),
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
          final item = cell.value as SetengahJadi;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(item)),
                const SizedBox(width: 4),
                _buildIconButton(Icons.delete_outlined, () => _onDelete(item), color: _accentRed),
              ],
            ),
          );
        }

        if (cell.columnName == 'stok') {
          final stockValue = cell.value as double;
          final isZeroStock = stockValue <= 0;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _numberFormat.format(stockValue),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isZeroStock ? _stockZero : _stockNormal,
              ),
            ),
          );
        }

        Color textColor = _textPrimary;
        if (cell.columnName == 'no') textColor = _textSecondary;

        return Container(
          alignment: cell.columnName == 'no' ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: cell.columnName == 'nama' ? FontWeight.w500 : FontWeight.normal, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color ?? _textTertiary),
        ),
      ),
    );
  }
}