import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import 'dart:html' as html;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/koreksi_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class KoreksiListScreen extends StatefulWidget {
  const KoreksiListScreen({super.key});

  @override
  State<KoreksiListScreen> createState() => _KoreksiListScreenState();
}

class _KoreksiListScreenState extends State<KoreksiListScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

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
    'no': 80,
    'nomor': 160,
    'tanggal': 120,
    'keterangan': 350,
    'aksi': 70,
  };

  bool _isLoading = false;
  bool _showDateFilter = false;
  List<Map<String, dynamic>> _koreksiList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late KoreksiDataSource _dataSource;
  int _totalFilteredKoreksi = 0;

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

    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadKoreksiData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
  }

  String _formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _loadKoreksiData() async {
    setState(() => _isLoading = true);
    try {
      final koreksiData = await KoreksiService.getKoreksiList(
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _koreksiList = koreksiData;
        _totalFilteredKoreksi = koreksiData.length;
        _dataSource = KoreksiDataSource(
          koreksiList: koreksiData,
          onDelete: _deleteKoreksi,
          onView: _showItemDetailDialog,
          primaryDark: _primaryDark,
          accentGold: _accentGold,
          accentMint: _accentMint,
          accentCoral: _accentCoral,
          accentSky: _accentSky,
          borderSoft: _borderSoft,
          textDark: _textDark,
          textMedium: _textMedium,
          textLight: _textLight,
          formatDate: _formatDate,
        );
      });
    } catch (e) {
      _showToast('Gagal memuat data koreksi: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
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
          _totalFilteredKoreksi = filteredData.length;
        });
      }
    });
  }

  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              type == ToastType.success ? Icons.check_circle_rounded :
              type == ToastType.error ? Icons.error_rounded : Icons.info_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral : _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
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
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
        _updateDateControllers();
      });
    }
  }

  void _toggleDateFilter() {
    setState(() {
      _showDateFilter = !_showDateFilter;
    });
  }

  void _openAddKoreksi() {
    Navigator.pushNamed(
      context,
      '/koreksi-form',
      arguments: {
        'onSaved': _loadKoreksiData,
      },
    );
  }

  void _deleteKoreksi(Map<String, dynamic> koreksi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentCoralSoft,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accentCoral.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.warning_amber_rounded, color: _accentCoral, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Hapus Koreksi Stok', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
            ],
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Apakah Anda yakin ingin menghapus "${koreksi['kor_nomor']}"?',
            style: GoogleFonts.montserrat(fontSize: 12, color: _textMedium),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(koreksi);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> koreksi) async {
    setState(() => _isLoading = true);
    try {
      final result = await KoreksiService.deleteKoreksi(koreksi['kor_nomor'].toString());
      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        await _loadKoreksiData();
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> koreksi) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          height: 600,
          decoration: BoxDecoration(color: _surfaceWhite, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.inventory, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Koreksi Stok', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(koreksi['kor_nomor'] ?? '-', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgSoft, border: Border(bottom: BorderSide(color: _borderSoft))),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: _accentGoldSoft, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.calendar_today, size: 14, color: _accentGold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(DateTime.parse(koreksi['kor_tanggal'])),
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: _accentSkySoft, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.description, size: 14, color: _accentSky),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Keterangan', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                Text(
                                  koreksi['kor_keterangan'] ?? '-',
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: KoreksiService.getKoreksiDetail(koreksi['kor_nomor'].toString()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _accentGold, strokeWidth: 2)),
                            const SizedBox(height: 12),
                            Text('Memuat detail items...', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: _accentCoral),
                            const SizedBox(height: 12),
                            Text('Gagal memuat detail', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                          ],
                        ),
                      );
                    }

                    final details = List<Map<String, dynamic>>.from(snapshot.data?['details'] ?? []);

                    if (details.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
                              child: Icon(Icons.inventory_2_outlined, size: 30, color: _textLight),
                            ),
                            const SizedBox(height: 12),
                            Text('Tidak ada item dalam transaksi ini', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: _accentMintSoft, borderRadius: BorderRadius.circular(6)),
                                  child: Icon(Icons.inventory_2_outlined, size: 12, color: _accentMint),
                                ),
                                const SizedBox(width: 8),
                                Text('Daftar Items (${details.length})', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: _borderSoft), borderRadius: BorderRadius.circular(8)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SfDataGrid(
                                  source: KoreksiDetailDataSource(
                                    details: details,
                                    accentGold: _accentGold,
                                    textDark: _textDark,
                                    textMedium: _textMedium,
                                    accentMint: _accentMint,
                                    accentMintSoft: _accentMintSoft,
                                    accentCoral: _accentCoral,
                                    accentCoralSoft: _accentCoralSoft,
                                  ),
                                  columnWidthMode: ColumnWidthMode.fill,
                                  headerRowHeight: 34,
                                  rowHeight: 32,
                                  allowSorting: true,
                                  gridLinesVisibility: GridLinesVisibility.both,
                                  headerGridLinesVisibility: GridLinesVisibility.both,
                                  columns: [
                                    GridColumn(
                                      columnName: 'no',
                                      width: 60,
                                      label: Container(
                                        alignment: Alignment.center,
                                        child: Text('No', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                      ),
                                    ),
                                    GridColumn(
                                      columnName: 'nama',
                                      label: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        alignment: Alignment.centerLeft,
                                        child: Text('Nama Item', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                      ),
                                    ),
                                    GridColumn(
                                      columnName: 'stok_sistem',
                                      width: 100,
                                      label: Container(
                                        alignment: Alignment.center,
                                        child: Text('Stok Sistem', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                      ),
                                    ),
                                    GridColumn(
                                      columnName: 'selisih',
                                      width: 100,
                                      label: Container(
                                        alignment: Alignment.center,
                                        child: Text('Selisih', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
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
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgSoft, border: Border(top: BorderSide(color: _borderSoft))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
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

  Future<void> _exportToExcel() async {
    try {
      final currentState = _key.currentState;
      if (currentState == null) return;

      final visibleRows = _dataSource.effectiveRows ?? _dataSource.rows;

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Koreksi Stok';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 18;
      sheet.getRangeByIndex(1, 3).columnWidth = 10;
      sheet.getRangeByIndex(1, 4).columnWidth = 35;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 4);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nomor');
      sheet.getRangeByName('C1').setText('Tanggal');
      sheet.getRangeByName('D1').setText('Keterangan');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String nomor = '';
        String tanggal = '';
        String keterangan = '';

        for (var cell in cells) {
          if (cell.columnName == 'no') {
            no = cell.value.toString();
          } else if (cell.columnName == 'nomor') {
            nomor = cell.value.toString();
          } else if (cell.columnName == 'tanggal') {
            tanggal = cell.value.toString();
          } else if (cell.columnName == 'keterangan') {
            keterangan = cell.value.toString();
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nomor);
        sheet.getRangeByName('C$rowIndex').setText(tanggal);
        sheet.getRangeByName('D$rowIndex').setText(keterangan);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 4);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.left;

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

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredKoreksi Transaksi');
      sheet.getRangeByName('B$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('B$totalRow').cellStyle.hAlign = HAlignType.left;
      sheet.getRangeByName('B$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('C$totalRow').setText('Periode:');
      sheet.getRangeByName('C$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('C$totalRow').cellStyle.hAlign = HAlignType.right;
      sheet.getRangeByName('C$totalRow').cellStyle.fontSize = 9;

      sheet.getRangeByName('D$totalRow').setText(
          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'
      );
      sheet.getRangeByName('D$totalRow').cellStyle.backColor = '#E9ECEF';
      sheet.getRangeByName('D$totalRow').cellStyle.hAlign = HAlignType.left;
      sheet.getRangeByName('D$totalRow').cellStyle.fontSize = 9;

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'KoreksiStok_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showToast('File Excel berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/KoreksiStok_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      _showToast('Gagal export Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Koreksi Stok',
      showBackButton: false,
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
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showDateFilter ? _accentGoldSoft : _bgSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _showDateFilter ? _accentGold : _borderSoft),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleDateFilter,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.date_range, size: 14, color: _showDateFilter ? _accentGold : _textLight),
                                const SizedBox(width: 6),
                                Text('Filter', style: GoogleFonts.montserrat(fontSize: 11, color: _showDateFilter ? _accentGold : _textMedium)),
                                const SizedBox(width: 4),
                                Icon(_showDateFilter ? Icons.expand_less : Icons.expand_more, size: 14, color: _showDateFilter ? _accentGold : _textLight),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_accentMint, _accentMint.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _exportToExcel,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.table_chart, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  Text('Export Excel', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openAddKoreksi,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  Text('Tambah', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
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
              if (_showDateFilter) ...[
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderSoft),
                    boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: _accentGold),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal Mulai', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                      Text(_startDateController.text, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderSoft)),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: _accentGold),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal Selesai', style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                      Text(_endDateController.text, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark)),
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
                        width: 90,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_accentMint, _accentMint.withOpacity(0.8)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _loadKoreksiData(),
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
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
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _accentGold, strokeWidth: 2)),
                      const SizedBox(height: 12),
                      Text('Memuat data koreksi...', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                    ],
                  ),
                )
                    : _koreksiList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
                        child: Icon(Icons.inventory_2_outlined, size: 35, color: _textLight),
                      ),
                      const SizedBox(height: 12),
                      Text('Belum ada data koreksi', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
                      const SizedBox(height: 4),
                      Text('Klik tombol Tambah untuk memulai', style: GoogleFonts.montserrat(fontSize: 11, color: _textLight)),
                    ],
                  ),
                )
                    : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderSoft),
                      boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
                              headerRowHeight: 28,
                              rowHeight: 30,
                              allowSorting: true,
                              allowFiltering: true,
                              onFilterChanged: _onFilterChanged,
                              gridLinesVisibility: GridLinesVisibility.both,
                              headerGridLinesVisibility: GridLinesVisibility.both,
                              selectionMode: SelectionMode.none,
                              onCellTap: (details) {
                                if (details.rowColumnIndex.rowIndex > 0) {
                                  final rowIndex = details.rowColumnIndex.rowIndex - 1;
                                  if (rowIndex < _dataSource.rows.length) {
                                    final row = _dataSource.rows[rowIndex];
                                    final cells = row.getCells();
                                    final aksiCell = cells.firstWhere(
                                          (cell) => cell.columnName == 'aksi',
                                      orElse: () => DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: null),
                                    );
                                    if (aksiCell.value != null) {
                                      _showItemDetailDialog(aksiCell.value as Map<String, dynamic>);
                                    }
                                  }
                                }
                              },
                              columns: [
                                GridColumn(
                                  columnName: 'no',
                                  width: _columnWidths['no'] ?? 80,
                                  label: Container(
                                    alignment: Alignment.center,
                                    child: Text('No', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'nomor',
                                  width: _columnWidths['nomor'] ?? 160,
                                  label: Container(
                                    alignment: Alignment.center,
                                    child: Text('Nomor', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'tanggal',
                                  width: _columnWidths['tanggal'] ?? 120,
                                  label: Container(
                                    alignment: Alignment.center,
                                    child: Text('Tanggal', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'keterangan',
                                  width: _columnWidths['keterangan'] ?? 350,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
                                    child: Text('Keterangan', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'aksi',
                                  width: _columnWidths['aksi'] ?? 70,
                                  label: Container(
                                    alignment: Alignment.center,
                                    child: Text('Aksi', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
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
                            border: Border(top: BorderSide(color: _borderSoft)),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: screenWidth - (isTablet ? 64 : 56),
                              child: Row(
                                children: [
                                  Container(
                                    width: _columnWidths['no'] ?? 80,
                                    alignment: Alignment.center,
                                    child: Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: _textDark)),
                                  ),
                                  Container(
                                    width: _columnWidths['nomor'] ?? 160,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt, size: 11, color: _primaryDark),
                                        const SizedBox(width: 4),
                                        Text('$_totalFilteredKoreksi Transaksi', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _primaryDark)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: _columnWidths['tanggal'] ?? 120,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                                      style: GoogleFonts.montserrat(fontSize: 9, color: _textDark),
                                    ),
                                  ),
                                  Container(
                                    width: _columnWidths['keterangan'] ?? 350,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerLeft,
                                    child: const SizedBox(),
                                  ),
                                  Container(
                                    width: _columnWidths['aksi'] ?? 70,
                                    alignment: Alignment.center,
                                    child: _totalFilteredKoreksi < _koreksiList.length
                                        ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: _accentGoldSoft, borderRadius: BorderRadius.circular(4)),
                                      child: Text('${_koreksiList.length - _totalFilteredKoreksi} filter', style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w600, color: _accentGold)),
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
        ),
      ),
    );
  }
}

class KoreksiDataSource extends DataGridSource {
  KoreksiDataSource({
    required List<Map<String, dynamic>> koreksiList,
    required Function(Map<String, dynamic>) onDelete,
    required Function(Map<String, dynamic>) onView,
    required Color primaryDark,
    required Color accentGold,
    required Color accentMint,
    required Color accentCoral,
    required Color accentSky,
    required Color borderSoft,
    required Color textDark,
    required Color textMedium,
    required Color textLight,
    required String Function(String) formatDate,
  }) {
    _onDelete = onDelete;
    _primaryDark = primaryDark;
    _accentGold = accentGold;
    _accentMint = accentMint;
    _accentCoral = accentCoral;
    _accentSky = accentSky;
    _borderSoft = borderSoft;
    _textDark = textDark;
    _textMedium = textMedium;
    _textLight = textLight;
    _formatDate = formatDate;

    _originalKoreksiList = koreksiList;
    _updateDataSource(koreksiList);
  }

  List<Map<String, dynamic>> _originalKoreksiList = [];
  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onDelete;
  late Color _primaryDark;
  late Color _accentGold;
  late Color _accentMint;
  late Color _accentCoral;
  late Color _accentSky;
  late Color _borderSoft;
  late Color _textDark;
  late Color _textMedium;
  late Color _textLight;
  late String Function(String) _formatDate;

  void _updateDataSource(List<Map<String, dynamic>> koreksiList) {
    _data = koreksiList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final koreksi = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: koreksi['kor_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(koreksi['kor_tanggal'] ?? '')),
        DataGridCell<String>(columnName: 'keterangan', value: koreksi['kor_keterangan']?.toString() ?? '-'),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: koreksi),
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
          final koreksi = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accentCoral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onDelete(koreksi),
                  borderRadius: BorderRadius.circular(6),
                  child: Center(
                    child: Icon(
                      Icons.delete_rounded,
                      size: 14,
                      color: _accentCoral,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        Color textColor = _textDark;
        if (cell.columnName == 'no' || cell.columnName == 'tanggal') {
          textColor = _textMedium;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: cell.columnName == 'nomor' ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }
}

class KoreksiDetailDataSource extends DataGridSource {
  KoreksiDetailDataSource({
    required List<Map<String, dynamic>> details,
    required Color accentGold,
    required Color textDark,
    required Color textMedium,
    required Color accentMint,
    required Color accentMintSoft,
    required Color accentCoral,
    required Color accentCoralSoft,
  }) {
    _accentGold = accentGold;
    _textDark = textDark;
    _textMedium = textMedium;
    _accentMint = accentMint;
    _accentMintSoft = accentMintSoft;
    _accentCoral = accentCoral;
    _accentCoralSoft = accentCoralSoft;

    _data = details.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item['item_nama']?.toString() ?? '-'),
        DataGridCell<double>(columnName: 'stok_sistem', value: item['kord_stok']?.toDouble() ?? 0),
        DataGridCell<double>(columnName: 'selisih', value: item['kord_qty']?.toDouble() ?? 0),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late Color _accentGold;
  late Color _textDark;
  late Color _textMedium;
  late Color _accentMint;
  late Color _accentMintSoft;
  late Color _accentCoral;
  late Color _accentCoralSoft;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'selisih') {
          final selisih = cell.value as double;
          final isPositive = selisih > 0;
          final isNegative = selisih < 0;

          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isPositive ? _accentMintSoft : (isNegative ? _accentCoralSoft : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${selisih > 0 ? '+' : ''}${selisih.toStringAsFixed(0)}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? _accentMint : (isNegative ? _accentCoral : _textMedium),
                ),
              ),
            ),
          );
        }

        if (cell.columnName == 'stok_sistem') {
          return Container(
            alignment: Alignment.center,
            child: Text(
              (cell.value as double).toStringAsFixed(0),
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
            ),
          );
        }

        Color textColor = _textDark;
        if (cell.columnName == 'no') {
          textColor = _textMedium;
        }

        return Container(
          alignment: cell.columnName == 'no' ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: cell.columnName == 'nama' ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

enum ToastType { success, error, info }