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

class _UangMukaListScreenState extends State<UangMukaListScreen> {
  final GlobalKey<SfDataGridState> _key = GlobalKey<SfDataGridState>();
  final DataGridController _dataGridController = DataGridController();

  // Color Palette - Minimalis dengan aksen primary
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

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  late Map<String, double> _columnWidths = {
    'no': 60,
    'nomor': 160,
    'tanggal': 100,
    'customer': 200,
    'nilai': 140,
    'jenis_bayar': 100,
    'status': 100,
    'aksi': 100,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _uangMukaList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late UangMukaDataSource _dataSource;
  int _totalFilteredUangMuka = 0;
  double _totalFilteredNilai = 0;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadUangMukaData();
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

  Future<void> _loadUangMukaData() async {
    setState(() => _isLoading = true);
    try {
      final data = await UangMukaService.getUangMukaList(
        search: null,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _uangMukaList = data;
        _totalFilteredUangMuka = data.length;
        _totalFilteredNilai = data.fold(0.0, (sum, item) => sum + (double.tryParse(item['um_nilai']?.toString() ?? '0') ?? 0));
        _dataSource = UangMukaDataSource(
          uangMukaList: data,
          onEdit: _openEditUangMuka,
          onDelete: _deleteUangMuka,
          onPrint: _printUangMuka,
          formatDate: _formatDate,
          currencyFormat: _currencyFormat,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data uang muka', isError: true);
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
          if (aksiCell.value != null) filteredData.add(aksiCell.value as Map<String, dynamic>);
        }
        setState(() {
          _totalFilteredUangMuka = filteredData.length;
          _totalFilteredNilai = filteredData.fold(0.0, (sum, item) => sum + (double.tryParse(item['um_nilai']?.toString() ?? '0') ?? 0));
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

  void _openAddUangMuka() {
    Navigator.pushNamed(context, AppRoutes.uangMukaForm, arguments: {'onSaved': _loadUangMukaData});
  }

  void _openEditUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showSnackbar('Uang muka sudah direalisasi, tidak dapat diubah', isError: true);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.uangMukaForm, arguments: {'uangMuka': uangMuka, 'onSaved': _loadUangMukaData});
  }

  void _deleteUangMuka(Map<String, dynamic> uangMuka) {
    final isRealisasi = uangMuka['um_isrealisasi'] ?? 0;
    if (isRealisasi == 1) {
      _showSnackbar('Uang muka sudah direalisasi, tidak dapat dihapus', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Uang Muka', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${uangMuka['um_nomor']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(uangMuka);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500)),
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
        _showSnackbar(result['message']);
        await _loadUangMukaData();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
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
        nomor: nomor, tanggal: tanggal, customer: customer, nilai: nilai, jenisBayar: jenisBayar, keterangan: keterangan, isRealisasi: isRealisasi,
      );
      _showSnackbar(success ? 'Berhasil mencetak uang muka' : 'Gagal mencetak. Pastikan printer terhubung.', isError: !success);
    } catch (e) {
      _showSnackbar('Error saat mencetak: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Uang Muka',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header Actions - 1 Row dengan Filter
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
                        decoration: BoxDecoration(color: _surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _primaryDark),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_startDateController.text, style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary))),
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
                        decoration: BoxDecoration(color: _surfaceWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: _primaryDark),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_endDateController.text, style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Load Button
                  _buildActionButton(icon: Icons.refresh_rounded, label: 'Load', color: _accentMint, onPressed: _loadUangMukaData, isMobile: isMobile),
                  const SizedBox(width: 8),
                  // Tambah Button
                  _buildActionButton(icon: Icons.add, label: isMobile ? 'Tambah' : 'Tambah', color: _primaryDark, onPressed: _openAddUangMuka, isMobile: isMobile),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _uangMukaList.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                padding: EdgeInsets.only(left: isTablet ? 16 : 12, right: isTablet ? 16 : 12, bottom: isTablet ? 16 : 12),
                child: Container(
                  decoration: BoxDecoration(color: _surfaceWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
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
                              _buildGridColumn('nomor', 'Nomor', width: _columnWidths['nomor']),
                              _buildGridColumn('tanggal', 'Tanggal', width: _columnWidths['tanggal'], alignment: Alignment.center),
                              _buildGridColumn('customer', 'Customer', width: _columnWidths['customer']),
                              _buildGridColumn('nilai', 'Nilai', width: _columnWidths['nilai'], alignment: Alignment.centerRight),
                              _buildGridColumn('jenis_bayar', 'Jenis Bayar', width: _columnWidths['jenis_bayar'], alignment: Alignment.center),
                              _buildGridColumn('status', 'Status', width: _columnWidths['status'], alignment: Alignment.center),
                              _buildGridColumn('aksi', 'Aksi', width: _columnWidths['aksi'], alignment: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: _bgLight, border: Border(top: BorderSide(color: _borderColor)), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                        child: Row(
                          children: [
                            Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textPrimary)),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(Icons.receipt_outlined, size: 12, color: _textSecondary),
                                const SizedBox(width: 4),
                                Text('$_totalFilteredUangMuka Transaksi', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            Text('Total Nilai: ${_currencyFormat.format(_totalFilteredNilai)}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentGold)),
                            const SizedBox(width: 16),
                            Text('${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
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

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed, required bool isMobile}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              if (!isMobile) ...[const SizedBox(width: 6), Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white))],
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
      label: Container(padding: const EdgeInsets.symmetric(horizontal: 12), alignment: alignment, child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 10, color: _textSecondary))),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: _bgLight, shape: BoxShape.circle), child: Icon(Icons.payment_outlined, size: 28, color: _textTertiary)),
          const SizedBox(height: 16),
          Text('Belum ada data uang muka', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
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
    required String Function(String) formatDate,
    required NumberFormat currencyFormat,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _onPrint = onPrint;
    _formatDate = formatDate;
    _currencyFormat = currencyFormat;
    _updateDataSource(uangMukaList);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit, _onDelete, _onPrint;
  late String Function(String) _formatDate;
  late NumberFormat _currencyFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentMint = Color(0xFF06D6A0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _bgLight = Color(0xFFF7F9FC);        // <-- TAMBAHKAN
  static const Color _borderColor = Color(0xFFE2E8F0);    // <-- TAMBAHKAN

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.print_outlined, () => _onPrint(um), color: _accentMint),
                const SizedBox(width: 4),
                if (isRealisasi == 0) _buildIconButton(Icons.edit_outlined, () => _onEdit(um), color: _primaryDark),
                const SizedBox(width: 4),
                if (isRealisasi == 0) _buildIconButton(Icons.delete_outlined, () => _onDelete(um), color: _accentRed),
              ],
            ),
          );
        }
        if (cell.columnName == 'status') {
          final isRealisasi = cell.value as int;
          final color = isRealisasi == 1 ? _accentMint : _accentGold;
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(isRealisasi == 1 ? 'Realisasi' : 'Belum', style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ),
          );
        }
        if (cell.columnName == 'nilai') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_currencyFormat.format(cell.value), style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _accentGold)),
          );
        }
        if (cell.columnName == 'jenis_bayar') {
          return Container(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(4), border: Border.all(color: _borderColor)),
              child: Text(cell.value.toString(), style: GoogleFonts.montserrat(fontSize: 9, color: _textSecondary)),
            ),
          );
        }
        Color textColor = _textPrimary;
        if (cell.columnName == 'no' || cell.columnName == 'tanggal') textColor = _textSecondary;
        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(cell.value.toString(), style: GoogleFonts.montserrat(fontSize: 11, fontWeight: cell.columnName == 'nomor' ? FontWeight.w500 : FontWeight.normal, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Container(padding: const EdgeInsets.all(5), child: Icon(icon, size: 15, color: color ?? _textSecondary))));
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'nilai') return Alignment.centerRight;
    if (columnName == 'aksi' || columnName == 'status' || columnName == 'jenis_bayar' || columnName == 'no' || columnName == 'tanggal') return Alignment.center;
    return Alignment.centerLeft;
  }
}