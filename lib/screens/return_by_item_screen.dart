import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:pivot_table/pivot_table.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../services/return_item_service.dart';
import '../models/return_item.dart';
import '../widgets/base_layout.dart';
import '../utils/responsive_helper.dart';
import '../services/session_manager.dart';

class ReturnByItemScreen extends StatefulWidget {
  const ReturnByItemScreen({super.key});

  @override
  State<ReturnByItemScreen> createState() => _ReturnByItemScreenState();
}

class _ReturnByItemScreenState extends State<ReturnByItemScreen> with TickerProviderStateMixin {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<ReturnItem> _returnItems = [];
  bool _isLoading = false;
  bool _isPusat = false;
  String? _error;
  late ReturnItemDataSource _dataSource;

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);

  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);

  late Map<String, double> _columnWidths = {
    'no': 70,
    'bulan': 90,
    'tahun': 100,
    'nomor': 140,
    'tanggal': 100,
    'nama': 220,
    'qty': 100,
    'harga': 100,
    'nilai': 150,
    'cabang': 120,
  };

  int _totalFilteredQty = 0;
  double _totalFilteredNilai = 0;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();

    final cabang = SessionManager.getCurrentCabang();
    setState(() {
      _isPusat = cabang?.kode == '00';
    });

    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month, 1);
    _dataSource = ReturnItemDataSource(
      items: [],
      currencyFormat: _currencyFormat,
      numberFormat: _numberFormat,
      isPusat: _isPusat,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataGridController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ReturnItemService.getReturnByItem(
        startDate: _startDate!,
        endDate: _endDate!,
        isPusat: _isPusat,
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        final items = data.map((json) => ReturnItem.fromJson(json)).toList();

        setState(() {
          _returnItems = items;
          _calculateTotals(items);
          _dataSource = ReturnItemDataSource(
            items: items,
            currencyFormat: _currencyFormat,
            numberFormat: _numberFormat,
            isPusat: _isPusat,
          );
        });
      } else {
        setState(() => _error = response['message'] ?? 'Gagal memuat data');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<ReturnItem> items) {
    _totalFilteredQty = items.fold<int>(0, (sum, item) => sum + item.qty);
    _totalFilteredNilai = items.fold<double>(0, (sum, item) => sum + item.nilai);
  }

  String _convertToPivotJson() {
    final List<Map<String, dynamic>> data = [];
    for (var item in _returnItems) {
      data.add({
        'bulan': item.bulan.toString(),
        'tahun': item.tahun.toString(),
        'nomor': item.nomor,
        'tanggal': DateFormat('yyyy-MM-dd').format(item.tanggal),
        'nama': item.nama,
        'qty': item.qty,
        'nilai': item.nilai,
        'cabang': item.cabang,
      });
    }
    return jsonEncode(data);
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _primaryDark, onPrimary: Colors.white),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _primaryDark, onPrimary: Colors.white),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(type == ToastType.success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white))),
          ],
        ),
        backgroundColor: type == ToastType.success ? _accentMint : _accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      if (_returnItems.isEmpty) {
        _showToast('Tidak ada data untuk di-export', type: ToastType.error);
        return;
      }

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Return by Item';

      final colCount = _isPusat ? 9 : 8;

      sheet.getRangeByIndex(1, 1).columnWidth = 6;   // No
      sheet.getRangeByIndex(1, 2).columnWidth = 9;   // Bulan
      sheet.getRangeByIndex(1, 3).columnWidth = 10;  // Tahun
      sheet.getRangeByIndex(1, 4).columnWidth = 14;  // Nomor
      sheet.getRangeByIndex(1, 5).columnWidth = 10;  // Tanggal
      sheet.getRangeByIndex(1, 6).columnWidth = 22;  // Nama Item
      sheet.getRangeByIndex(1, 7).columnWidth = 10;  // Qty
      sheet.getRangeByIndex(1, 8).columnWidth = 12;  // Harga
      sheet.getRangeByIndex(1, 9).columnWidth = 15;  // Nilai
      if (_isPusat) sheet.getRangeByIndex(1, 10).columnWidth = 12; // Cabang

      final headerRange = sheet.getRangeByIndex(1, 1, 1, colCount);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.fontSize = 10;
      headerRange.cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Bulan');
      sheet.getRangeByName('C1').setText('Tahun');
      sheet.getRangeByName('D1').setText('Nomor');
      sheet.getRangeByName('E1').setText('Tanggal');
      sheet.getRangeByName('F1').setText('Nama Item');
      sheet.getRangeByName('G1').setText('Qty');
      sheet.getRangeByName('H1').setText('Harga');
      sheet.getRangeByName('I1').setText('Nilai');
      if (_isPusat) sheet.getRangeByName('J1').setText('Cabang');

      int rowIndex = 2;
      final visibleRows = _dataSource.rows;

      for (var row in visibleRows) {
        final cells = row.getCells();
        final map = <String, String>{};
        for (var cell in cells) {
          map[cell.columnName] = cell.value?.toString() ?? '';
        }

        sheet.getRangeByName('A$rowIndex').setText(map['no'] ?? '');
        sheet.getRangeByName('B$rowIndex').setText(map['bulan'] ?? '');
        sheet.getRangeByName('C$rowIndex').setText(map['tahun'] ?? '');
        sheet.getRangeByName('D$rowIndex').setText(map['nomor'] ?? '');
        sheet.getRangeByName('E$rowIndex').setText(map['tanggal'] ?? '');
        sheet.getRangeByName('F$rowIndex').setText(map['nama'] ?? '');
        sheet.getRangeByName('G$rowIndex').setText(map['qty'] ?? '');
        sheet.getRangeByName('H$rowIndex').setText(map['harga'] ?? '');
        sheet.getRangeByName('I$rowIndex').setText(map['nilai'] ?? '');
        if (_isPusat) sheet.getRangeByName('J$rowIndex').setText(map['cabang'] ?? '');

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, colCount);
        dataRange.cellStyle.fontSize = 9;
        if (rowIndex % 2 == 0) dataRange.cellStyle.backColor = '#F8F9FA';

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('G$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('H$rowIndex').cellStyle.hAlign = HAlignType.right;

        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('A$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('G$totalRow').setText(_numberFormat.format(_totalFilteredQty));
      sheet.getRangeByName('G$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('G$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('G$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('G$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('H$totalRow').setText(_currencyFormat.format(_totalFilteredNilai));
      sheet.getRangeByName('H$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('H$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('H$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('H$totalRow').cellStyle.fontSize = 9;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final fileName = 'Return_by_Item_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName
          ..click();
        html.Url.revokeObjectUrl(url);
        _showToast('File Excel berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        _showToast('File Excel berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      _showToast('Gagal export Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  Future<void> _exportPivotToExcel() async {
    try {
      if (_returnItems.isEmpty) {
        _showToast('Tidak ada data untuk di-export', type: ToastType.error);
        return;
      }

      final jsonData = _convertToPivotJson();
      final data = jsonDecode(jsonData) as List;

      Map<String, Map<String, double>> pivotData = {};
      Set<String> cabangs = {};
      Set<String> itemNames = {};

      for (var item in data) {
        String cabang = item['cabang']?.toString() ?? '-';
        String nama = item['nama']?.toString() ?? '-';
        double nilai = (item['nilai'] ?? 0).toDouble();

        if (cabang.isEmpty) cabang = '-';
        cabangs.add(cabang);
        itemNames.add(nama);

        if (!pivotData.containsKey(nama)) {
          pivotData[nama] = {};
        }
        pivotData[nama]![cabang] = (pivotData[nama]![cabang] ?? 0) + nilai;
      }

      List<String> sortedCabangs = cabangs.toList()..sort();
      List<String> sortedItemNames = itemNames.toList()..sort();

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Pivot Return';

      sheet.getRangeByIndex(1, 1).columnWidth = 30;
      int colIndex = 2;
      for (var cabang in sortedCabangs) {
        sheet.getRangeByIndex(1, colIndex).columnWidth = 15;
        colIndex++;
      }
      sheet.getRangeByIndex(1, colIndex).columnWidth = 15;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, colIndex);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('Nama Item');
      colIndex = 2;
      for (var cabang in sortedCabangs) {
        sheet.getRangeByIndex(1, colIndex).setText(cabang);
        colIndex++;
      }
      sheet.getRangeByIndex(1, colIndex).setText('Total');

      int rowIndex = 2;
      double grandTotal = 0;

      for (var itemName in sortedItemNames) {
        sheet.getRangeByName('A$rowIndex').setText(itemName);
        double rowTotal = 0;
        colIndex = 2;

        for (var cabang in sortedCabangs) {
          double qty = pivotData[itemName]?[cabang] ?? 0;
          rowTotal += qty;
          var cell = sheet.getRangeByIndex(rowIndex, colIndex);
          cell.setNumber(qty);
          cell.cellStyle.hAlign = HAlignType.right;
          colIndex++;
        }

        var totalCell = sheet.getRangeByIndex(rowIndex, colIndex);
        totalCell.setNumber(rowTotal);
        totalCell.cellStyle.hAlign = HAlignType.right;
        totalCell.cellStyle.bold = true;
        grandTotal += rowTotal;

        if (rowIndex % 2 == 0) {
          sheet.getRangeByIndex(rowIndex, 1, rowIndex, colIndex).cellStyle.backColor = '#F8F9FA';
        }
        rowIndex++;
      }

      int totalRow = rowIndex;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#E9ECEF';

      colIndex = 2;
      for (var cabang in sortedCabangs) {
        double colTotal = 0;
        for (var itemName in sortedItemNames) {
          colTotal += pivotData[itemName]?[cabang] ?? 0;
        }
        var cell = sheet.getRangeByIndex(totalRow, colIndex);
        cell.setNumber(colTotal);
        cell.cellStyle.hAlign = HAlignType.right;
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#E9ECEF';
        colIndex++;
      }

      var grandCell = sheet.getRangeByIndex(totalRow, colIndex);
      grandCell.setNumber(grandTotal);
      grandCell.cellStyle.hAlign = HAlignType.right;
      grandCell.cellStyle.bold = true;
      grandCell.cellStyle.backColor = '#E9ECEF';

      int infoRow = totalRow + 2;
      sheet.getRangeByName('A$infoRow').setText('Periode:');
      sheet.getRangeByName('B$infoRow').setText('${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}');

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final fileName = 'Pivot_Return_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName
          ..click();
        html.Url.revokeObjectUrl(url);
        _showToast('File Excel Pivot berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        _showToast('File Excel Pivot berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      _showToast('Gagal export Pivot Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Return by Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgSoft,
        child: Column(
          children: [
            // Filter
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                border: Border(bottom: BorderSide(color: _borderSoft)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _accentGold),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Mulai', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                Text(_startDate != null ? _displayDateFormat.format(_startDate!) : '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _accentGold),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Selesai', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                Text(_endDate != null ? _displayDateFormat.format(_endDate!) : '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 90, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentMint, _accentMint.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _loadData,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Load', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentGold, _accentGold.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _returnItems.isEmpty ? null : (_tabController.index == 0 ? _exportToExcel : _exportPivotToExcel),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Icons.table_chart, size: 14, color: Colors.white),
                              if (!isMobile) ...[
                                const SizedBox(width: 6),
                                Text('Export', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: _surfaceWhite,
              child: TabBar(
                controller: _tabController,
                indicatorColor: _accentGold,
                indicatorWeight: 2,
                labelColor: _accentGold,
                unselectedLabelColor: _textMedium,
                labelStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 11),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.grid_on, size: 16), SizedBox(width: 4), Text('DATA GRID'),
                  ])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.pivot_table_chart, size: 16), SizedBox(width: 4), Text('PIVOT'),
                  ])),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _accentGold, strokeWidth: 2)),
                  const SizedBox(height: 12),
                  Text('Memuat data...', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                ]),
              )
                  : _error != null
                  ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline, size: 48, color: _accentCoral),
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.montserrat(fontSize: 12, color: _textMedium)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadData, child: Text('Coba Lagi')),
                ]),
              )
                  : _returnItems.isEmpty
                  ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 70, height: 70, decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
                      child: Icon(Icons.assignment_return_outlined, size: 35, color: _textLight)),
                  const SizedBox(height: 12),
                  Text('Tidak ada data', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                ]),
              )
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildDataGridView(screenWidth),
                  _buildPivotView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGridView(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderSoft),
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
                  onColumnResizeUpdate: (details) {
                    setState(() => _columnWidths[details.column.columnName] = details.width);
                    return true;
                  },
                  columnWidthMode: ColumnWidthMode.fill,
                  headerRowHeight: 32,
                  rowHeight: 30,
                  allowSorting: true,
                  allowFiltering: true,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  selectionMode: SelectionMode.none,
                  columns: [
                    _buildColumn('no', 'No', width: _columnWidths['no'], alignment: Alignment.center),
                    _buildColumn('bulan', 'Bulan', width: _columnWidths['bulan'], alignment: Alignment.center),
                    _buildColumn('tahun', 'Tahun', width: _columnWidths['tahun'], alignment: Alignment.center),
                    _buildColumn('nomor', 'Nomor', width: _columnWidths['nomor']),
                    _buildColumn('tanggal', 'Tanggal', width: _columnWidths['tanggal'], alignment: Alignment.center),
                    _buildColumn('nama', 'Nama Item', width: _columnWidths['nama']),
                    _buildColumn('qty', 'Qty', width: _columnWidths['qty'], alignment: Alignment.centerRight),
                    _buildColumn('harga', 'Harga', width: _columnWidths['harga'], alignment: Alignment.centerRight),
                    _buildColumn('nilai', 'Nilai', width: _columnWidths['nilai'], alignment: Alignment.centerRight),
                    if (_isPusat) _buildColumn('cabang', 'Cabang', width: _columnWidths['cabang']),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: _bgSoft,
                border: Border(top: BorderSide(color: _borderSoft)),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: screenWidth - 40,
                  child: Row(
                    children: [
                      Container(width: _columnWidths['no'] ?? 70, alignment: Alignment.center,
                          child: Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700))),
                      Container(
                        width: (_columnWidths['bulan'] ?? 90) + (_columnWidths['tahun'] ?? 100) + (_columnWidths['nomor'] ?? 140) + (_columnWidths['tanggal'] ?? 100) + (_columnWidths['nama'] ?? 220) + (_columnWidths['qty'] ?? 100) + (_columnWidths['harga'] ?? 100),                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Periode: ${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}',
                            style: GoogleFonts.montserrat(fontSize: 9)),
                      ),
                      Container(width: _columnWidths['qty'] ?? 100, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(_numberFormat.format(_totalFilteredQty),
                              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: _accentGold))),
                      Container(width: _columnWidths['nilai'] ?? 150, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(_currencyFormat.format(_totalFilteredNilai),
                              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: _accentGold))),
                      if (_isPusat) Container(width: _columnWidths['cabang'] ?? 120),
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

  Widget _buildPivotView() {
    if (_returnItems.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
              child: Icon(Icons.pivot_table_chart, size: 35, color: _textLight)),
          const SizedBox(height: 12),
          Text('Tidak ada data untuk pivot table',
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
        ]),
      );
    }

    try {
      final jsonData = _convertToPivotJson();

      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderSoft),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _bgSoft,
                border: Border(bottom: BorderSide(color: _borderSoft)),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _accentGoldSoft, borderRadius: BorderRadius.circular(4)),
                      child: Icon(Icons.info_outline, size: 12, color: _accentGold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rows: Nama Item | Columns: Cabang',
                        style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: _textMedium)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PivotTable(
                jsonData: jsonData,
                hiddenAttributes: const [],
                cols: const ['cabang'],
                rows: const ['nama'],
                aggregatorName: AggregatorName.sum,
                vals: const ['nilai'],
                marginLabel: 'Total',
                rendererName: RendererName.table,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Center(
        child: Text('Error: ${e.toString()}', style: GoogleFonts.montserrat(fontSize: 11, color: _accentCoral)),
      );
    }
  }

  GridColumn _buildColumn(String name, String label, {double? width, Alignment alignment = Alignment.centerLeft}) {
    return GridColumn(
      columnName: name,
      width: width ?? double.nan,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: alignment,
        child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
      ),
    );
  }
}

// ========== DATASOURCE ==========
class ReturnItemDataSource extends DataGridSource {
  static const Color _accentCoral = Color(0xFFFF6B6B);

  ReturnItemDataSource({
    required List<ReturnItem> items,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
    required bool isPusat,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;
    final formatDate = DateFormat('dd/MM/yy');

    _data = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<int>(columnName: 'bulan', value: item.bulan),
        DataGridCell<int>(columnName: 'tahun', value: item.tahun),
        DataGridCell<String>(columnName: 'nomor', value: item.nomor),
        DataGridCell<String>(columnName: 'tanggal', value: formatDate.format(item.tanggal)),
        DataGridCell<String>(columnName: 'nama', value: item.nama),
        DataGridCell<int>(columnName: 'qty', value: item.qty),
        DataGridCell<double>(columnName: 'harga', value: item.harga),
        DataGridCell<double>(columnName: 'nilai', value: item.nilai.toDouble()),
        if (isPusat) DataGridCell<String>(columnName: 'cabang', value: item.cabang),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _currencyFormat;
  late NumberFormat _numberFormat;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'nilai') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_currencyFormat.format(cell.value),
                style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentCoral)),
          );
        }
        if (cell.columnName == 'qty') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_numberFormat.format(cell.value),
                style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600)),
          );
        }
        if (cell.columnName == 'harga') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_currencyFormat.format(cell.value),
                style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600)),
          );
        }
        return Container(
          alignment: cell.columnName == 'no' || cell.columnName == 'bulan' || cell.columnName == 'tahun' || cell.columnName == 'tanggal' ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(cell.value.toString(), style: GoogleFonts.montserrat(fontSize: 10)),
        );
      }).toList(),
    );
  }
}

enum ToastType { success, error, info }