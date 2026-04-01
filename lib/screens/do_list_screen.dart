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
import '../services/do_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class DoListScreen extends StatefulWidget {
  const DoListScreen({super.key});

  @override
  State<DoListScreen> createState() => _DoListScreenState();
}

class _DoListScreenState extends State<DoListScreen> with SingleTickerProviderStateMixin {
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
    'no': 60,
    'nomor': 180,
    'tanggal': 100,
    'keterangan': 250,
    'gudang': 100,
    'cbg_tujuan': 100,
    'status': 90,
    'aksi': 90,
  };

  bool _isLoading = false;
  bool _showDateFilter = false;
  List<Map<String, dynamic>> _mutasiList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late MutasiDataSource _dataSource;

  int _totalFilteredMutasi = 0;

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
    _loadMutasiData();
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
      return DateFormat('dd/MM/yy HH:mm').format(date);
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
        _calculateTotals(data);
        _dataSource = MutasiDataSource(
          mutasiList: data,
          onEdit: _openEditMutasi,
          onDelete: _deleteMutasi,
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
      _showToast('Gagal memuat data mutasi out: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals(List<Map<String, dynamic>> mutasiList) {
    _totalFilteredMutasi = mutasiList.length;
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
          _totalFilteredMutasi = filteredData.length;
        });
      }
    });
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
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

  void _openAddMutasi() {
    Navigator.pushNamed(
      context,
      AppRoutes.doForm,
      arguments: {
        'onMutasiSaved': _loadMutasiData,
      },
    );
  }

  void _openEditMutasi(Map<String, dynamic> mutasiData) {
    Navigator.pushNamed(
      context,
      AppRoutes.doForm,
      arguments: {
        'mutasiHeader': mutasiData,
        'onMutasiSaved': _loadMutasiData,
      },
    );
  }

  void _deleteMutasi(Map<String, dynamic> mutasiData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        actionsPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _accentCoralSoft,
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
                  color: _accentCoral.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: _accentCoral,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Hapus Mutasi Out',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Apakah Anda yakin ingin menghapus "${mutasiData['mutc_nomor']}"?',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: _textMedium,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentCoral, _accentCoral.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _accentCoral.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performDelete(mutasiData);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Hapus',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> mutasiData) async {
    setState(() => _isLoading = true);
    try {
      final result = await DoService.deleteMutasi(mutasiData['mutc_nomor'].toString());
      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        await _loadMutasiData();
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> mutasiData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 900,
          height: 600,
          decoration: BoxDecoration(
            color: _surfaceWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.swap_horiz, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Mutasi Out',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mutasiData['mutc_nomor'] ?? '-',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bgSoft,
                  border: Border(bottom: BorderSide(color: _borderSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentGoldSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.calendar_today, size: 14, color: _accentGold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
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
                                  DateFormat('dd MMMM yyyy HH:mm').format(DateTime.parse(mutasiData['mutc_tanggal'])),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
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
                            decoration: BoxDecoration(
                              color: _accentSkySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.warehouse, size: 14, color: _accentSky),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gudang Asal',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: _textLight,
                                  ),
                                ),
                                Text(
                                  mutasiData['mutc_gdg_kode'] ?? '-',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _borderSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentGoldSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.business, size: 14, color: _accentGold),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cabang Tujuan',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: _textLight,
                                  ),
                                ),
                                Text(
                                  mutasiData['mutc_cbg_tujuan'] ?? '-',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
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
                            decoration: BoxDecoration(
                              color: _accentMintSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.note, size: 14, color: _accentMint),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keterangan',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    color: _textLight,
                                  ),
                                ),
                                Text(
                                  mutasiData['mutc_keterangan'] ?? '-',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
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
                  future: DoService.getMutasiDetail(mutasiData['mutc_nomor']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
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
                              'Memuat detail items...',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: _accentCoral,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat detail',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textMedium,
                              ),
                            ),
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
                              decoration: BoxDecoration(
                                color: _bgSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 30,
                                color: _textLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada item dalam mutasi ini',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: _textMedium,
                              ),
                            ),
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
                            decoration: BoxDecoration(
                              color: _bgSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderSoft),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _accentMintSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    size: 12,
                                    color: _accentMint,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Daftar Items (${details.length})',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: _borderSoft),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SfDataGrid(
                                  source: MutasiDetailDataSource(
                                    details: details,
                                    accentGold: _accentGold,
                                    textDark: _textDark,
                                    textMedium: _textMedium,
                                    accentMint: _accentMint,
                                    accentMintSoft: _accentMintSoft,
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
                                      columnName: 'nama',
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
                                      columnName: 'qty',
                                      width: 100,
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
                    Container(
                      width: 90,
                      height: 36,
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
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      final currentState = _key.currentState;
      if (currentState == null) return;

      final visibleRows = _dataSource.effectiveRows ?? _dataSource.rows;

      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Mutasi Out';

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 18;
      sheet.getRangeByIndex(1, 3).columnWidth = 10;
      sheet.getRangeByIndex(1, 4).columnWidth = 25;
      sheet.getRangeByIndex(1, 5).columnWidth = 12;
      sheet.getRangeByIndex(1, 6).columnWidth = 12;
      sheet.getRangeByIndex(1, 7).columnWidth = 10;

      final headerRange = sheet.getRangeByIndex(1, 1, 1, 7);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;
      headerRange.cellStyle.fontSize = 10;

      sheet.getRangeByName('A1').setText('No');
      sheet.getRangeByName('B1').setText('Nomor Mutasi');
      sheet.getRangeByName('C1').setText('Tanggal');
      sheet.getRangeByName('D1').setText('Keterangan');
      sheet.getRangeByName('E1').setText('Gudang Asal');
      sheet.getRangeByName('F1').setText('Cabang Tujuan');
      sheet.getRangeByName('G1').setText('Status');

      int rowIndex = 2;
      for (var row in visibleRows) {
        final cells = row.getCells();

        String no = '';
        String nomor = '';
        String tanggal = '';
        String keterangan = '';
        String gudang = '';
        String cbgTujuan = '';
        String status = '';

        for (var cell in cells) {
          if (cell.columnName == 'no') {
            no = cell.value.toString();
          } else if (cell.columnName == 'nomor') {
            nomor = cell.value.toString();
          } else if (cell.columnName == 'tanggal') {
            tanggal = cell.value.toString();
          } else if (cell.columnName == 'keterangan') {
            keterangan = cell.value.toString();
          } else if (cell.columnName == 'gudang') {
            gudang = cell.value.toString();
          } else if (cell.columnName == 'cbg_tujuan') {
            cbgTujuan = cell.value.toString();
          } else if (cell.columnName == 'status') {
            status = cell.value.toString();
          }
        }

        sheet.getRangeByName('A$rowIndex').setText(no);
        sheet.getRangeByName('B$rowIndex').setText(nomor);
        sheet.getRangeByName('C$rowIndex').setText(tanggal);
        sheet.getRangeByName('D$rowIndex').setText(keterangan);
        sheet.getRangeByName('E$rowIndex').setText(gudang);
        sheet.getRangeByName('F$rowIndex').setText(cbgTujuan);
        sheet.getRangeByName('G$rowIndex').setText(status);

        final dataRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 7);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;

        sheet.getRangeByName('A$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('B$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('C$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('D$rowIndex').cellStyle.hAlign = HAlignType.left;
        sheet.getRangeByName('E$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('F$rowIndex').cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByName('G$rowIndex').cellStyle.hAlign = HAlignType.center;

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

      sheet.getRangeByName('B$totalRow').setText('$_totalFilteredMutasi Mutasi');
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
          ..download = 'MutasiOut_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          ..click();
        html.Url.revokeObjectUrl(url);

        _showToast('File Excel berhasil di-download', type: ToastType.success);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/MutasiOut_List_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
        await file.writeAsBytes(bytes);
        _showToast('File Excel berhasil disimpan', type: ToastType.success);
      }
    } catch (e) {
      print('Error export Excel: $e');
      _showToast('Gagal export Excel: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Mutasi Out',
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
                        border: Border.all(
                          color: _showDateFilter ? _accentGold : _borderSoft,
                        ),
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
                                Icon(
                                  Icons.date_range,
                                  size: 14,
                                  color: _showDateFilter ? _accentGold : _textLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Filter',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _showDateFilter ? _accentGold : _textMedium,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showDateFilter ? Icons.expand_less : Icons.expand_more,
                                  size: 14,
                                  color: _showDateFilter ? _accentGold : _textLight,
                                ),
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
                          onTap: _exportToExcel,
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
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryDark, _primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryDark.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openAddMutasi,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                if (!isMobile) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tambah',
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
              if (_showDateFilter) ...[
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
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
                                        _startDateController.text,
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
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
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
                                        _endDateController.text,
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
                            onTap: () => _loadMutasiData(),
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
                        'Memuat data mutasi out...',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textMedium,
                        ),
                      ),
                    ],
                  ),
                )
                    : _mutasiList.isEmpty
                    ? Center(
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
                          Icons.swap_horiz,
                          size: 35,
                          color: _textLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada data mutasi out',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Klik tombol Tambah untuk memulai',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textLight,
                        ),
                      ),
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
                                  width: _columnWidths['no'] ?? 60,
                                  minimumWidth: 50,
                                  maximumWidth: 100,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                  columnName: 'nomor',
                                  width: _columnWidths['nomor'] ?? 180,
                                  minimumWidth: 160,
                                  maximumWidth: 900,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Nomor Mutasi',
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
                                  minimumWidth: 80,
                                  maximumWidth: 140,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                  columnName: 'keterangan',
                                  width: _columnWidths['keterangan'] ?? 250,
                                  minimumWidth: 200,
                                  maximumWidth: 350,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
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
                                  columnName: 'gudang',
                                  width: _columnWidths['gudang'] ?? 100,
                                  minimumWidth: 80,
                                  maximumWidth: 120,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Gudang Asal',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'cbg_tujuan',
                                  width: _columnWidths['cbg_tujuan'] ?? 100,
                                  minimumWidth: 80,
                                  maximumWidth: 120,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Cabang Tujuan',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'status',
                                  width: _columnWidths['status'] ?? 90,
                                  minimumWidth: 80,
                                  maximumWidth: 120,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Status',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                ),
                                GridColumn(
                                  columnName: 'aksi',
                                  width: _columnWidths['aksi'] ?? 90,
                                  minimumWidth: 80,
                                  maximumWidth: 120,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Aksi',
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
                              width: screenWidth - (isTablet ? 64 : 56),
                              child: Row(
                                children: [
                                  Container(
                                    width: _columnWidths['no'] ?? 60,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                    width: _columnWidths['nomor'] ?? 180,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt, size: 11, color: _primaryDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_totalFilteredMutasi Mutasi',
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
                                    width: _columnWidths['tanggal'] ?? 100,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: _columnWidths['keterangan'] ?? 250,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerLeft,
                                    child: const SizedBox(),
                                  ),
                                  Container(
                                    width: (_columnWidths['gudang'] ?? 100) + (_columnWidths['cbg_tujuan'] ?? 100),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: const SizedBox(),
                                  ),
                                  Container(
                                    width: (_columnWidths['status'] ?? 90) + (_columnWidths['aksi'] ?? 90),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: _totalFilteredMutasi < _mutasiList.length
                                        ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _accentGoldSoft,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_mutasiList.length - _totalFilteredMutasi} filter',
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
        ),
      ),
    );
  }
}

class MutasiDataSource extends DataGridSource {
  MutasiDataSource({
    required List<Map<String, dynamic>> mutasiList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
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
    _onEdit = onEdit;
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

    _updateDataSource(mutasiList);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
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

  void _updateDataSource(List<Map<String, dynamic>> mutasiList) {
    _data = mutasiList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final data = entry.value;
      final status = data['mutc_status'] == 1 ? 'Closed' : 'Open';

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: data['mutc_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(data['mutc_tanggal'] ?? '')),
        DataGridCell<String>(columnName: 'keterangan', value: data['mutc_keterangan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'gudang', value: data['mutc_gdg_kode']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'cbg_tujuan', value: data['mutc_cbg_tujuan']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'status', value: status),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: data),
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
          final data = cell.value as Map<String, dynamic>;
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
                    color: _primaryDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onEdit(data),
                      borderRadius: BorderRadius.circular(4),
                      child: Center(
                        child: Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: _primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentCoral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onDelete(data),
                      borderRadius: BorderRadius.circular(4),
                      child: Center(
                        child: Icon(
                          Icons.delete_rounded,
                          size: 12,
                          color: _accentCoral,
                        ),
                      ),
                    ),
                  ),
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                status,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
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
      case 'status':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'aksi':
      case 'status':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }
}

class MutasiDetailDataSource extends DataGridSource {
  MutasiDetailDataSource({
    required List<Map<String, dynamic>> details,
    required Color accentGold,
    required Color textDark,
    required Color textMedium,
    required Color accentMint,
    required Color accentMintSoft,
  }) {
    _accentGold = accentGold;
    _textDark = textDark;
    _textMedium = textMedium;
    _accentMint = accentMint;
    _accentMintSoft = accentMintSoft;

    _data = details.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      int qty = 0;
      final rawQty = item['mutcd_qty'];
      if (rawQty is int) qty = rawQty;
      else if (rawQty is double) qty = rawQty.toInt();
      else if (rawQty is String) qty = int.tryParse(rawQty) ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item['item_nama']?.toString() ?? '-'),
        DataGridCell<int>(columnName: 'qty', value: qty),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late Color _accentGold;
  late Color _textDark;
  late Color _textMedium;
  late Color _accentMint;
  late Color _accentMintSoft;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'qty') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _accentMintSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentMint.withOpacity(0.3)),
              ),
              child: Text(
                cell.value.toString(),
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accentMint,
                ),
              ),
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