import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/return_service.dart';
import '../routes/app_routes.dart';
import '../widgets/base_layout.dart';

class ReturnListScreen extends StatefulWidget {
  const ReturnListScreen({super.key});

  @override
  State<ReturnListScreen> createState() => _ReturnListScreenState();
}

class _ReturnListScreenState extends State<ReturnListScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _returnList = [];

  final DataGridController _dataGridController = DataGridController();
  late ReturnDataSource _dataSource;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showDateFilter = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate.year, _endDate.month, 1);
    _updateDateControllers();
    _dataSource = ReturnDataSource(returnList: [], onEdit: _openEditReturn, onDelete: _deleteReturn);
    _loadReturnData();
  }

  void _updateDateControllers() {
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
  }

  String _formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadReturnData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final returnData = await ReturnService.getReturnList(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        startDate: _formatDateForApi(_startDate),
        endDate: _formatDateForApi(_endDate),
      );
      setState(() {
        _returnList = returnData;
        _dataSource = ReturnDataSource(
          returnList: _returnList,
          onEdit: _openEditReturn,
          onDelete: _deleteReturn,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data return production: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF6A918),
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
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

      _loadReturnData();
    }
  }

  void _resetDateFilter() {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime(_endDate.year, _endDate.month, 1);
      _updateDateControllers();
      _loadReturnData();
    });
  }

  void _toggleDateFilter() {
    setState(() {
      _showDateFilter = !_showDateFilter;
    });
  }

  void _filterReturn(String query) {
    _loadReturnData();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _openAddReturn() {
    Navigator.pushNamed(
      context,
      AppRoutes.returnProductionForm,
      arguments: {
        'onSaved': _loadReturnData,
      },
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
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Hapus Return?',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${returnData['ret_nomor']}"?',
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(returnData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> returnData) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ReturnService.deleteReturn(returnData['ret_nomor'].toString());

      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadReturnData();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Return Production',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // ========== FILTER TANGGAL SECTION ==========
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Tanggal',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showDateFilter ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: const Color(0xFFF6A918),
                      ),
                      onPressed: _toggleDateFilter,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30),
                    ),
                  ],
                ),
              ),

              if (_showDateFilter) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal Mulai',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextField(
                                              controller: _startDateController,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                              ),
                                              enabled: false,
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal Selesai',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300, width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextField(
                                              controller: _endDateController,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                              ),
                                              enabled: false,
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: _resetDateFilter,
                          icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                          label: Text(
                            'Reset ke Awal Bulan',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ========== SEARCH SECTION ==========
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari nomor/keterangan...',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterReturn,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterReturn('');
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _openAddReturn,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text(
                          'Tambah',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6A918),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== SUMMARY ==========
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ${_dataSource.rows.length} return',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Periode: ${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF6A918),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ========== DATA GRID ==========
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                    : _returnList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_return_outlined,
                        size: 36,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data return'
                            : 'Return tidak ditemukan',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SfDataGrid(
                      controller: _dataGridController,
                      source: _dataSource,
                      allowColumnsResizing: true,
                      columnResizeMode: ColumnResizeMode.onResize,
                      columnWidthMode: ColumnWidthMode.auto,
                      headerRowHeight: 32,
                      rowHeight: 30,
                      allowSorting: true,
                      allowFiltering: true,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      selectionMode: SelectionMode.single,

                      stackedHeaderRows: [
                        StackedHeaderRow(
                          cells: [
                            StackedHeaderCell(
                              columnNames: ['no', 'nomor', 'tanggal', 'keterangan', 'aksi'],
                              child: Container(
                                height: 12,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.filter_list, size: 10, color: Colors.grey[500]),
                                    const SizedBox(width: 2),
                                    Icon(Icons.unfold_more, size: 10, color: Colors.grey[500]),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      columns: [
                        GridColumn(
                          columnName: 'no',
                          minimumWidth: 50,
                          maximumWidth: 60,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'No',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'nomor',
                          minimumWidth: 150,
                          maximumWidth: 180,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nomor',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'tanggal',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Tanggal',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'keterangan',
                          minimumWidth: 250,
                          maximumWidth: 350,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Keterangan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'aksi',
                          minimumWidth: 80,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text(
                              'Aksi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReturnDataSource extends DataGridSource {
  ReturnDataSource({
    required List<Map<String, dynamic>> returnList,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;

    _data = returnList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final ret = entry.value;

      final nomor = ret['ret_nomor']?.toString() ?? '-';
      final tanggal = _formatDate(ret['ret_tanggal']?.toString() ?? '');
      final keterangan = ret['ret_keterangan']?.toString() ?? '-';

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: nomor),
        DataGridCell<String>(columnName: 'tanggal', value: tanggal),
        DataGridCell<String>(columnName: 'keterangan', value: keterangan),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: ret),
      ]);
    }).toList();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;

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
                // Tombol Edit
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                    onPressed: () => _onEdit(ret),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 2),
                // Tombol Delete
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                    onPressed: () => _onDelete(ret),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: Colors.black87,
            ),
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

  FontWeight _getFontWeight(String columnName) {
    return FontWeight.normal;
  }
}