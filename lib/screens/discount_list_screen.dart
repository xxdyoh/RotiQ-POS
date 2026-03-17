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

  // Warna konsisten dengan screen lainnya
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
    'id': 100,
    'nama': 250,
    'percentage': 120,
    'aksi': 100,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _discounts = [];
  late DiscountDataSource _dataSource;

  int _totalFilteredDiscounts = 0;
  double _totalPercentage = 0;

  final NumberFormat _numberFormat = NumberFormat('#,##0');

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
          primaryDark: _primaryDark,
          accentGold: _accentGold,
          accentCoral: _accentCoral,
          borderColor: _borderColor,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data discount: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> discounts) {
    _totalFilteredDiscounts = discounts.length;
    _totalPercentage = discounts.fold(0.0, (sum, disc) {
      return sum + (double.tryParse(disc['disc_persen']?.toString() ?? '0') ?? 0);
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
          _totalFilteredDiscounts = filteredData.length;
          _totalPercentage = filteredData.fold(0.0, (sum, disc) {
            return sum + (double.tryParse(disc['disc_persen']?.toString() ?? '0') ?? 0);
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

  void _openAddDiscount() {
    Navigator.pushNamed(
      context,
      AppRoutes.discountForm,
      arguments: {
        'onSaved': _loadDiscounts,
      },
    );
  }

  void _openEditDiscount(Map<String, dynamic> discount) {
    Navigator.pushNamed(
      context,
      AppRoutes.discountForm,
      arguments: {
        'discount': discount,
        'onSaved': _loadDiscounts,
      },
    );
  }

  void _deleteDiscount(Map<String, dynamic> discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _accentCoral, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Discount?', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${discount['disc_nama']}"?',
            style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(discount);
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

  Future<void> _performDelete(Map<String, dynamic> discount) async {
    setState(() => _isLoading = true);
    try {
      final result = await DiscountService.deleteDiscount(discount['disc_id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadDiscounts();
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
      sheet.name = 'Data Discount';

      // Set column widths
      sheet.getRangeByIndex(1, 1).columnWidth = 8;   // No
      sheet.getRangeByIndex(1, 2).columnWidth = 10;  // ID
      sheet.getRangeByIndex(1, 3).columnWidth = 35;  // Nama
      sheet.getRangeByIndex(1, 4).columnWidth = 15;  // Diskon %

      // Header style
      final headerRange = sheet.getRangeByIndex(1, 1, 1, 4);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 11;

      // Headers
      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('ID');
      sheet.getRangeByName('C1').setText('Nama Discount');
      sheet.getRangeByName('D1').setText('Diskon %');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String id = '';
        String nama = '';
        double percentage = 0;

        for (var cell in cells) {
          if (cell.columnName == 'no') {
            no = cell.value.toString();
          } else if (cell.columnName == 'id') {
            id = cell.value.toString();
          } else if (cell.columnName == 'nama') {
            nama = cell.value.toString();
          } else if (cell.columnName == 'percentage') {
            percentage = cell.value as double;
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(id);
        sheet.getRangeByName('C$rowIndex').setText(nama);
        sheet.getRangeByName('D$rowIndex').setNumber(percentage);

        // Style for data rows
        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
        dataRange.cellStyle.fontSize = 10;
        dataRange.cellStyle.vAlign = VAlignType.center;

        // Alignment
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.right;

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

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredDiscounts Discount');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('B$totalRow').cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByName('C$totalRow').setText('Total Diskon:');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('C$totalRow').cellStyle.hAlign = HAlignType.right;

      sheet.getRangeByName('D$totalRow').setNumber(_totalPercentage);
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('D$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('D$totalRow').cellStyle.fontColor = '#F6A918';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.right;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Discount_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Discount_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
      title: 'Discount',
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
                    onPressed: _openAddDiscount,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      isMobile ? 'Tambah' : 'Tambah Discount',
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
                    'Memuat data discount...',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : _discounts.isEmpty
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
                      Icons.discount_outlined,
                      size: 35,
                      color: _textSecondary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada data discount',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Klik tombol Tambah Discount untuk memulai',
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
                              columnName: 'id',
                              width: _columnWidths['id'] ?? 100,
                              minimumWidth: 80,
                              maximumWidth: 120,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'ID',
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
                              minimumWidth: 200,
                              maximumWidth: 350,
                              label: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  'Nama Discount',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            GridColumn(
                              columnName: 'percentage',
                              width: _columnWidths['percentage'] ?? 120,
                              minimumWidth: 100,
                              maximumWidth: 150,
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
                                width: _columnWidths['id'] ?? 100,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: Text(
                                  '$_totalFilteredDiscounts',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryDark,
                                  ),
                                ),
                              ),
                              Container(
                                width: _columnWidths['nama'] ?? 250,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Icon(Icons.discount, size: 11, color: _primaryDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_totalFilteredDiscounts Discount',
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
                                width: _columnWidths['percentage'] ?? 120,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${_numberFormat.format(_totalPercentage)}%',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _accentGold,
                                  ),
                                ),
                              ),
                              Container(
                                width: _columnWidths['aksi'] ?? 100,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.center,
                                child: _totalFilteredDiscounts < _discounts.length
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_discounts.length - _totalFilteredDiscounts} filter',
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

class DiscountDataSource extends DataGridSource {
  DiscountDataSource({
    required List<Map<String, dynamic>> discounts,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required Color primaryDark,
    required Color accentGold,
    required Color accentCoral,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _primaryDark = primaryDark;
    _accentGold = accentGold;
    _accentCoral = accentCoral;
    _borderColor = borderColor;
    _textPrimary = textPrimary;
    _textSecondary = textSecondary;

    _originalDiscounts = discounts;
    _updateDataSource(discounts);
  }

  List<Map<String, dynamic>> _originalDiscounts = [];
  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late Color _primaryDark;
  late Color _accentGold;
  late Color _accentCoral;
  late Color _borderColor;
  late Color _textPrimary;
  late Color _textSecondary;

  void _updateDataSource(List<Map<String, dynamic>> discounts) {
    _data = discounts.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final discount = entry.value;

      final id = discount['disc_id']?.toString() ?? '-';
      final name = discount['disc_nama']?.toString() ?? '-';
      final percentage = double.tryParse(discount['disc_persen']?.toString() ?? '0') ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'id', value: id),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<double>(columnName: 'percentage', value: percentage),
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
                    onPressed: () => _onEdit(discount),
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
                    onPressed: () => _onDelete(discount),
                    padding: EdgeInsets.zero,
                    iconSize: 12,
                    tooltip: 'Hapus',
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'percentage') {
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

        Color textColor = _textPrimary;
        if (cell.columnName == 'no' || cell.columnName == 'id') {
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
      case 'percentage':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'percentage':
        return TextAlign.right;
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }
}