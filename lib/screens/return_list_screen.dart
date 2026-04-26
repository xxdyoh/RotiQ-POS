import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/return_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';
import '../utils/responsive_helper.dart';

class ReturnListScreen extends StatefulWidget {
  const ReturnListScreen({super.key});

  @override
  State<ReturnListScreen> createState() => _ReturnListScreenState();
}

class _ReturnListScreenState extends State<ReturnListScreen> {
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

  final NumberFormat _numberFormat = NumberFormat('#,##0');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  late Map<String, double> _columnWidths = {
    'no': 60,
    'nomor': 160,
    'tanggal': 120,
    'keterangan': 400,
    'aksi': 80,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _returnList = [];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  late ReturnDataSource _dataSource;
  int _totalFilteredReturn = 0;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _loadReturnData();
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

  Future<void> _loadReturnData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ReturnService.getReturnList(
        search: null,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );

      setState(() {
        _returnList = data;
        _totalFilteredReturn = data.length;
        _dataSource = ReturnDataSource(
          returnList: data,
          onEdit: _openEditReturn,
          onDelete: _deleteReturn,
          formatDate: _formatDate,
        );
      });
    } catch (e) {
      _showSnackbar('Gagal memuat data return', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        setState(() => _totalFilteredReturn = _dataSource.effectiveRows!.length);
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

  void _openAddReturn() {
    Navigator.pushNamed(
      context,
      AppRoutes.returnProductionForm,
      arguments: {'onSaved': _loadReturnData},
    );
  }

  void _openEditReturn(Map<String, dynamic> returnData) {
    Navigator.pushNamed(
      context,
      AppRoutes.returnProductionForm,
      arguments: {
        'returnHeader': returnData,
        'onSaved': _loadReturnData,
      },
    );
  }

  void _deleteReturn(Map<String, dynamic> returnData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Hapus Return', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus "${returnData['ret_nomor']}"?', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(returnData);
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

  Future<void> _performDelete(Map<String, dynamic> returnData) async {
    setState(() => _isLoading = true);
    try {
      final result = await ReturnService.deleteReturn(returnData['ret_nomor'].toString());
      if (result['success']) {
        _showSnackbar(result['message']);
        await _loadReturnData();
      } else {
        _showSnackbar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> returnData) {
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
                      child: Icon(Icons.assignment_return, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Return', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(returnData['ret_nomor'] ?? '-', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white.withOpacity(0.8))),
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
                                Text(DateFormat('dd MMMM yyyy').format(DateTime.parse(returnData['ret_tanggal'])),
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
                            child: Icon(Icons.description, size: 14, color: _accentBlue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Keterangan', style: GoogleFonts.montserrat(fontSize: 9, color: _textTertiary)),
                                Text(returnData['ret_keterangan'] ?? '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  future: ReturnService.getReturnDetail(returnData['ret_nomor'].toString()),
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
                                  source: ReturnDetailDataSource(details: details, numberFormat: _numberFormat),
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
                                        width: 100,
                                        label: Container(alignment: Alignment.center, child: Text('Quantity', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10)))),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Return Production',
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
                    onPressed: _loadReturnData,
                    isMobile: isMobile,
                  ),
                  const SizedBox(width: 8),
                  // Tambah Button
                  _buildActionButton(
                    icon: Icons.add,
                    label: isMobile ? 'Tambah' : 'Tambah',
                    color: _primaryDark,
                    onPressed: _openAddReturn,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            // Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _returnList.isEmpty
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
                                Text('$_totalFilteredReturn Transaksi', style: GoogleFonts.montserrat(fontSize: 10, color: _textSecondary)),
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
            child: Icon(Icons.assignment_return_outlined, size: 28, color: _textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada data return', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Klik "Tambah" untuk memulai', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ========== DATASOURCE ==========
class ReturnDataSource extends DataGridSource {
  ReturnDataSource({
    required List<Map<String, dynamic>> returnList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required String Function(String) formatDate,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatDate = formatDate;
    _updateDataSource(returnList);
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late String Function(String) _formatDate;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _primaryDark = Color(0xFF2C3E50);

  void _updateDataSource(List<Map<String, dynamic>> returnList) {
    _data = returnList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final ret = entry.value;
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: ret['ret_nomor']?.toString() ?? '-'),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(ret['ret_tanggal']?.toString() ?? '')),
        DataGridCell<String>(columnName: 'keterangan', value: ret['ret_keterangan']?.toString() ?? '-'),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: ret),
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
          final ret = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconButton(Icons.edit_outlined, () => _onEdit(ret), color: _primaryDark),
                const SizedBox(width: 4),
                _buildIconButton(Icons.delete_outlined, () => _onDelete(ret), color: _accentRed),
              ],
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

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color ?? _textSecondary),
        ),
      ),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'aksi' || columnName == 'no' || columnName == 'tanggal') return Alignment.center;
    return Alignment.centerLeft;
  }
}

class ReturnDetailDataSource extends DataGridSource {
  ReturnDetailDataSource({required List<Map<String, dynamic>> details, required NumberFormat numberFormat}) {
    _numberFormat = numberFormat;
    _data = details.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: item['item_nama']?.toString() ?? '-'),
        DataGridCell<int>(columnName: 'qty', value: item['retd_qty'] ?? 0),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _numberFormat;

  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
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