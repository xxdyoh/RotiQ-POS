import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:pivot_table/pivot_table.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../services/sales_item_service.dart';
import '../models/sales_item.dart';
import '../widgets/base_layout.dart';
import '../utils/responsive_helper.dart';

class SalesByItemScreen extends StatefulWidget {
  const SalesByItemScreen({super.key});

  @override
  State<SalesByItemScreen> createState() => _SalesByItemScreenState();
}

class _SalesByItemScreenState extends State<SalesByItemScreen> with TickerProviderStateMixin {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<SalesItem> _salesItems = [];
  bool _isLoading = false;
  bool _showDateFilter = false;
  String? _error;
  late SalesItemDataSource _dataSource;

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
  final Color _accentSkySoft = const Color(0xFF4CC9F0).withOpacity(0.1);

  late Map<String, double> _columnWidths = {
    'no': 70,
    'bulan': 90,
    'tahun': 100,
    'nomor': 140,
    'tanggal': 100,
    'nama': 200,
    'varian': 100,
    'salesType': 120,
    'qty': 100,
    'nilai': 150,
    'served': 120,
    'category': 120,
    'kasir': 120,
  };

  int _totalFilteredQty = 0;
  double _totalFilteredNilai = 0;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month, 1);
    _dataSource = SalesItemDataSource(
      items: [],
      currencyFormat: _currencyFormat,
      numberFormat: _numberFormat,
      onFilterChanged: _onFilterChanged,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SalesItemService.getSalesByItem(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        final items = data.map((json) => SalesItem.fromJson(json)).toList();

        setState(() {
          _salesItems = items;
          _calculateTotals(items);
          _dataSource = SalesItemDataSource(
            items: items,
            currencyFormat: _currencyFormat,
            numberFormat: _numberFormat,
            onFilterChanged: _onFilterChanged,
          );
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Gagal memuat data';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleDateFilter() {
    setState(() {
      _showDateFilter = !_showDateFilter;
    });
  }

  void _calculateTotals(List<SalesItem> items) {
    _totalFilteredQty = items.fold<int>(0, (sum, item) => sum + item.qty);
    _totalFilteredNilai = items.fold<double>(0, (sum, item) => sum + item.nilai);
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        final filteredRows = _dataSource.effectiveRows!;

        int totalQty = 0;
        double totalNilai = 0;

        for (var row in filteredRows) {
          final cells = row.getCells();
          for (var cell in cells) {
            if (cell.columnName == 'qty' && cell.value != null) {
              totalQty += cell.value as int;
            } else if (cell.columnName == 'nilai' && cell.value != null) {
              totalNilai += cell.value as double;
            }
          }
        }

        setState(() {
          _totalFilteredQty = totalQty;
          _totalFilteredNilai = totalNilai;
        });
      }
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, // Gunakan context dari parameter
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: _surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: _surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    final num value = amount is int ? amount : (amount ?? 0);
    return _currencyFormat.format(value);
  }

  String _convertToPivotJson() {
    final List<Map<String, dynamic>> data = [];
    for (var item in _salesItems) {
      data.add({
        'bulan': item.bulan.toString(),
        'tahun': item.tahun.toString(),
        'nomor': item.nomor,
        'tanggal': DateFormat('yyyy-MM-dd').format(item.tanggal),
        'nama': item.nama,
        'varian': item.varrian,
        'salesType': item.salesType,
        'qty': item.qty,
        'nilai': item.nilai,
        'served': item.served,
        'category': item.category,
        'kasir': item.kasir,
      });
    }
    return jsonEncode(data);
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                type == ToastType.success ? Icons.check_circle_rounded :
                type == ToastType.error ? Icons.error_rounded :
                Icons.info_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral :
        _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final currentState = _key.currentState;
      if (currentState == null) return;

      final visibleRows = _dataSource.rows;

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Sales by Item';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 9;
      sheet.getRangeByIndex(1, 3).columnWidth = 10;
      sheet.getRangeByIndex(1, 4).columnWidth = 14;
      sheet.getRangeByIndex(1, 5).columnWidth = 10;
      sheet.getRangeByIndex(1, 6).columnWidth = 20;
      sheet.getRangeByIndex(1, 7).columnWidth = 10;
      sheet.getRangeByIndex(1, 8).columnWidth = 12;
      sheet.getRangeByIndex(1, 9).columnWidth = 10;
      sheet.getRangeByIndex(1, 10).columnWidth = 15;
      sheet.getRangeByIndex(1, 11).columnWidth = 12;
      sheet.getRangeByIndex(1, 12).columnWidth = 12;
      sheet.getRangeByIndex(1, 13).columnWidth = 12;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 13);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Bulan');
      sheet.getRangeByName('C1').setText('Tahun');
      sheet.getRangeByName('D1').setText('Nomor');
      sheet.getRangeByName('E1').setText('Tanggal');
      sheet.getRangeByName('F1').setText('Nama Item');
      sheet.getRangeByName('G1').setText('Varian');
      sheet.getRangeByName('H1').setText('Sales Type');
      sheet.getRangeByName('I1').setText('Qty');
      sheet.getRangeByName('J1').setText('Nilai');
      sheet.getRangeByName('K1').setText('Served');
      sheet.getRangeByName('L1').setText('Category');
      sheet.getRangeByName('M1').setText('Kasir');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String bulan = '';
        String tahun = '';
        String nomor = '';
        String tanggal = '';
        String nama = '';
        String varian = '';
        String salesType = '';
        String qty = '';
        String nilai = '';
        String served = '';
        String category = '';
        String kasir = '';

        for (var cell in cells) {
          switch (cell.columnName) {
            case 'no': no = cell.value.toString(); break;
            case 'bulan': bulan = cell.value.toString(); break;
            case 'tahun': tahun = cell.value.toString(); break;
            case 'nomor': nomor = cell.value.toString(); break;
            case 'tanggal': tanggal = cell.value.toString(); break;
            case 'nama': nama = cell.value.toString(); break;
            case 'varian': varian = cell.value.toString(); break;
            case 'salesType': salesType = cell.value.toString(); break;
            case 'qty': qty = cell.value.toString(); break;
            case 'nilai': nilai = cell.value.toString(); break;
            case 'served': served = cell.value.toString(); break;
            case 'category': category = cell.value.toString(); break;
            case 'kasir': kasir = cell.value.toString(); break;
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(bulan);
        sheet.getRangeByName('C$rowIndex').setText(tahun);
        sheet.getRangeByName('D$rowIndex').setText(nomor);
        sheet.getRangeByName('E$rowIndex').setText(tanggal);
        sheet.getRangeByName('F$rowIndex').setText(nama);
        sheet.getRangeByName('G$rowIndex').setText(varian);
        sheet.getRangeByName('H$rowIndex').setText(salesType);
        sheet.getRangeByName('I$rowIndex').setText(qty);
        sheet.getRangeByName('J$rowIndex').setText(nilai);
        sheet.getRangeByName('K$rowIndex').setText(served);
        sheet.getRangeByName('L$rowIndex').setText(category);
        sheet.getRangeByName('M$rowIndex').setText(kasir);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 13);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('G$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('H$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('I$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('J$rowIndex').cellStyle.hAlign = HAlignType.right;
        sheet.getRangeByName('K$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('L$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('M$rowIndex').cellStyle.hAlign = HAlignType.left;

        if (rowIndex % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8F9FA';
        }

        rowIndex++;
      }

      final totalRow = rowIndex + 1;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('A$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('H$totalRow').setText('Total Qty:');
      sheet.getRangeByName('H$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('H$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('H$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('I$totalRow').setText(_numberFormat.format(_totalFilteredQty));
      sheet.getRangeByName('I$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('I$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('I$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('I$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('J$totalRow').setText(_currencyFormat.format(_totalFilteredNilai));
      sheet.getRangeByName('J$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('J$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('J$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('J$totalRow').cellStyle.fontSize = 9;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Sales_by_Item_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showToast('File Excel berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Sales_by_Item_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      print('Error export Excel: $e');
      _showToast('Gagal export Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  Future<void> _exportPivotToExcel() async {
    try {
      if (_salesItems.isEmpty) {
        _showToast('Tidak ada data untuk di-export', type: ToastType.error);
        return;
      }

      final jsonData = _convertToPivotJson();
      final data = jsonDecode(jsonData) as List;

      // Kelompokkan data berdasarkan kategori dan nama item
      Map<String, Map<String, double>> pivotData = {};
      Set<String> categories = {};
      Set<String> itemNames = {};

      for (var item in data) {
        String category = item['category'] ?? '-';
        String nama = item['nama'] ?? '-';
        double nilai = (item['nilai'] ?? 0).toDouble();

        categories.add(category);
        itemNames.add(nama);

        if (!pivotData.containsKey(nama)) {
          pivotData[nama] = {};
        }
        pivotData[nama]![category] = (pivotData[nama]![category] ?? 0) + nilai;
      }

      // Urutkan categories dan itemNames
      List<String> sortedCategories = categories.toList()..sort();
      List<String> sortedItemNames = itemNames.toList()..sort();

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Pivot Sales by Item';

      // Set column widths
      sheet.getRangeByIndex(1, 1).columnWidth = 30; // Nama Item
      int colIndex = 2;
      for (var category in sortedCategories) {
        sheet.getRangeByIndex(1, colIndex).columnWidth = 15;
        colIndex++;
      }
      sheet.getRangeByIndex(1, colIndex).columnWidth = 15; // Total

      // Header style
      final headerRange = sheet.getRangeByIndex(1, 1, 1, colIndex);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      // Headers
      sheet.getRangeByName('A1').setText('Nama Item');
      colIndex = 2;
      for (var category in sortedCategories) {
        sheet.getRangeByIndex(1, colIndex).setText(category);
        colIndex++;
      }
      sheet.getRangeByIndex(1, colIndex).setText('Total');

      // Data rows
      int rowIndex = 2;
      for (var itemName in sortedItemNames) {
        // Nama Item
        sheet.getRangeByName('A$rowIndex').setText(itemName);
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.left;

        double totalRow = 0;
        colIndex = 2;

        for (var category in sortedCategories) {
          double nilai = pivotData[itemName]?[category] ?? 0;
          totalRow += nilai;

          var cell = sheet.getRangeByIndex(rowIndex, colIndex);
          cell.setNumber(nilai);
          cell.cellStyle.hAlign = HAlignType.right;
          cell.cellStyle.numberFormat = '#,##0';
          colIndex++;
        }

        // Total per row
        var totalCell = sheet.getRangeByIndex(rowIndex, colIndex);
        totalCell.setNumber(totalRow);
        totalCell.cellStyle.hAlign = HAlignType.right;
        totalCell.cellStyle.bold = true;
        totalCell.cellStyle.numberFormat = '#,##0';

        // Style untuk data row
        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, colIndex);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        if (rowIndex % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8F9FA';
        }

        rowIndex++;
      }

      // Total column
      int totalRowIndex = rowIndex;
      sheet.getRangeByName('A$totalRowIndex').setText('TOTAL');
      sheet.getRangeByName('A$totalRowIndex').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRowIndex').cellStyle.backColor = '#E9ECEF';

      colIndex = 2;
      double grandTotal = 0;
      for (var category in sortedCategories) {
        double totalCategory = 0;
        for (var itemName in sortedItemNames) {
          totalCategory += pivotData[itemName]?[category] ?? 0;
        }
        grandTotal += totalCategory;

        var cell = sheet.getRangeByIndex(totalRowIndex, colIndex);
        cell.setNumber(totalCategory);
        cell.cellStyle.hAlign = HAlignType.right;
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#E9ECEF';
        cell.cellStyle.numberFormat = '#,##0';
        colIndex++;
      }

      // Grand total
      var grandTotalCell = sheet.getRangeByIndex(totalRowIndex, colIndex);
      grandTotalCell.setNumber(grandTotal);
      grandTotalCell.cellStyle.hAlign = HAlignType.right;
      grandTotalCell.cellStyle.bold = true;
      grandTotalCell.cellStyle.backColor = '#E9ECEF';
      grandTotalCell.cellStyle.numberFormat = '#,##0';

      // Info periode
      int infoRow = totalRowIndex + 2;
      sheet.getRangeByName('A$infoRow').setText('Periode:');
      sheet.getRangeByName('A$infoRow').cellStyle.bold = true;
      sheet.getRangeByName('B$infoRow').setText(
          '${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}'
      );

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Pivot_Sales_by_Item_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showToast('File Excel Pivot berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Pivot_Sales_by_Item_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel Pivot berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      print('Error export Pivot Excel: $e');
      _showToast('Gagal export Pivot Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Sales by Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: _bgSoft,
          child: Column(
            children: [
              // Header dengan filter periode (selalu ditampilkan)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceWhite,
                  border: Border(bottom: BorderSide(color: _borderSoft)),
                ),
                child: Row(
                  children: [
                    // Label Periode

                    // Tanggal Mulai
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _bgSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: _accentGold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tanggal Mulai',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        color: _textLight,
                                      ),
                                    ),
                                    Text(
                                      _startDate != null ? _displayDateFormat.format(_startDate!) : '-',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Tanggal Selesai
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _bgSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: _accentGold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tanggal Selesai',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        color: _textLight,
                                      ),
                                    ),
                                    Text(
                                      _endDate != null ? _displayDateFormat.format(_endDate!) : '-',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Load Button
                    Container(
                      width: 90,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accentMint, _accentMint.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _accentMint.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _loadData,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Load',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Export Excel Button
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accentGold, _accentGold.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _accentGold.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _salesItems.isEmpty ? null :
                          (_tabController.index == 0 ? _exportToExcel : _exportPivotToExcel),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.table_chart, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Export Excel',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
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
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grid_on, size: 16),
                          SizedBox(width: 4),
                          Text('DATA GRID'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pivot_table_chart, size: 16),
                          SizedBox(width: 4),
                          Text('PIVOT'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Konten (DataGrid atau Pivot)
              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: _accentGold,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Memuat data...',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textMedium,
                        ),
                      ),
                    ],
                  ),
                )
                    : _error != null
                    ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accentCoralSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.error_outline, size: 32, color: _accentCoral),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Terjadi Kesalahan',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: _textMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_accentMint, _accentMint.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _loadData,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh, size: 14, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'COBA LAGI',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDataGridView(screenWidth, isTablet),
                    _buildPivotView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap, // Ini akan menggunakan context dari parent
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderSoft),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: _accentGold),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null ? _displayDateFormat.format(date) : 'Pilih',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: date != null ? _textDark : _textLight,
                  fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGridView(double screenWidth, bool isTablet) {
    if (_salesItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _bgSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 35,
                color: _textLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada data untuk ditampilkan',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih periode dan klik Load',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: _textLight,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderSoft),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
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
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
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
                  rowHeight: 32,
                  allowSorting: true,
                  allowFiltering: true,
                  onFilterChanged: _onFilterChanged,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  selectionMode: SelectionMode.none,
                  columns: [
                    GridColumn(
                      columnName: 'no',
                      width: _columnWidths['no'] ?? 70,
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
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'bulan',
                      width: _columnWidths['bulan'] ?? 90,
                      minimumWidth: 80,
                      maximumWidth: 120,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Bulan',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'tahun',
                      width: _columnWidths['tahun'] ?? 100,
                      minimumWidth: 90,
                      maximumWidth: 130,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Tahun',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'nomor',
                      width: _columnWidths['nomor'] ?? 140,
                      minimumWidth: 130,
                      maximumWidth: 200,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Nomor',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'tanggal',
                      width: _columnWidths['tanggal'] ?? 100,
                      minimumWidth: 90,
                      maximumWidth: 130,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Tanggal',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
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
                          'Nama Item',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'varian',
                      width: _columnWidths['varian'] ?? 100,
                      minimumWidth: 90,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Varian',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'salesType',
                      width: _columnWidths['salesType'] ?? 120,
                      minimumWidth: 110,
                      maximumWidth: 160,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Sales Type',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'qty',
                      width: _columnWidths['qty'] ?? 100,
                      minimumWidth: 90,
                      maximumWidth: 130,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Qty',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'nilai',
                      width: _columnWidths['nilai'] ?? 150,
                      minimumWidth: 140,
                      maximumWidth: 200,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Nilai',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'served',
                      width: _columnWidths['served'] ?? 120,
                      minimumWidth: 110,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Served',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'category',
                      width: _columnWidths['category'] ?? 120,
                      minimumWidth: 110,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Category',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'kasir',
                      width: _columnWidths['kasir'] ?? 120,
                      minimumWidth: 110,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Kasir',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer Total Manual - TETAP DIPERTAHANKAN
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: _bgSoft,
                border: Border(
                  top: BorderSide(color: _borderSoft),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: screenWidth - 40,
                  child: Row(
                    children: [
                      Container(
                        width: _columnWidths['no'] ?? 70,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        child: Text(
                          'Total',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                      Container(
                        width: (_columnWidths['bulan'] ?? 90) +
                            (_columnWidths['tahun'] ?? 100) +
                            (_columnWidths['nomor'] ?? 140) +
                            (_columnWidths['tanggal'] ?? 100) +
                            (_columnWidths['nama'] ?? 200) +
                            (_columnWidths['varian'] ?? 100) +
                            (_columnWidths['salesType'] ?? 120),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Periode: ${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: _textDark,
                          ),
                        ),
                      ),
                      Container(
                        width: _columnWidths['qty'] ?? 100,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerRight,
                        child: Text(
                          _numberFormat.format(_totalFilteredQty),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accentGold,
                          ),
                        ),
                      ),
                      Container(
                        width: _columnWidths['nilai'] ?? 150,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currencyFormat.format(_totalFilteredNilai),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accentGold,
                          ),
                        ),
                      ),
                      Container(
                        width: (_columnWidths['served'] ?? 120) +
                            (_columnWidths['category'] ?? 120) +
                            (_columnWidths['kasir'] ?? 120),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
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
    );
  }

  Widget _buildPivotView() {
    if (_salesItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _bgSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pivot_table_chart,
                size: 35,
                color: _textLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada data untuk pivot table',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih periode dan klik Load',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: _textLight,
              ),
            ),
          ],
        ),
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
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header info dengan tombol export
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _bgSoft,
                border: Border(
                  bottom: BorderSide(color: _borderSoft),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _accentGoldSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.info_outline, size: 12, color: _accentGold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rows: Nama Item | Columns: Category',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _textMedium,
                      ),
                    ),
                  ),
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentMint, _accentMint.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _accentMint.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _exportPivotToExcel,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_chart, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Export',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Pivot Table dengan Listener
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {},
                child: PivotTable(
                  jsonData: jsonData,
                  hiddenAttributes: const [],
                  cols: const ['category'],
                  rows: const ['nama'],
                  aggregatorName: AggregatorName.sum,
                  vals: const ['nilai'],
                  marginLabel: 'Total',
                  rendererName: RendererName.table,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _accentCoralSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentCoral.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: _accentCoral, size: 32),
              const SizedBox(height: 8),
              Text(
                'Error: ${e.toString()}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _accentCoral,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}

class SalesItemDataSource extends DataGridSource {
  SalesItemDataSource({
    required List<SalesItem> items,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
    required Function(DataGridFilterChangeDetails) onFilterChanged,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;
    _onFilterChanged = onFilterChanged;
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
        DataGridCell<String>(columnName: 'varian', value: item.varrian),
        DataGridCell<String>(columnName: 'salesType', value: item.salesType),
        DataGridCell<int>(columnName: 'qty', value: item.qty),
        DataGridCell<double>(columnName: 'nilai', value: item.nilai.toDouble()),
        DataGridCell<String>(columnName: 'served', value: item.served),
        DataGridCell<String>(columnName: 'category', value: item.category),
        DataGridCell<String>(columnName: 'kasir', value: item.kasir),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _currencyFormat;
  late NumberFormat _numberFormat;
  late Function(DataGridFilterChangeDetails) _onFilterChanged;

  @override
  List<DataGridRow> get rows => _data;

  @override
  Future<void> handleFilterChange(DataGridFilterChangeDetails details) async {
    _onFilterChanged(details);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'nilai') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _currencyFormat.format(cell.value),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF6A918),
              ),
            ),
          );
        }

        if (cell.columnName == 'qty') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _numberFormat.format(cell.value),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          );
        }

        Color textColor = Colors.black87;
        if (cell.columnName == 'no' || cell.columnName == 'tanggal') {
          textColor = const Color(0xFF718096);
        }

        return Container(
          alignment: cell.columnName == 'no' ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.normal,
              color: textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum ToastType { success, error, info }