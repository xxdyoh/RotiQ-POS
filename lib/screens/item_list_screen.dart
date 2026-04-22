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

  // Color Palette - Minimalis & Elegan
  static const Color _primaryDark = Color(0xFF1A202C);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentOrange = Color(0xFFF59E0B);

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late Map<String, double> _columnWidths = {
    'no': 120,
    'nama': 260,
    'category': 170,
    'harga': 160,
    'stok': 140,
    'nilai': 160,
    'aksi': 180,
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
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data', isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Item', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${item['Nama']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
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

  Future<void> _performDelete(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final result = await ItemService.deleteItem(item['id'].toString());
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
      sheet.name = 'Data Item';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 30;
      sheet.getRangeByIndex(1, 3).columnWidth = 20;
      sheet.getRangeByIndex(1, 4).columnWidth = 18;
      sheet.getRangeByIndex(1, 5).columnWidth = 10;
      sheet.getRangeByIndex(1, 6).columnWidth = 20;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 6);
      headerRange.cellStyle.backColor = '#1A202C';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama Item');
      sheet.getRangeByName('C1').setText('Kategori');
      sheet.getRangeByName('D1').setText('Harga');
      sheet.getRangeByName('E1').setText('Stok');
      sheet.getRangeByName('F1').setText('Nilai Stok');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '', nama = '', kategori = '', harga = '';
        int stok = 0;
        double nilai = 0;

        for (var cell in cells) {
          if (cell.columnName == 'no') no = cell.value.toString();
          else if (cell.columnName == 'nama') nama = cell.value.toString();
          else if (cell.columnName == 'category') kategori = cell.value.toString();
          else if (cell.columnName == 'harga') harga = cell.value.toString();
          else if (cell.columnName == 'stok') stok = cell.value as int;
          else if (cell.columnName == 'nilai') nilai = cell.value as double;
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nama);
        sheet.getRangeByName('C$rowIndex').setText(kategori);
        sheet.getRangeByName('D$rowIndex').setText(harga);
        sheet.getRangeByName('E$rowIndex').setNumber(stok.toDouble());
        sheet.getRangeByName('F$rowIndex').setNumber(nilai);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 6);
        dataRange.cellStyle.fontSize = 9;

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.right;

        if (stok <= 0) {
          sheet.getRangeByName('E$rowIndex').cellStyle.fontColor = '#EF4444';
          sheet.getRangeByName('E$rowIndex').cellStyle.bold = true;
        }

        if (rowIndex % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8FAFC';
        }

        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#F1F5F9';

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredItems Item');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('C$totalRow').setText('${_categories.length} Kategori');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('D$totalRow').setText('Total Stok:');
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('E$totalRow').setNumber(_totalFilteredStock.toDouble());
      sheet.getRangeByName('E$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('E$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('E$totalRow').cellStyle.fontColor = '#3B82F6';
      sheet.getRangeByName('E$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('F$totalRow').setNumber(_totalFilteredValue);
      sheet.getRangeByName('F$totalRow').numberFormat = '"Rp "#,##0';
      sheet.getRangeByName('F$totalRow').cellStyle.backColor = '#F1F5F9';
      sheet.getRangeByName('F$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('F$totalRow').cellStyle.fontColor = '#F59E0B';
      sheet.getRangeByName('F$totalRow').cellStyle.hAlign = HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Item_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Item_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header Actions - Minimalis
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
                    label: isMobile ? 'Tambah' : 'Tambah Item',
                    color: _primaryDark,
                    onPressed: _openAddItem,
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
                              _buildGridColumn('nama', 'Nama Item', width: _columnWidths['nama']),
                              _buildGridColumn('category', 'Kategori', width: _columnWidths['category']),
                              _buildGridColumn('harga', 'Harga', width: _columnWidths['harga'], alignment: Alignment.centerRight),
                              _buildGridColumn('stok', 'Stok', width: _columnWidths['stok'], alignment: Alignment.centerRight),
                              if (!isMobile)
                                _buildGridColumn('nilai', 'Nilai', width: _columnWidths['nilai'], alignment: Alignment.centerRight),
                              _buildGridColumn('aksi', 'Aksi', width: _columnWidths['aksi'], alignment: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                      // Footer - Minimalis
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // <-- vertical 10 -> 8
                        decoration: BoxDecoration(
                          color: _bgLight,
                          border: Border(top: BorderSide(color: _borderColor)),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
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
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(Icons.category_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('${_categories.length} kategori', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            Text('Stok: ${_numberFormat.format(_totalFilteredStock)}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 16),
                            if (!isMobile)
                              Text(currencyFormat.format(_totalFilteredValue), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textPrimary)),
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
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
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
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: alignment,
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 10, // <-- Diperkecil
            color: _textSecondary,
          ),
        ),
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
            child: Icon(Icons.inventory_2_outlined, size: 28, color: _textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada data item', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah Item" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== MINIMALIS DATASOURCE ==========
// ========== MINIMALIS DATASOURCE ==========
class ItemDataSource extends DataGridSource {
  ItemDataSource({
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required NumberFormat formatCurrency,
    required NumberFormat numberFormat,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatCurrency = formatCurrency;
    _numberFormat = numberFormat;
    _updateDataSource(items);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late NumberFormat _formatCurrency;
  late NumberFormat _numberFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _stockZero = Color(0xFFDC2626);   // Merah gelap (<= 0)
  static const Color _stockNormal = Color(0xFF059669); // Hijau gelap (>= 1)
  static const Color _borderColor = Color(0xFFE2E8F0);

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
        DataGridCell<double>(columnName: 'harga', value: price),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(item)),
                const SizedBox(width: 4),
                _buildIconButton(Icons.delete_outlined, () => _onDelete(item), color: _stockZero),
              ],
            ),
          );
        }

        final stockValue = cell.columnName == 'stok' ? (cell.value as int) : 0;
        final isZeroStock = cell.columnName == 'stok' && stockValue <= 0;
        final isValue = cell.columnName == 'nilai' || cell.columnName == 'harga';

        // Warna teks
        Color textColor = _textPrimary;
        if (cell.columnName == 'no') textColor = _textSecondary;
        if (cell.columnName == 'stok') {
          textColor = isZeroStock ? _stockZero : _stockNormal;
        }

        // Font weight
        FontWeight fontWeight = FontWeight.normal;
        if (cell.columnName == 'stok' || isValue) {
          fontWeight = FontWeight.w500;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            isValue ? _formatCurrency.format(cell.value) : cell.value.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: fontWeight,
              color: textColor,
            ),
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
          padding: const EdgeInsets.all(5), // <-- sedikit diperkecil
          child: Icon(icon, size: 15, color: color ?? _textTertiary),
        ),
      ),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return Alignment.centerRight;
      case 'aksi':
      case 'no':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }
}