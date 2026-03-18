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
import '../services/minta_report_service.dart';
import '../models/minta_report_model.dart';
import '../widgets/base_layout.dart';
import '../services/spk_service.dart';

class MintaReportScreen extends StatefulWidget {
  const MintaReportScreen({super.key});

  @override
  State<MintaReportScreen> createState() => _MintaReportScreenState();
}

class _MintaReportScreenState extends State<MintaReportScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  List<MintaReportItem> _reportItems = [];
  bool _isLoading = false;
  String? _error;
  late MintaReportDataSource _dataSource;

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

  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late Map<String, double> _columnWidths = {
    'no': 60,
    'item_nama': 200,
    'cabang': 120,
    'keterangan': 250,
    'total_qty': 100,
  };

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
    _selectedDate = DateTime.now();
    _dataSource = MintaReportDataSource(items: [], numberFormat: _numberFormat);
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await MintaReportService.getMintaReport(
        selectedDate: _selectedDate!,
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'];

        List<MintaReportItem> items = [];

        for (var outerItem in data) {
          if (outerItem is List && outerItem.isNotEmpty) {
            for (var innerItem in outerItem) {
              if (innerItem is Map<String, dynamic>) {
                items.add(MintaReportItem.fromJson(innerItem));
              }
            }
            break;
          }
        }

        setState(() {
          _reportItems = items;
          _dataSource = MintaReportDataSource(items: items, numberFormat: _numberFormat);
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

  String _convertToPivotJson() {
    final List<Map<String, dynamic>> data = [];
    for (var item in _reportItems) {
      data.add({
        'item_nama': item.itemNama,
        'cabang': item.cabang,
        'keterangan': item.keterangan,
        'total_qty': item.totalQty,
      });
    }
    return jsonEncode(data);
  }

  int get _totalQty {
    return _reportItems.fold<int>(0, (sum, item) => sum + item.totalQty);
  }

  void _showCreateSpkDialog() {
    final TextEditingController keteranganController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: _surfaceWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryDark, _primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.playlist_add_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Buat SPK',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _accentGoldSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accentGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: _accentGold),
                          const SizedBox(width: 8),
                          Text(
                            'Tanggal: ${_displayDateFormat.format(_selectedDate!)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keterangan SPK',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: _bgSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderSoft),
                      ),
                      child: TextField(
                        controller: keteranganController,
                        style: GoogleFonts.montserrat(fontSize: 11, color: _textDark),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Masukkan keterangan SPK...',
                          hintStyle: GoogleFonts.montserrat(fontSize: 11, color: _textLight),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bgSoft,
                  border: Border(top: BorderSide(color: _borderSoft)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _textMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
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
                          onTap: () {
                            Navigator.pop(context);
                            _createSpk(keteranganController.text);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.save_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Buat SPK',
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSpk(String keterangan) async {
    setState(() => _isLoading = true);

    try {
      final result = await SpkService.createSpkFromMinta(
        tanggal: _apiDateFormat.format(_selectedDate!),
        keterangan: keterangan,
      );

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (_reportItems.isEmpty) {
        _showToast('Tidak ada data untuk di-export', type: ToastType.error);
        return;
      }

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Minta Report';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 30;
      sheet.getRangeByIndex(1, 3).columnWidth = 15;
      sheet.getRangeByIndex(1, 4).columnWidth = 30;
      sheet.getRangeByIndex(1, 5).columnWidth = 15;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 5);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nama Item');
      sheet.getRangeByName('C1').setText('Cabang');
      sheet.getRangeByName('D1').setText('Keterangan');
      sheet.getRangeByName('E1').setText('Total Qty');

      int rowIndex = 2;
      for (var item in _reportItems) {
        sheet.getRangeByName('A$rowIndex').setNumber(rowIndex - 1);
        sheet.getRangeByName('B$rowIndex').setText(item.itemNama);
        sheet.getRangeByName('C$rowIndex').setText(item.cabang);
        sheet.getRangeByName('D$rowIndex').setText(item.keterangan);
        sheet.getRangeByName('E$rowIndex').setNumber(item.totalQty.toDouble());

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 5);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.right;

        if ((rowIndex - 1) % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8F9FA';
        }

        rowIndex++;
      }

      final totalRow = rowIndex;
      sheet.getRangeByName('A$totalRow').setText('TOTAL');
      sheet.getRangeByName('A$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('A$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('E$totalRow').setNumber(_totalQty.toDouble());
      sheet.getRangeByName('E$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('E$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('E$totalRow').cellStyle.bold = true;
      sheet.getRangeByName('E$totalRow').cellStyle.fontSize = 9;

      final infoRow = totalRow + 2;
      sheet.getRangeByName('A$infoRow').setText('Periode:');
      sheet.getRangeByName('A$infoRow').cellStyle.bold = true;
      sheet.getRangeByName('B$infoRow').setText(_displayDateFormat.format(_selectedDate!));

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Minta_Report_${_apiDateFormat.format(_selectedDate!)}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showToast('File Excel berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Minta_Report_${_apiDateFormat.format(_selectedDate!)}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      _showToast('Gagal export Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  Future<void> _exportPivotToExcel() async {
    try {
      if (_reportItems.isEmpty) {
        _showToast('Tidak ada data untuk di-export', type: ToastType.error);
        return;
      }

      Map<String, Map<String, int>> pivotData = {};
      Set<String> cabangs = {};
      Set<String> itemNames = {};

      for (var item in _reportItems) {
        cabangs.add(item.cabang);
        itemNames.add(item.itemNama);

        if (!pivotData.containsKey(item.itemNama)) {
          pivotData[item.itemNama] = {};
        }
        pivotData[item.itemNama]![item.cabang] =
            (pivotData[item.itemNama]![item.cabang] ?? 0) + item.totalQty;
      }

      List<String> sortedCabangs = cabangs.toList()..sort();
      List<String> sortedItemNames = itemNames.toList()..sort();

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Pivot Minta Report';

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
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('Nama Item');
      colIndex = 2;
      for (var cabang in sortedCabangs) {
        sheet.getRangeByIndex(1, colIndex).setText(cabang);
        colIndex++;
      }
      sheet.getRangeByIndex(1, colIndex).setText('Total');

      int rowIndex = 2;
      for (var itemName in sortedItemNames) {
        sheet.getRangeByName('A$rowIndex').setText(itemName);
        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.left;

        int totalRow = 0;
        colIndex = 2;

        for (var cabang in sortedCabangs) {
          int qty = pivotData[itemName]?[cabang] ?? 0;
          totalRow += qty;

          var cell = sheet.getRangeByIndex(rowIndex, colIndex);
          cell.setNumber(qty.toDouble());
          cell.cellStyle.hAlign = HAlignType.right;
          colIndex++;
        }

        var totalCell = sheet.getRangeByIndex(rowIndex, colIndex);
        totalCell.setNumber(totalRow.toDouble());
        totalCell.cellStyle.hAlign = HAlignType.right;
        totalCell.cellStyle.bold = true;

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, colIndex);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        if ((rowIndex - 1) % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8F9FA';
        }

        rowIndex++;
      }

      int totalRowIndex = rowIndex;
      sheet.getRangeByName('A$totalRowIndex').setText('TOTAL');
      sheet.getRangeByName('A$totalRowIndex').cellStyle.bold = true;
      sheet.getRangeByName('A$totalRowIndex').cellStyle.backColor = '#E9ECEF';

      colIndex = 2;
      int grandTotal = 0;
      for (var cabang in sortedCabangs) {
        int totalCabang = 0;
        for (var itemName in sortedItemNames) {
          totalCabang += pivotData[itemName]?[cabang] ?? 0;
        }
        grandTotal += totalCabang;

        var cell = sheet.getRangeByIndex(totalRowIndex, colIndex);
        cell.setNumber(totalCabang.toDouble());
        cell.cellStyle.hAlign = HAlignType.right;
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#E9ECEF';
        colIndex++;
      }

      var grandTotalCell = sheet.getRangeByIndex(totalRowIndex, colIndex);
      grandTotalCell.setNumber(grandTotal.toDouble());
      grandTotalCell.cellStyle.hAlign = HAlignType.right;
      grandTotalCell.cellStyle.bold = true;
      grandTotalCell.cellStyle.backColor = '#E9ECEF';

      int infoRow = totalRowIndex + 2;
      sheet.getRangeByName('A$infoRow').setText('Periode:');
      sheet.getRangeByName('A$infoRow').cellStyle.bold = true;
      sheet.getRangeByName('B$infoRow').setText(_displayDateFormat.format(_selectedDate!));

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'Pivot_Minta_Report_${_apiDateFormat.format(_selectedDate!)}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showToast('File Excel Pivot berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/Pivot_Minta_Report_${_apiDateFormat.format(_selectedDate!)}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel Pivot berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      _showToast('Gagal export Pivot Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BaseLayout(
      title: 'Laporan Permintaan Barang',
      showBackButton: true,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: _bgSoft,
          child: Column(
            children: [
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
                        onTap: () => _selectDate(context),
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
                              Icon(Icons.calendar_today_rounded, size: 14, color: _accentGold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tanggal',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        color: _textLight,
                                      ),
                                    ),
                                    Text(
                                      _selectedDate != null ? _displayDateFormat.format(_selectedDate!) : '-',
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
                    Container(
                      width: 80,
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
                                _isLoading
                                    ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
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
                          onTap: _isLoading ? null : _showCreateSpkDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.playlist_add_rounded, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Buat SPK',
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
                    const SizedBox(width: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accentSky, _accentSky.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _accentSky.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _reportItems.isEmpty ? null :
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
                    ? _buildErrorState()
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDataGridView(),
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

  Widget _buildDataGridView() {
    if (_reportItems.isEmpty) {
      return _buildEmptyState('Tidak ada data untuk ditampilkan');
    }

    final screenWidth = MediaQuery.of(context).size.width;

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
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  selectionMode: SelectionMode.none,
                  stackedHeaderRows: [
                    StackedHeaderRow(
                      cells: [
                        StackedHeaderCell(
                          columnNames: const ['no', 'item_nama', 'cabang', 'keterangan', 'total_qty'],
                          child: Container(
                            height: 12,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.filter_list, size: 10, color: _textLight),
                                const SizedBox(width: 2),
                                Icon(Icons.unfold_more, size: 10, color: _textLight),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  tableSummaryRows: [
                    GridTableSummaryRow(
                      showSummaryInRow: false,
                      title: 'TOTAL',
                      titleColumnSpan: 3,
                      columns: [
                        GridSummaryColumn(
                          name: 'TotalQty',
                          columnName: 'total_qty',
                          summaryType: GridSummaryType.sum,
                        ),
                      ],
                      position: GridTableSummaryRowPosition.bottom,
                    ),
                  ],
                  columns: [
                    GridColumn(
                      columnName: 'no',
                      width: _columnWidths['no'] ?? 60,
                      minimumWidth: 50,
                      maximumWidth: 70,
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
                      columnName: 'item_nama',
                      width: _columnWidths['item_nama'] ?? 200,
                      minimumWidth: 150,
                      maximumWidth: 300,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
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
                      columnName: 'cabang',
                      width: _columnWidths['cabang'] ?? 120,
                      minimumWidth: 100,
                      maximumWidth: 180,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cabang',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'keterangan',
                      width: _columnWidths['keterangan'] ?? 250,
                      minimumWidth: 200,
                      maximumWidth: 350,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Keterangan',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'total_qty',
                      width: _columnWidths['total_qty'] ?? 100,
                      minimumWidth: 90,
                      maximumWidth: 130,
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total Qty',
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
                        width: _columnWidths['no'] ?? 60,
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
                        width: (_columnWidths['item_nama'] ?? 200) +
                            (_columnWidths['cabang'] ?? 120) +
                            (_columnWidths['keterangan'] ?? 250),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Periode: ${_displayDateFormat.format(_selectedDate!)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: _textDark,
                          ),
                        ),
                      ),
                      Container(
                        width: _columnWidths['total_qty'] ?? 100,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerRight,
                        child: Text(
                          _numberFormat.format(_totalQty),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accentGold,
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
      ),
    );
  }

  Widget _buildPivotView() {
    if (_reportItems.isEmpty) {
      return _buildEmptyState('Tidak ada data untuk pivot table');
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
                      'Rows: Nama Item | Columns: Cabang',
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
                        colors: [_accentSky, _accentSky.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _accentSky.withOpacity(0.2),
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
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 40,
                  child: PivotTable(
                    jsonData: jsonData,
                    hiddenAttributes: const [],
                    cols: const ['cabang'],
                    rows: const ['item_nama'],
                    aggregatorName: AggregatorName.sum,
                    vals: const ['total_qty'],
                    marginLabel: 'Total',
                    rendererName: RendererName.table,
                  ),
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

  Widget _buildEmptyState(String message) {
    return Center(
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _bgSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, size: 32, color: _textLight),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentCoral.withOpacity(0.3)),
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
            const SizedBox(height: 12),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
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
                  onTap: _loadData,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
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
    );
  }
}

class MintaReportDataSource extends DataGridSource {
  MintaReportDataSource({
    required List<MintaReportItem> items,
    required NumberFormat numberFormat,
  }) {
    _numberFormat = numberFormat;
    _totalQty = items.fold<int>(0, (sum, item) => sum + item.totalQty);

    _data = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'item_nama', value: item.itemNama),
        DataGridCell<String>(columnName: 'cabang', value: item.cabang),
        DataGridCell<String>(columnName: 'keterangan', value: item.keterangan),
        DataGridCell<int>(columnName: 'total_qty', value: item.totalQty),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late int _totalQty;
  late NumberFormat _numberFormat;

  @override
  List<DataGridRow> get rows => _data;

  @override
  Widget? buildTableSummaryCellWidget(
      GridTableSummaryRow summaryRow,
      GridSummaryColumn? summaryColumn,
      RowColumnIndex rowColumnIndex,
      String summaryValue) {

    if (summaryColumn?.name == 'TotalQty') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerRight,
        child: Text(
          _numberFormat.format(_totalQty),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: Color(0xFFF6A918),
          ),
          textAlign: TextAlign.right,
        ),
      );
    } else if (summaryColumn == null && summaryRow.title != null && summaryRow.title!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          summaryRow.title!,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: Color(0xFFF6A918),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(summaryValue),
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isTotalQty = cell.columnName == 'total_qty';
        final Color textColor = isTotalQty ? const Color(0xFFF6A918) : const Color(0xFF1A202C);

        return Container(
          alignment: isTotalQty ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isTotalQty ? _numberFormat.format(cell.value) : cell.value.toString(),
            textAlign: isTotalQty ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: isTotalQty ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum ToastType { success, error, info }