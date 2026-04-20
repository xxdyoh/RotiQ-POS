import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/uangmuka_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';
import '../services/universal_printer_service.dart';
import '../utils/responsive_helper.dart';

class UangMukaListScreen extends StatefulWidget {
  const UangMukaListScreen({super.key});

  @override
  State<UangMukaListScreen> createState() => _UangMukaListScreenState();
}

class _UangMukaListScreenState extends State<UangMukaListScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Warna modern dari StokinListScreen
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

  // Soft versions
  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);
  final Color _accentSkySoft = const Color(0xFF4CC9F0).withOpacity(0.1);

  late Map<String, double> _columnWidths = {
    'no': 60,
    'nomor': 160,
    'tanggal': 100,
    'customer': 200,
    'nilai': 140,
    'jenis_bayar': 100,
    'status': 100,
    'aksi': 120,
  };

  bool _isLoading = false;
  bool _showDateFilter = false;
  List<Map<String, dynamic>> _uangMukaList = [];

  // Filter tanggal
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late UangMukaDataSource _dataSource;

  int _totalFilteredUangMuka = 0;
  double _totalFilteredNilai = 0;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();

    // Animation
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
    _loadUangMukaData();
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

  Future<void> _loadUangMukaData() async {
    setState(() => _isLoading = true);
    try {
      final uangMukaData = await UangMukaService.getUangMukaList(
        search: null,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _uangMukaList = uangMukaData;
        _totalFilteredUangMuka = uangMukaData.length;
        _totalFilteredNilai = uangMukaData.fold(0.0, (sum, item) {
          return sum + (double.tryParse(item['um_nilai']?.toString() ?? '0') ?? 0);
        });
        _dataSource = UangMukaDataSource(
          uangMukaList: uangMukaData,
          onEdit: _openEditUangMuka,
          onDelete: _deleteUangMuka,
          onPrint: _printUangMuka,
          primaryDark: _primaryDark,
          accentGold: _accentGold,
          accentMint: _accentMint,
          accentCoral: _accentCoral,
          accentSky: _accentSky,
          accentMintSoft: _accentMintSoft,
          borderSoft: _borderSoft,
          bgSoft: _bgSoft,
          textDark: _textDark,
          textMedium: _textMedium,
          textLight: _textLight,
          formatDate: _formatDate,
          currencyFormat: _currencyFormat,
        );
      });
    } catch (e) {
      _showToast('Gagal memuat data uang muka: ${e.toString()}', type: ToastType.error);
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
          _totalFilteredUangMuka = filteredData.length;
          _totalFilteredNilai = filteredData.fold(0.0, (sum, item) {
            return sum + (double.tryParse(item['um_nilai']?.toString() ?? '0') ?? 0);
          });
        });
      }
    });
  }

  // Modern Toast
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

  void _openAddUangMuka() {
    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm,
      arguments: {
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _openEditUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showToast('Uang muka sudah direalisasi, tidak dapat diubah', type: ToastType.info);
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.uangMukaForm,
      arguments: {
        'uangMuka': uangMuka,
        'onSaved': _loadUangMukaData,
      },
    );
  }

  void _deleteUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showToast('Uang muka sudah direalisasi, tidak dapat dihapus', type: ToastType.info);
      return;
    }

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
                'Hapus Uang Muka',
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
            'Apakah Anda yakin ingin menghapus "${uangMuka['um_nomor']}"?',
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
                await _performDelete(uangMuka);
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

  Future<void> _performDelete(Map<String, dynamic> uangMuka) async {
    setState(() => _isLoading = true);
    try {
      final result = await UangMukaService.deleteUangMuka(uangMuka['um_nomor'].toString());
      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        await _loadUangMukaData();
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printUangMuka(Map<String, dynamic> uangMuka) async {
    try {
      final tanggal = DateTime.parse(uangMuka['um_tanggal']?.toString() ?? DateTime.now().toString());
      final customer = uangMuka['um_customer']?.toString() ?? '-';
      final nilai = double.tryParse(uangMuka['um_nilai']?.toString() ?? '0') ?? 0;
      final jenisBayar = uangMuka['um_jenisbayar']?.toString() ?? 'Cash';
      final keterangan = uangMuka['um_keterangan']?.toString();
      final isRealisasi = (uangMuka['um_isrealisasi'] ?? 0) == 1;
      final nomor = uangMuka['um_nomor']?.toString() ?? '';

      final success = await UniversalPrinterService().printUangMukaReceipt(
        nomor: nomor,
        tanggal: tanggal,
        customer: customer,
        nilai: nilai,
        jenisBayar: jenisBayar,
        keterangan: keterangan,
        isRealisasi: isRealisasi,
      );

      if (success) {
        _showToast('Berhasil mencetak uang muka', type: ToastType.success);
      } else {
        _showToast('Gagal mencetak. Pastikan printer terhubung.', type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error saat mencetak: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Uang Muka',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: _bgSoft,
          child: Column(
            children: [
              // Header dengan filter dan tombol aksi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceWhite,
                  border: Border(bottom: BorderSide(color: _borderSoft)),
                ),
                child: Row(
                  children: [
                    // Filter tanggal toggle
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

                    // Tambah Button
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
                          onTap: _openAddUangMuka,
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

              // Date Filter Panel - Satu Baris dengan Tombol Load
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
                      // Tanggal Mulai
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

                      // Tanggal Selesai
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

                      // Load Button dengan Icon
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
                            onTap: () => _loadUangMukaData(),
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

              // DataGrid
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
                        'Memuat data uang muka...',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: _textMedium,
                        ),
                      ),
                    ],
                  ),
                )
                    : _uangMukaList.isEmpty
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
                          Icons.payment_outlined,
                          size: 35,
                          color: _textLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada data uang muka',
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
                                  width: _columnWidths['nomor'] ?? 160,
                                  minimumWidth: 140,
                                  maximumWidth: 900,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                  columnName: 'customer',
                                  width: _columnWidths['customer'] ?? 200,
                                  minimumWidth: 150,
                                  maximumWidth: 900,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Customer',
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
                                  width: _columnWidths['nilai'] ?? 140,
                                  minimumWidth: 120,
                                  maximumWidth: 200,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                  columnName: 'jenis_bayar',
                                  width: _columnWidths['jenis_bayar'] ?? 100,
                                  minimumWidth: 80,
                                  maximumWidth: 140,
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Jenis Bayar',
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
                                  width: _columnWidths['status'] ?? 100,
                                  minimumWidth: 80,
                                  maximumWidth: 140,
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
                                  width: _columnWidths['aksi'] ?? 120,
                                  minimumWidth: 100,
                                  maximumWidth: 150,
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
                        // Footer Total
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
                                    width: _columnWidths['nomor'] ?? 160,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt, size: 11, color: _primaryDark),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_totalFilteredUangMuka Transaksi',
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
                                    width: _columnWidths['customer'] ?? 200,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Total Nilai: ',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _textDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: _columnWidths['nilai'] ?? 140,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _currencyFormat.format(_totalFilteredNilai),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _accentGold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: (_columnWidths['jenis_bayar'] ?? 100) + (_columnWidths['status'] ?? 100),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: const SizedBox(),
                                  ),
                                  Container(
                                    width: _columnWidths['aksi'] ?? 120,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: _totalFilteredUangMuka < _uangMukaList.length
                                        ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _accentGoldSoft,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_uangMukaList.length - _totalFilteredUangMuka} filter',
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

class UangMukaDataSource extends DataGridSource {
  UangMukaDataSource({
    required List<Map<String, dynamic>> uangMukaList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required Function(Map<String, dynamic>) onPrint,
    required Color primaryDark,
    required Color accentGold,
    required Color accentMint,
    required Color accentCoral,
    required Color accentSky,
    required Color accentMintSoft,
    required Color borderSoft,
    required Color bgSoft,
    required Color textDark,
    required Color textMedium,
    required Color textLight,
    required String Function(String) formatDate,
    required NumberFormat currencyFormat,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _onPrint = onPrint;
    _primaryDark = primaryDark;
    _accentGold = accentGold;
    _accentMint = accentMint;
    _accentCoral = accentCoral;
    _accentSky = accentSky;
    _accentMintSoft = accentMintSoft;
    _borderSoft = borderSoft;
    _bgSoft = bgSoft;
    _textDark = textDark;
    _textMedium = textMedium;
    _textLight = textLight;
    _formatDate = formatDate;
    _currencyFormat = currencyFormat;

    _updateDataSource(uangMukaList);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late Function(Map<String, dynamic>) _onPrint;
  late Color _primaryDark;
  late Color _accentGold;
  late Color _accentMint;
  late Color _accentCoral;
  late Color _accentSky;
  late Color _accentMintSoft;
  late Color _borderSoft;
  late Color _bgSoft;
  late Color _textDark;
  late Color _textMedium;
  late Color _textLight;
  late String Function(String) _formatDate;
  late NumberFormat _currencyFormat;

  void _updateDataSource(List<Map<String, dynamic>> uangMukaList) {
    _data = uangMukaList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final um = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: um['um_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(um['um_tanggal']?.toString() ?? '')),
        DataGridCell<String>(columnName: 'customer', value: um['um_customer']?.toString() ?? '-'),
        DataGridCell<double>(columnName: 'nilai', value: double.tryParse(um['um_nilai']?.toString() ?? '0') ?? 0),
        DataGridCell<String>(columnName: 'jenis_bayar', value: um['um_jenisbayar']?.toString() ?? 'Cash'),
        DataGridCell<int>(columnName: 'status', value: um['um_isrealisasi'] ?? 0),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: um),
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
          final um = cell.value as Map<String, dynamic>;
          final isRealisasi = um['um_isrealisasi'] ?? 0;

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Print Button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentMintSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onPrint(um),
                      borderRadius: BorderRadius.circular(4),
                      child: Center(
                        child: Icon(
                          Icons.print_rounded,
                          size: 12,
                          color: _accentMint,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // Edit Button (hanya jika belum realisasi)
                if (isRealisasi == 0)
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
                        onTap: () => _onEdit(um),
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
                  )
                else
                  const SizedBox(width: 24),

                const SizedBox(width: 2),

                // Delete Button (hanya jika belum realisasi)
                if (isRealisasi == 0)
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
                        onTap: () => _onDelete(um),
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
                  )
                else
                  const SizedBox(width: 24),
              ],
            ),
          );
        }

        if (cell.columnName == 'status') {
          final isRealisasi = cell.value as int;
          final statusText = isRealisasi == 1 ? 'Realisasi' : 'Belum';
          final color = isRealisasi == 1 ? _accentMint : _accentGold;

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
                statusText,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          );
        }

        if (cell.columnName == 'nilai') {
          final nilai = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              _currencyFormat.format(nilai),
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _accentGold,
              ),
            ),
          );
        }

        if (cell.columnName == 'jenis_bayar') {
          final jenisBayar = cell.value.toString();
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _bgSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _borderSoft),
              ),
              child: Text(
                jenisBayar,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _textMedium,
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
              fontWeight: _getFontWeight(cell.columnName),
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
      case 'nilai':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      case 'jenis_bayar':
      case 'status':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'nilai':
        return TextAlign.right;
      case 'aksi':
      case 'jenis_bayar':
      case 'status':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'nilai') {
      return FontWeight.w600;
    }
    if (columnName == 'nomor') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}

// Toast Type enum
enum ToastType { success, error, info }