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
import '../services/spk_service.dart';
import '../widgets/base_layout.dart';
import '../utils/responsive_helper.dart';

class SpkListScreen extends StatefulWidget {
  const SpkListScreen({super.key});

  @override
  State<SpkListScreen> createState() => _SpkListScreenState();
}

class _SpkListScreenState extends State<SpkListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Color Palette - Minimalis
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
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  late Map<String, double> _columnWidths = {
    'no': 80,
    'nomor': 160,
    'tanggal': 150,
    'keterangan': 300,
    'status': 80,
    'user_create': 120,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _spkList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late SpkDataSource _dataSource;
  int _totalFilteredSpk = 0;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadSpkData();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _updateDateControllers() {
    _startDateController.text = _dateFormat.format(_startDate);
    _endDateController.text = _dateFormat.format(_endDate);
  }

  String _formatDateForApi(DateTime date) => _apiDateFormat.format(date);

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _loadSpkData() async {
    setState(() => _isLoading = true);
    try {
      final data = await SpkService.getSpkList(
        search: null,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _spkList = data;
        _totalFilteredSpk = data.length;
        _dataSource = SpkDataSource(
          spkList: data,
          onEdit: _openEditSpk,
          onDelete: _deleteSpk,
          formatDate: _formatDate,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data SPK', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        setState(() => _totalFilteredSpk = _dataSource.effectiveRows!.length);
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
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

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
        _updateDateControllers();
      });
    }
  }

  void _openEditSpk(Map<String, dynamic> spk) {
    _showEditKeteranganDialog(spk);
  }

  void _showEditKeteranganDialog(Map<String, dynamic> spk) {
    final TextEditingController controller = TextEditingController(text: spk['spk_keterangan'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_outlined, size: 16, color: _accentBlue),
            ),
            const SizedBox(width: 8),
            Text('Edit Keterangan', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt, size: 14, color: _accentGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      spk['spk_nomor'],
                      style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: TextField(
                controller: controller,
                style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Keterangan...',
                  hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performUpdate(spk['spk_nomor'], controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Simpan', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpdate(String nomor, String keterangan) async {
    setState(() => _isLoading = true);
    try {
      final result = await SpkService.updateSpk(nomor, keterangan);
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadSpkData();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteSpk(Map<String, dynamic> spk) {
    if (spk['spk_isclosed'] == 1) {
      _showSnackbar('SPK Closed tidak dapat dihapus!', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus SPK', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${spk['spk_nomor']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(spk);
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

  Future<void> _performDelete(Map<String, dynamic> spk) async {
    setState(() => _isLoading = true);
    try {
      final result = await SpkService.deleteSpk(spk['spk_nomor'].toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadSpkData();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> spk) {
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
              // Header
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
                      child: Icon(Icons.assignment_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail SPK', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(spk['spk_nomor'] ?? '-', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Info Row 1
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgLight, border: Border(bottom: BorderSide(color: _borderColor))),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: _accentGold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.calendar_today, size: 14, color: _accentGold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(DateFormat('dd MMMM yyyy').format(DateTime.parse(spk['spk_tanggal'])),
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
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
                            decoration: BoxDecoration(
                              color: spk['spk_isclosed'] == 1 ? _accentMint.withOpacity(0.1) : _accentGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              spk['spk_isclosed'] == 1 ? Icons.check_circle : Icons.pending,
                              size: 14,
                              color: spk['spk_isclosed'] == 1 ? _accentMint : _accentGold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(
                                  spk['spk_isclosed'] == 1 ? 'Closed' : 'Open',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: spk['spk_isclosed'] == 1 ? _accentMint : _accentGold,
                                  ),
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
              // Info Row 2
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.description_rounded, size: 14, color: _accentBlue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keterangan', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                          Text(spk['spk_keterangan'] ?? '-',
                              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Items List
              Expanded(
                child: FutureBuilder(
                  future: SpkService.getSpkDetail(spk['spk_nomor']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(child: Text('Gagal memuat detail', style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)));
                    }
                    final data = snapshot.data!;
                    final details = List<Map<String, dynamic>>.from(data['details'] ?? []);
                    if (details.isEmpty) {
                      return Center(child: Text('Tidak ada item', style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)));
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: _accentMint.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Icon(Icons.inventory_2_outlined, size: 12, color: _accentMint),
                                ),
                                const SizedBox(width: 8),
                                Text('Daftar Items (${details.length})',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(8)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SfDataGrid(
                                  source: SpkDetailDataSource(details: details, numberFormat: _numberFormat),
                                  columnWidthMode: ColumnWidthMode.fill,
                                  headerRowHeight: 34,
                                  rowHeight: 32,
                                  gridLinesVisibility: GridLinesVisibility.both,
                                  headerGridLinesVisibility: GridLinesVisibility.both,
                                  columns: [
                                    GridColumn(
                                        columnName: 'no',
                                        width: 50,
                                        label: Container(alignment: Alignment.center, child: Text('No', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
                                    GridColumn(
                                        columnName: 'nama',
                                        label: Container(alignment: Alignment.centerLeft, child: Text('Nama Item', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
                                    GridColumn(
                                        columnName: 'qty',
                                        width: 90,
                                        label: Container(alignment: Alignment.center, child: Text('Qty SPK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
                                    GridColumn(
                                        columnName: 'realisasi',
                                        width: 90,
                                        label: Container(alignment: Alignment.center, child: Text('Realisasi', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
                                    GridColumn(
                                        columnName: 'sisa',
                                        width: 90,
                                        label: Container(alignment: Alignment.center, child: Text('Sisa', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
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
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgLight, border: Border(top: BorderSide(color: _borderColor))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 90,
                      height: 36,
                      decoration: BoxDecoration(color: _primaryDark, borderRadius: BorderRadius.circular(8)),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: Text('Tutup', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
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

  Future<void> _exportToExcel() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data SPK';

      // ===== LEBAR KOLOM =====
      sheet.getRangeByIndex(1, 1).columnWidth = 6;   // No SPK
      sheet.getRangeByIndex(1, 2).columnWidth = 18;  // Nomor SPK
      sheet.getRangeByIndex(1, 3).columnWidth = 12;  // Tanggal
      sheet.getRangeByIndex(1, 4).columnWidth = 30;  // Keterangan
      sheet.getRangeByIndex(1, 5).columnWidth = 10;  // Status
      sheet.getRangeByIndex(1, 6).columnWidth = 12;  // User
      sheet.getRangeByIndex(1, 7).columnWidth = 6;   // No Detail
      sheet.getRangeByIndex(1, 8).columnWidth = 25;  // Nama Item
      sheet.getRangeByIndex(1, 9).columnWidth = 12;  // Qty SPK
      sheet.getRangeByIndex(1, 10).columnWidth = 12; // Realisasi
      sheet.getRangeByIndex(1, 11).columnWidth = 10; // Sisa

      // ===== PERIODE DI ATAS =====
      final periodeRange = sheet.getRangeByIndex(1, 1, 1, 6);
      periodeRange.merge();
      periodeRange.setText('Periode: ${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}');
      periodeRange.cellStyle.fontSize = 11;
      periodeRange.cellStyle.bold = true;
      periodeRange.cellStyle.hAlign = HAlignType.left;
      periodeRange.cellStyle.backColor = '#F1F5F9';

      // ===== HEADER KOLOM SPK =====
      int row = 3;
      final spkHeaderRange = sheet.getRangeByIndex(row, 1, row, 6);
      spkHeaderRange.cellStyle.backColor = '#2C3E50';
      spkHeaderRange.cellStyle.fontColor = '#FFFFFF';
      spkHeaderRange.cellStyle.bold = true;
      spkHeaderRange.cellStyle.fontSize = 10;
      spkHeaderRange.cellStyle.hAlign = HAlignType.center;

      sheet.getRangeByIndex(row, 1).setText('No');
      sheet.getRangeByIndex(row, 2).setText('Nomor');
      sheet.getRangeByIndex(row, 3).setText('Tanggal');
      sheet.getRangeByIndex(row, 4).setText('Keterangan');
      sheet.getRangeByIndex(row, 5).setText('Status');
      sheet.getRangeByIndex(row, 6).setText('User');
      row++;

      // ===== DATA SPK + DETAIL =====
      int noSpk = 1;
      for (var spk in _spkList) {
        final nomor = spk['spk_nomor']?.toString() ?? '-';
        final tanggal = _formatDate(spk['spk_tanggal'] ?? '');
        final keterangan = spk['spk_keterangan']?.toString() ?? '-';
        final status = spk['spk_isclosed'] == 1 ? 'Closed' : 'Open';
        final user = spk['user_create']?.toString() ?? '-';

        // Baris data SPK
        sheet.getRangeByIndex(row, 1).setText(noSpk.toString());
        sheet.getRangeByIndex(row, 2).setText(nomor);
        sheet.getRangeByIndex(row, 3).setText(tanggal);
        sheet.getRangeByIndex(row, 4).setText(keterangan);
        sheet.getRangeByIndex(row, 5).setText(status);
        sheet.getRangeByIndex(row, 6).setText(user);

        final dataSpkRange = sheet.getRangeByIndex(row, 1, row, 6);
        dataSpkRange.cellStyle.fontSize = 9;
        sheet.getRangeByIndex(row, 1).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 3).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 5).cellStyle.hAlign = HAlignType.center;

        // Warna status
        if (status == 'Closed') {
          sheet.getRangeByIndex(row, 5).cellStyle.fontColor = '#06D6A0';
        } else {
          sheet.getRangeByIndex(row, 5).cellStyle.fontColor = '#F6A918';
        }

        row++;

        // Header kolom detail
        final detailHeaderRange = sheet.getRangeByIndex(row, 7, row, 11);
        detailHeaderRange.cellStyle.backColor = '#34495E';
        detailHeaderRange.cellStyle.fontColor = '#FFFFFF';
        detailHeaderRange.cellStyle.bold = true;
        detailHeaderRange.cellStyle.fontSize = 9;
        detailHeaderRange.cellStyle.hAlign = HAlignType.center;

        sheet.getRangeByIndex(row, 7).setText('No');
        sheet.getRangeByIndex(row, 8).setText('Nama Item');
        sheet.getRangeByIndex(row, 9).setText('Qty SPK');
        sheet.getRangeByIndex(row, 10).setText('Realisasi');
        sheet.getRangeByIndex(row, 11).setText('Sisa');
        row++;

        // Data detail items
        try {
          final detailData = await SpkService.getSpkDetailForExport(nomor);
          final details = List<Map<String, dynamic>>.from(detailData['details'] ?? []);

          if (details.isNotEmpty) {
            int noDetail = 1;
            for (var item in details) {
              final qty = _parseInt(item['spkd_qty']);
              final realisasi = _parseInt(item['qty_realisasi']);
              final sisa = qty - realisasi;

              sheet.getRangeByIndex(row, 7).setText(noDetail.toString());
              sheet.getRangeByIndex(row, 8).setText(item['item_nama']?.toString() ?? '-');
              sheet.getRangeByIndex(row, 9).setNumber(qty.toDouble());
              sheet.getRangeByIndex(row, 10).setNumber(realisasi.toDouble());
              sheet.getRangeByIndex(row, 11).setNumber(sisa.toDouble());

              final detailDataRange = sheet.getRangeByIndex(row, 7, row, 11);
              detailDataRange.cellStyle.fontSize = 9;
              sheet.getRangeByIndex(row, 7).cellStyle.hAlign = HAlignType.center;
              sheet.getRangeByIndex(row, 9).cellStyle.hAlign = HAlignType.center;
              sheet.getRangeByIndex(row, 10).cellStyle.hAlign = HAlignType.center;
              sheet.getRangeByIndex(row, 11).cellStyle.hAlign = HAlignType.center;

              if (row % 2 == 0) {
                detailDataRange.cellStyle.backColor = '#F8FAFC';
              }

              noDetail++;
              row++;
            }
          } else {
            sheet.getRangeByIndex(row, 7).setText('');
            sheet.getRangeByIndex(row, 8).setText('(Tidak ada item)');
            sheet.getRangeByIndex(row, 8).cellStyle.italic = true;
            sheet.getRangeByIndex(row, 8).cellStyle.fontColor = '#94A3B8';
            row++;
          }
        } catch (e) {
          sheet.getRangeByIndex(row, 7).setText('');
          sheet.getRangeByIndex(row, 8).setText('(Gagal memuat detail)');
          sheet.getRangeByIndex(row, 8).cellStyle.fontColor = '#EF4444';
          sheet.getRangeByIndex(row, 8).cellStyle.italic = true;
          row++;
        }

        // Spasi antar SPK
        row++;
        noSpk++;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'SPK_Detail_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/SPK_Detail_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showSnackbar('File Excel berhasil disimpan');
      }
    } catch (e) {
      debugPrint('Export Excel error: $e');
      _showSnackbar('Gagal export Excel: ${e.toString()}', isError: true);
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'SPK',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header Actions - 1 Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 12),
              child: Row(
                children: [
                  // Tanggal Mulai
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _surfaceWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _primaryDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _startDateController.text,
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary),
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
                    flex: 2,
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _surfaceWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _primaryDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _endDateController.text,
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Load Button
                  _buildActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Load',
                    color: _accentMint,
                    onPressed: _loadSpkData,
                    isMobile: isMobile,
                  ),
                  const SizedBox(width: 8),
                  // Export Button
                  _buildActionButton(
                    icon: Icons.download_outlined,
                    label: 'Export',
                    color: _accentBlue,
                    onPressed: _exportToExcel,
                    isMobile: isMobile,
                  ),
                  // Tidak ada tombol Tambah karena SPK dibuat dari Minta
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _spkList.isEmpty
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
                              _buildGridColumn('no', 'No', width: _columnWidths['no'], alignment: Alignment.center),
                              _buildGridColumn('nomor', 'Nomor', width: _columnWidths['nomor']),
                              _buildGridColumn('tanggal', 'Tanggal', width: _columnWidths['tanggal'], alignment: Alignment.center),
                              _buildGridColumn('keterangan', 'Keterangan', width: _columnWidths['keterangan']),
                              _buildGridColumn('status', 'Status', width: _columnWidths['status'], alignment: Alignment.center),
                              _buildGridColumn('user_create', 'User', width: _columnWidths['user_create'], alignment: Alignment.center),
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
                                const Icon(Icons.receipt_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$_totalFilteredSpk SPK', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                              style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary),
                            ),
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
            child: Icon(Icons.assignment_outlined, size: 28, color: _textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada data SPK', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('SPK akan dibuat otomatis dari permintaan barang', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class SpkDataSource extends DataGridSource {
  SpkDataSource({
    required List<Map<String, dynamic>> spkList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required String Function(String) formatDate,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatDate = formatDate;
    _updateDataSource(spkList);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late String Function(String) _formatDate;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentMint = Color(0xFF06D6A0);
  static const Color _accentGold = Color(0xFFF6A918);

  void _updateDataSource(List<Map<String, dynamic>> spkList) {
    _data = spkList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final spk = entry.value;
      final status = spk['spk_isclosed'] == 1 ? 'Closed' : 'Open';
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: spk['spk_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(spk['spk_tanggal'] ?? '')),
        DataGridCell<String>(columnName: 'keterangan', value: spk['spk_keterangan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'status', value: status),
        DataGridCell<String>(columnName: 'user_create', value: spk['user_create']?.toString() ?? '-'),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: spk),
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
          final spk = cell.value as Map<String, dynamic>;
          final isClosed = spk['spk_isclosed'] == 1;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(spk)),
                const SizedBox(width: 4),
                _buildIconButton(
                  Icons.delete_outlined,
                  isClosed ? null : () => _onDelete(spk),
                  color: isClosed ? _textTertiary : _accentRed,
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'status') {
          final status = cell.value.toString();
          final isClosed = status == 'Closed';
          final color = isClosed ? _accentMint : _accentGold;
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(status, style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ),
          );
        }

        Color textColor = _textPrimary;
        if (cell.columnName == 'no' || cell.columnName == 'tanggal') textColor = _textSecondary;

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            cell.value.toString(),
            style: GoogleFonts.montserrat(fontSize: 11, fontWeight: cell.columnName == 'nomor' ? FontWeight.w500 : FontWeight.normal, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap, {Color? color}) {
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

  Alignment _getAlignment(String columnName) {
    if (columnName == 'aksi' || columnName == 'no' || columnName == 'tanggal' || columnName == 'status' || columnName == 'user_create') {
      return Alignment.center;
    }
    return Alignment.centerLeft;
  }
}

class SpkDetailDataSource extends DataGridSource {
  SpkDetailDataSource({required List<Map<String, dynamic>> details, required NumberFormat numberFormat}) {
    _numberFormat = numberFormat;
    _data = details.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      int qty = 0;
      final rawQty = item['spkd_qty'];
      if (rawQty is int) qty = rawQty;
      else if (rawQty is double) qty = rawQty.toInt();
      else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

      int realisasi = 0;
      final rawRealisasi = item['qty_realisasi'];
      if (rawRealisasi is int) realisasi = rawRealisasi;
      else if (rawRealisasi is double) realisasi = rawRealisasi.toInt();
      else if (rawRealisasi is String) realisasi = int.tryParse(rawRealisasi) ?? 0;

      final sisa = qty - realisasi;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item['item_nama']?.toString() ?? '-'),
        DataGridCell<int>(columnName: 'qty', value: qty),
        DataGridCell<int>(columnName: 'realisasi', value: realisasi),
        DataGridCell<int>(columnName: 'sisa', value: sisa),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _numberFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _accentMint = Color(0xFF06D6A0);

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'qty') {
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _accentGold.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_numberFormat.format(cell.value), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentGold)),
            ),
          );
        }
        if (cell.columnName == 'realisasi') {
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _accentMint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_numberFormat.format(cell.value), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint)),
            ),
          );
        }
        if (cell.columnName == 'sisa') {
          final sisa = cell.value as int;
          final color = sisa > 0 ? _accentGold : _accentMint;
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_numberFormat.format(sisa), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
          );
        }
        return Container(
          alignment: cell.columnName == 'no' ? Alignment.center : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(cell.value.toString(), style: GoogleFonts.montserrat(fontSize: 10, color: cell.columnName == 'no' ? _textSecondary : _textPrimary)),
        );
      }).toList(),
    );
  }
}