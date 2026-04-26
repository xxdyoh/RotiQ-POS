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
import '../services/do_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';
import '../services/session_manager.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DoListScreen extends StatefulWidget {
  const DoListScreen({super.key});

  @override
  State<DoListScreen> createState() => _DoListScreenState();
}

class _DoListScreenState extends State<DoListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Color Palette - Minimalis dengan aksen primary (sama seperti koreksi_list_screen)
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
    'no': 100,
    'nomor': 160,
    'tanggal': 150,
    'keterangan': 250,
    'gudang': 150,
    'cbg_tujuan': 160,
    'status': 80,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _mutasiList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late MutasiDataSource _dataSource;
  int _totalFilteredMutasi = 0;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadMutasiData();
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

  Future<void> _loadMutasiData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DoService.getMutasiList(
        search: null,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _mutasiList = data;
        _totalFilteredMutasi = data.length;
        _dataSource = MutasiDataSource(
          mutasiList: data,
          onEdit: _openEditMutasi,
          onDelete: _deleteMutasi,
          formatDate: _formatDate,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data mutasi out', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        setState(() => _totalFilteredMutasi = _dataSource.effectiveRows!.length);
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

  void _openAddMutasi() {
    Navigator.pushNamed(
      context,
      AppRoutes.doForm,
      arguments: {'onMutasiSaved': _loadMutasiData},
    );
  }

  void _openEditMutasi(Map<String, dynamic> mutasi) {
    // Cek jika closed
    if (mutasi['mutc_status'] == 1) {
      _showSnackbar('Mutasi Closed tidak dapat diedit!', isError: true);
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.doForm,
      arguments: {
        'mutasiHeader': mutasi,
        'onMutasiSaved': _loadMutasiData,
      },
    );
  }

  void _deleteMutasi(Map<String, dynamic> mutasi) {
    if (mutasi['mutc_status'] == 1) {
      _showSnackbar('Mutasi Closed tidak dapat dihapus!', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Mutasi Out', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${mutasi['mutc_nomor']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(mutasi);
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

  Future<void> _performDelete(Map<String, dynamic> mutasi) async {
    setState(() => _isLoading = true);
    try {
      final result = await DoService.deleteMutasi(mutasi['mutc_nomor'].toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadMutasiData();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> mutasi) {
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
                      child: Icon(Icons.local_shipping_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Mutasi Out', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(mutasi['mutc_nomor'] ?? '-', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white.withOpacity(0.8))),
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
                                Text(DateFormat('dd MMMM yyyy').format(DateTime.parse(mutasi['mutc_tanggal'])),
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
                            decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.warehouse_rounded, size: 14, color: _accentBlue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gudang Asal', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(
                                  mutasi['gudang_nama'] != null && mutasi['gudang_nama'].toString().isNotEmpty
                                      ? '${mutasi['mutc_gdg_kode']} - ${mutasi['gudang_nama']}'
                                      : mutasi['mutc_gdg_kode'] ?? '-',
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: _accentGold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.business_rounded, size: 14, color: _accentGold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cabang Tujuan', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(
                                  mutasi['cabang_nama'] != null && mutasi['cabang_nama'].toString().isNotEmpty
                                      ? '${mutasi['mutc_cbg_tujuan']} - ${mutasi['cabang_nama']}'
                                      : mutasi['mutc_cbg_tujuan'] ?? '-',
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
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
                            decoration: BoxDecoration(color: _accentMint.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.description_rounded, size: 14, color: _accentMint),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Keterangan', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(mutasi['mutc_keterangan'] ?? '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Items List
              Expanded(
                child: FutureBuilder(
                  future: DoService.getMutasiDetail(mutasi['mutc_nomor'].toString()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(child: Text('Gagal memuat detail', style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)));
                    }
                    final details = List<Map<String, dynamic>>.from(snapshot.data?['details'] ?? []);
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
                                  source: MutasiDetailDataSource(details: details, numberFormat: _numberFormat),
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
                                        columnName: 'tipe',
                                        width: 70,
                                        label: Container(alignment: Alignment.center, child: Text('Tipe', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
                                    GridColumn(
                                        columnName: 'qty',
                                        width: 80,
                                        label: Container(alignment: Alignment.center, child: Text('Qty', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
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
                    // Tombol Print
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _accentBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _printSuratJalan(mutasi);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.print_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Print', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Tutup
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

  Future<void> _printSuratJalan(Map<String, dynamic> mutasi) async {
    // Ambil detail items
    List<Map<String, dynamic>> details = [];
    try {
      final detailData = await DoService.getMutasiDetail(mutasi['mutc_nomor'].toString());
      details = List<Map<String, dynamic>>.from(detailData['details'] ?? []);
    } catch (e) {
      debugPrint('Gagal load detail: $e');
    }

    final nomor = mutasi['mutc_nomor']?.toString() ?? '-';
    final tanggal = DateFormat('dd MMMM yyyy').format(DateTime.parse(mutasi['mutc_tanggal']));
    final asal = SessionManager.getCurrentCabang()?.nama ??
        SessionManager.getCurrentCabang()?.kode ?? '-';
    final tujuanNama = mutasi['cabang_nama']?.toString().isNotEmpty == true
        ? '${mutasi['mutc_cbg_tujuan']} - ${mutasi['cabang_nama']}'
        : mutasi['mutc_cbg_tujuan']?.toString() ?? '-';
    final keterangan = mutasi['mutc_keterangan']?.toString() ?? '-';
    final gudangNama = mutasi['gudang_nama']?.toString().isNotEmpty == true
        ? '${mutasi['mutc_gdg_kode']} - ${mutasi['gudang_nama']}'
        : mutasi['mutc_gdg_kode']?.toString() ?? '-';

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(210 * PdfPageFormat.mm, 148 * PdfPageFormat.mm), // A5 landscape
        margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'MUTASI OUT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColor.fromHex('#2C3E50'), thickness: 2),
              pw.SizedBox(height: 8),

              // Info Table
              pw.Table(
                columnWidths: {
                  0: pw.FixedColumnWidth(60),
                  1: pw.FixedColumnWidth(10),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FixedColumnWidth(20),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FixedColumnWidth(10),
                  6: pw.FlexColumnWidth(1),
                },
                children: [
                  _buildInfoRow('Nomor', nomor, 'Asal', asal),
                  _buildInfoRow('Tanggal', tanggal, 'Tujuan', tujuanNama),
                  _buildInfoRow('Keterangan', keterangan, 'Gudang', gudangNama),
                ],
              ),
              pw.SizedBox(height: 10),

              // Detail Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(fontSize: 9),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2C3E50'),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.center,
                columnWidths: {
                  0: pw.FixedColumnWidth(25),
                  1: pw.FixedColumnWidth(40),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FixedColumnWidth(50),
                },
                headers: ['No', 'Kode', 'Nama Item', 'Jumlah'],
                data: details.isEmpty
                    ? [
                  ['', '', 'Tidak ada item', '']
                ]
                    : details.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final item = e.value;
                  return [
                    idx.toString(),
                    (item['mutcd_brg_kode'] ?? '-').toString(),
                    (item['item_nama'] ?? '-').toString(),
                    (item['mutcd_qty'] ?? 0).toString(),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),

              // Tanda Tangan
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildTtdColumn('Disiapkan Oleh'),
                  _buildTtdColumn('Checker'),
                  _buildTtdColumn('Diterima Oleh'),
                ],
              ),
              pw.SizedBox(height: 10),

              // Footer
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Print — otomatis tampil print dialog di web, share di mobile
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'MutasiOut_$nomor.pdf',
    );
  }

  pw.TableRow _buildInfoRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('$label1', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(':', style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(value1, style: pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(width: 12),
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('$label2', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(':', style: pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(value2, style: pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  pw.Widget _buildTtdColumn(String jabatan) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 35),
        pw.Text('(_______________)', style: pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text(jabatan, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  Future<void> _exportToExcel() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Mutasi Out';

      // Lebar kolom
      sheet.getRangeByIndex(1, 1).columnWidth = 6;   // No
      sheet.getRangeByIndex(1, 2).columnWidth = 18;  // Nomor
      sheet.getRangeByIndex(1, 3).columnWidth = 12;  // Tanggal
      sheet.getRangeByIndex(1, 4).columnWidth = 25;  // Keterangan
      sheet.getRangeByIndex(1, 5).columnWidth = 12;  // Status
      sheet.getRangeByIndex(1, 6).columnWidth = 6;   // No Detail
      sheet.getRangeByIndex(1, 7).columnWidth = 25;  // Nama Item
      sheet.getRangeByIndex(1, 8).columnWidth = 8;   // Tipe
      sheet.getRangeByIndex(1, 9).columnWidth = 10;  // Qty

      // Periode
      final periodeRange = sheet.getRangeByIndex(1, 1, 1, 5);
      periodeRange.merge();
      periodeRange.setText('Periode: ${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}');
      periodeRange.cellStyle.fontSize = 11;
      periodeRange.cellStyle.bold = true;
      periodeRange.cellStyle.backColor = '#F1F5F9';

      // Header Mutasi
      int row = 3;
      final headerRange = sheet.getRangeByIndex(row, 1, row, 5);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByIndex(row, 1).setText('No');
      sheet.getRangeByIndex(row, 2).setText('Nomor');
      sheet.getRangeByIndex(row, 3).setText('Tanggal');
      sheet.getRangeByIndex(row, 4).setText('Keterangan');
      sheet.getRangeByIndex(row, 5).setText('Status');
      row++;

      int noMutasi = 1;
      for (var mutasi in _mutasiList) {
        final nomor = mutasi['mutc_nomor']?.toString() ?? '-';
        final tanggal = _formatDate(mutasi['mutc_tanggal'] ?? '');
        final keterangan = mutasi['mutc_keterangan']?.toString() ?? '-';
        final gudang = mutasi['gudang_nama'] ?? mutasi['mutc_gdg_kode'] ?? '-';
        final cabang = mutasi['cabang_nama'] ?? mutasi['mutc_cbg_tujuan'] ?? '-';
        final status = mutasi['mutc_status'] == 1 ? 'Closed' : 'Open';
        final info = '$nomor | $gudang → $cabang';

        // Row Mutasi
        sheet.getRangeByIndex(row, 1).setText(noMutasi.toString());
        sheet.getRangeByIndex(row, 2).setText(info);
        sheet.getRangeByIndex(row, 3).setText(tanggal);
        sheet.getRangeByIndex(row, 4).setText(keterangan);
        sheet.getRangeByIndex(row, 5).setText(status);

        final dataRange = sheet.getRangeByIndex(row, 1, row, 5);
        dataRange.cellStyle.fontSize = 9;
        sheet.getRangeByIndex(row, 1).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 3).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 5).cellStyle.hAlign = HAlignType.center;

        if (status == 'Closed') {
          sheet.getRangeByIndex(row, 5).cellStyle.fontColor = '#06D6A0';
        } else {
          sheet.getRangeByIndex(row, 5).cellStyle.fontColor = '#F6A918';
        }
        row++;

        // Header Detail
        final detailHeaderRange = sheet.getRangeByIndex(row, 6, row, 9);
        detailHeaderRange.cellStyle.backColor = '#34495E';
        detailHeaderRange.cellStyle.fontColor = '#FFFFFF';
        detailHeaderRange.cellStyle.bold = true;
        detailHeaderRange.cellStyle.fontSize = 9;
        detailHeaderRange.cellStyle.hAlign = HAlignType.center;

        sheet.getRangeByIndex(row, 6).setText('No');
        sheet.getRangeByIndex(row, 7).setText('Nama Item');
        sheet.getRangeByIndex(row, 8).setText('Tipe');
        sheet.getRangeByIndex(row, 9).setText('Qty');
        row++;

        // Detail Items
        try {
          final detailData = await DoService.getMutasiDetail(nomor);
          final details = List<Map<String, dynamic>>.from(detailData['details'] ?? []);

          if (details.isNotEmpty) {
            int noDetail = 1;
            for (var item in details) {
              final tipe = item['mutcd_tipe'] ?? 'BJ';
              final tipeLabel = tipe == 'BJ' ? 'BJ' : 'STJ';
              final qty = _parseInt(item['mutcd_qty']);

              sheet.getRangeByIndex(row, 6).setText(noDetail.toString());
              sheet.getRangeByIndex(row, 7).setText(item['item_nama']?.toString() ?? '-');
              sheet.getRangeByIndex(row, 8).setText(tipeLabel);
              sheet.getRangeByIndex(row, 9).setNumber(qty.toDouble());

              final detailRange = sheet.getRangeByIndex(row, 6, row, 9);
              detailRange.cellStyle.fontSize = 9;
              sheet.getRangeByIndex(row, 6).cellStyle.hAlign = HAlignType.center;
              sheet.getRangeByIndex(row, 8).cellStyle.hAlign = HAlignType.center;
              sheet.getRangeByIndex(row, 9).cellStyle.hAlign = HAlignType.center;

              if (row % 2 == 0) detailRange.cellStyle.backColor = '#F8FAFC';

              noDetail++;
              row++;
            }
          } else {
            sheet.getRangeByIndex(row, 6).setText('');
            sheet.getRangeByIndex(row, 7).setText('(Tidak ada item)');
            sheet.getRangeByIndex(row, 7).cellStyle.italic = true;
            sheet.getRangeByIndex(row, 7).cellStyle.fontColor = '#94A3B8';
            row++;
          }
        } catch (e) {
          sheet.getRangeByIndex(row, 6).setText('');
          sheet.getRangeByIndex(row, 7).setText('(Gagal memuat)');
          sheet.getRangeByIndex(row, 7).cellStyle.fontColor = '#EF4444';
          sheet.getRangeByIndex(row, 7).cellStyle.italic = true;
          row++;
        }

        row++;
        noMutasi++;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = 'MutasiOut_Detail_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download');
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/MutasiOut_Detail_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
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
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Mutasi Out',
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
                    onPressed: _loadMutasiData,
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
                  const SizedBox(width: 8),
                  // Tambah Button
                  _buildActionButton(
                    icon: Icons.add,
                    label: isMobile ? 'Tambah' : 'Tambah',
                    color: _primaryDark,
                    onPressed: _openAddMutasi,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _mutasiList.isEmpty
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
                              _buildGridColumn('gudang', 'Gudang Asal', width: _columnWidths['gudang'], alignment: Alignment.center),
                              _buildGridColumn('cbg_tujuan', 'Cabang Tujuan', width: _columnWidths['cbg_tujuan'], alignment: Alignment.center),
                              _buildGridColumn('status', 'Status', width: _columnWidths['status'], alignment: Alignment.center),
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
                                Text('$_totalFilteredMutasi Transaksi', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
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
            child: Icon(Icons.local_shipping_outlined, size: 28, color: _textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada data mutasi out', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class MutasiDataSource extends DataGridSource {
  MutasiDataSource({
    required List<Map<String, dynamic>> mutasiList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required String Function(String) formatDate,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatDate = formatDate;
    _updateDataSource(mutasiList);
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

  void _updateDataSource(List<Map<String, dynamic>> mutasiList) {
    _data = mutasiList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final mutasi = entry.value;
      final status = mutasi['mutc_status'] == 1 ? 'Closed' : 'Open';
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: mutasi['mutc_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(mutasi['mutc_tanggal'] ?? '')),
        DataGridCell<String>(columnName: 'keterangan', value: mutasi['mutc_keterangan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'gudang', value: mutasi['mutc_gdg_kode']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'cbg_tujuan', value: mutasi['mutc_cbg_tujuan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'status', value: status),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: mutasi),
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
          final mutasi = cell.value as Map<String, dynamic>;
          final isClosed = mutasi['mutc_status'] == 1;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(
                  Icons.edit_outlined,
                  isClosed ? null : () => _onEdit(mutasi),
                  color: isClosed ? _textTertiary : null,
                ),
                const SizedBox(width: 4),
                _buildIconButton(
                  Icons.delete_outlined,
                  isClosed ? null : () => _onDelete(mutasi),
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
    if (columnName == 'aksi' || columnName == 'no' || columnName == 'tanggal' || columnName == 'gudang' || columnName == 'cbg_tujuan' || columnName == 'status') {
      return Alignment.center;
    }
    return Alignment.centerLeft;
  }
}

class MutasiDetailDataSource extends DataGridSource {
  MutasiDetailDataSource({required List<Map<String, dynamic>> details, required NumberFormat numberFormat}) {
    _numberFormat = numberFormat;
    _data = details.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      final tipe = item['mutcd_tipe'] ?? 'BJ';
      int qty = 0;
      final rawQty = item['mutcd_qty'];
      if (rawQty is int) qty = rawQty;
      else if (rawQty is double) qty = rawQty.toInt();
      else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item['item_nama']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tipe', value: tipe),
        DataGridCell<int>(columnName: 'qty', value: qty),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _numberFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentMint = Color(0xFF06D6A0);

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'tipe') {
          final tipe = cell.value.toString();
          final isBJ = tipe == 'BJ';
          final color = isBJ ? _accentBlue : _accentMint;
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(isBJ ? 'BJ' : 'STJ', style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ),
          );
        }
        if (cell.columnName == 'qty') {
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _accentMint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(_numberFormat.format(cell.value), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint)),
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