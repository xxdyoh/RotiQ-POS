import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:pivot_table/pivot_table.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/setengahjadi_stock_report_service.dart';
import '../models/setengahjadi_stock_report.dart';
import '../widgets/base_layout.dart';

class SetengahJadiStockReportScreen extends StatefulWidget {
  const SetengahJadiStockReportScreen({super.key});

  @override
  State<SetengahJadiStockReportScreen> createState() => _SetengahJadiStockReportScreenState();
}

class _SetengahJadiStockReportScreenState extends State<SetengahJadiStockReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<SetengahJadiStockReport> _stockData = [];
  bool _isLoading = false;
  bool _isLoadingDetail = false;
  String? _error;
  late SetengahJadiStockDataSource _dataSource;

  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name_asc';
  SetengahJadiStockSummary _stockSummary = SetengahJadiStockSummary(
    totalAwal: 0,
    totalStokIn: 0,
    totalStokOut: 0,
    totalAkhir: 0,
    totalItems: 0,
  );

  List<SetengahJadiStockReport> _filteredData = [];

  // Untuk detail dialog
  int _detailTab = 0;
  StockMovementDetail? _currentDetail;
  String? _currentDetailName;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _dataSource = SetengahJadiStockDataSource(stockData: [], numberFormat: _numberFormat);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SetengahJadiStockReportService.getSetengahJadiStockReport(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);
      final items = data.map((json) => SetengahJadiStockReport.fromJson(json)).toList();

      setState(() {
        _stockData = items;
        _stockSummary = SetengahJadiStockSummary.fromJson(response['summary'] ?? {});
        _applyFilters();
      });
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

  void _applyFilters() {
    List<SetengahJadiStockReport> filtered = List.from(_stockData);

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchLower = _searchController.text.toLowerCase();
        return item.NAMA.toLowerCase().contains(searchLower) ||
            item.ID.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);

    setState(() {
      _filteredData = filtered;
      _dataSource = SetengahJadiStockDataSource(
        stockData: filtered,
        numberFormat: _numberFormat,
      );
    });
  }

  List<SetengahJadiStockReport> _applySorting(List<SetengahJadiStockReport> data) {
    switch (_sortBy) {
      case 'name_asc':
        data.sort((a, b) => a.NAMA.compareTo(b.NAMA));
        break;
      case 'name_desc':
        data.sort((a, b) => b.NAMA.compareTo(a.NAMA));
        break;
      case 'akhir_desc':
        data.sort((a, b) => b.Akhir.compareTo(a.Akhir));
        break;
      case 'akhir_asc':
        data.sort((a, b) => a.Akhir.compareTo(b.Akhir));
        break;
      case 'stokin_desc':
        data.sort((a, b) => b.Stok_in.compareTo(a.Stok_in));
        break;
      case 'stokin_asc':
        data.sort((a, b) => a.Stok_in.compareTo(b.Stok_in));
        break;
      case 'stokout_desc':
        data.sort((a, b) => b.Stok_out.compareTo(a.Stok_out));
        break;
      case 'stokout_asc':
        data.sort((a, b) => a.Stok_out.compareTo(b.Stok_out));
        break;
    }
    return data;
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'name_asc': return 'A-Z';
      case 'name_desc': return 'Z-A';
      case 'akhir_desc': return 'Stok ↑';
      case 'akhir_asc': return 'Stok ↓';
      case 'stokin_desc': return 'Stok In ↑';
      case 'stokin_asc': return 'Stok In ↓';
      case 'stokout_desc': return 'Stok Out ↑';
      case 'stokout_asc': return 'Stok Out ↓';
      default: return 'Urut';
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      lastDate: DateTime(2100),
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

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  String _formatPeriod() {
    if (_startDate == null || _endDate == null) return '';
    final startStr = DateFormat('dd/MM').format(_startDate!);
    final endStr = DateFormat('dd/MM').format(_endDate!);
    return '$startStr - $endStr';
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  String _convertToPivotJson() {
    final List<Map<String, dynamic>> data = [];
    for (var item in _filteredData) {
      data.add({
        'ID': item.ID,
        'NAMA': item.NAMA,
        'Awal': item.Awal,
        'Stok_in': item.Stok_in,
        'Stok_out': item.Stok_out,
        'Akhir': item.Akhir,
        'Change': item.change,
      });
    }
    return jsonEncode(data);
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _showDetailDialog(SetengahJadiStockReport item) async {
    setState(() {
      _isLoadingDetail = true;
    });

    try {
      final detail = await SetengahJadiStockReportService.getStockSetengahJadiDetail(
        stjId: item.ID,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      setState(() {
        _currentDetail = detail;
        _currentDetailName = item.NAMA;
        _detailTab = 0;
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Detail Stok: $_currentDetailName',
                            style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Periode: ${_formatPeriod()}',
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() => _detailTab = 0),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _detailTab == 0 ? Colors.blue.shade600 : Colors.grey.shade200,
                              foregroundColor: _detailTab == 0 ? Colors.white : Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              'Masuk (${_currentDetail!.masuk.length})',
                              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setDialogState(() => _detailTab = 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _detailTab == 1 ? Colors.red.shade600 : Colors.grey.shade200,
                              foregroundColor: _detailTab == 1 ? Colors.white : Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              'Keluar (${_currentDetail!.keluar.length})',
                              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _detailTab == 0
                          ? _buildMovementList(_currentDetail!.masuk, Colors.blue)
                          : _buildMovementList(_currentDetail!.keluar, Colors.red),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      _showSnackbar('Error loading detail: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingDetail = false;
      });
    }
  }

  Widget _buildMovementList(List<StockMovement> movements, Color color) {
    if (movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      movement.noReferensi,
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateString(movement.tanggal),
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (movement.keterangan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    movement.keterangan,
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (movement.itemNama != null && movement.itemNama!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Item: ${movement.itemNama}',
                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      movement.jenis,
                      style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                  Text(
                    'Qty: ${movement.qty.toInt()}',
                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Stock St. Jadi',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // Filter Section
              Container(
                margin: EdgeInsets.all(isTablet ? 12 : 10),
                padding: EdgeInsets.all(isTablet ? 14 : 12),
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
                          flex: 5,
                          child: _buildDateField(
                            label: 'Dari Tanggal',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: _buildDateField(
                            label: 'Sampai Tanggal',
                            date: _endDate,
                            onTap: () => _selectEndDate(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: _buildSearchAndSort(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _buildLoadButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Bar
              _buildTabBar(),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingIndicator()
                    : _error != null
                    ? _buildErrorState()
                    : _filteredData.isEmpty
                    ? _buildEmptyState('Tidak ada data stok untuk ditampilkan')
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDataGridView(),
                    _buildPivotView(),
                  ],
                ),
              ),

              // Bottom Total Bar
              _buildBottomTotalBar(isTablet),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: const Color(0xFFF6A918)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date != null ? DateFormat('dd/MM/yy').format(date) : 'Pilih',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndSort() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (value) => _applyFilters(),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade500),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 36,
          child: PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortBy = value);
              _applyFilters();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name_asc', child: Text('A-Z Nama')),
              const PopupMenuItem(value: 'name_desc', child: Text('Z-A Nama')),
              const PopupMenuItem(value: 'akhir_desc', child: Text('Stok Tertinggi')),
              const PopupMenuItem(value: 'akhir_asc', child: Text('Stok Terendah')),
              const PopupMenuItem(value: 'stokin_desc', child: Text('Stok In Tertinggi')),
              const PopupMenuItem(value: 'stokin_asc', child: Text('Stok In Terendah')),
              const PopupMenuItem(value: 'stokout_desc', child: Text('Stok Out Tertinggi')),
              const PopupMenuItem(value: 'stokout_asc', child: Text('Stok Out Terendah')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.sort, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(_getSortLabel(), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 13),
        Container(
          height: 36,
          width: 80,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadData,
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, size: 14, color: Colors.white),
            label: Text(
              'Load',
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF6A918),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: const Size(70, 36),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
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
        indicatorColor: const Color(0xFFF6A918),
        labelColor: const Color(0xFFF6A918),
        unselectedLabelColor: Colors.grey,
        indicatorWeight: 2,
        labelStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 11),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)), strokeWidth: 2),
          const SizedBox(height: 12),
          Text('Memuat data...', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDataGridView() {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SfDataGrid(
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
          onCellDoubleTap: (details) {
            if (details.rowColumnIndex.rowIndex > 0) {
              final rowIndex = details.rowColumnIndex.rowIndex - 1;
              if (rowIndex < _filteredData.length) {
                _showDetailDialog(_filteredData[rowIndex]);
              }
            }
          },
          tableSummaryRows: [
            GridTableSummaryRow(
              showSummaryInRow: false,
              title: 'TOTAL',
              titleColumnSpan: 2,
              columns: [
                GridSummaryColumn(name: 'TotalAwal', columnName: 'Awal', summaryType: GridSummaryType.sum),
                GridSummaryColumn(name: 'TotalStokIn', columnName: 'Stok_in', summaryType: GridSummaryType.sum),
                GridSummaryColumn(name: 'TotalStokOut', columnName: 'Stok_out', summaryType: GridSummaryType.sum),
                GridSummaryColumn(name: 'TotalAkhir', columnName: 'Akhir', summaryType: GridSummaryType.sum),
                GridSummaryColumn(name: 'TotalChange', columnName: 'Change', summaryType: GridSummaryType.sum),
              ],
              position: GridTableSummaryRowPosition.bottom,
            ),
          ],
          columns: [
            GridColumn(
              columnName: 'no',
              width: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.center,
                child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'ID',
              width: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'NAMA',
              width: 230,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text('Nama Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'Awal',
              width: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerRight,
                child: const Text('Stok Awal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'Stok_in',
              width: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerRight,
                child: const Text('Stok In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'Stok_out',
              width: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerRight,
                child: const Text('Stok Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'Akhir',
              width: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerRight,
                child: const Text('Stok Akhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            GridColumn(
              columnName: 'Change',
              width: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerRight,
                child: const Text('Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPivotView() {
    if (_filteredData.isEmpty) {
      return _buildEmptyState('Tidak ada data untuk pivot table');
    }

    try {
      final jsonData = _convertToPivotJson();

      return Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Rows: - | Columns: - | Values: Stok Awal, Stok In, Stok Out, Stok Akhir, Perubahan',
                    style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey[600]),
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
                    cols: const [],
                    rows: const [],
                    aggregatorName: AggregatorName.sum,
                    vals: const ['Awal', 'Stok_in', 'Stok_out', 'Akhir', 'Change'],
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
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 32),
              const SizedBox(height: 8),
              Text('Error: ${e.toString()}', style: TextStyle(color: Colors.red[800], fontSize: 11), textAlign: TextAlign.center),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(Icons.inbox, size: 32, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Text(message, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 32, color: Colors.red[400]),
            ),
            const SizedBox(height: 12),
            Text('Terjadi Kesalahan', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red[800])),
            const SizedBox(height: 6),
            Text(_error!, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.red[600]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text('COBA LAGI', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6A918),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTotalBar(bool isTablet) {
    final totalChange = _stockSummary.totalChange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Items', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${_filteredData.length} items', style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text('Stok Akhir: ', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600)),
                      Text(
                        _stockSummary.totalAkhir.toString(),
                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: _getStockColor(_stockSummary.totalAkhir)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perubahan: ${totalChange >= 0 ? '+' : ''}$totalChange',
                    style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w600, color: totalChange >= 0 ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTotalItem('Awal', _stockSummary.totalAwal, Colors.grey.shade700),
                _buildTotalItem('Stok In', _stockSummary.totalStokIn, Colors.green),
                _buildTotalItem('Stok Out', _stockSummary.totalStokOut, Colors.red),
                _buildTotalItem('Akhir', _stockSummary.totalAkhir, _getStockColor(_stockSummary.totalAkhir)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600)),
          Text(value.toString(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class SetengahJadiStockDataSource extends DataGridSource {
  SetengahJadiStockDataSource({
    required List<SetengahJadiStockReport> stockData,
    required NumberFormat numberFormat,
  }) {
    _numberFormat = numberFormat;

    _totalAwal = stockData.fold<int>(0, (sum, item) => sum + item.Awal);
    _totalStokIn = stockData.fold<int>(0, (sum, item) => sum + item.Stok_in);
    _totalStokOut = stockData.fold<int>(0, (sum, item) => sum + item.Stok_out);
    _totalAkhir = stockData.fold<int>(0, (sum, item) => sum + item.Akhir);
    _totalChange = stockData.fold<int>(0, (sum, item) => sum + item.change);

    _data = stockData.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'ID', value: item.ID),
        DataGridCell<String>(columnName: 'NAMA', value: item.NAMA),
        DataGridCell<int>(columnName: 'Awal', value: item.Awal),
        DataGridCell<int>(columnName: 'Stok_in', value: item.Stok_in),
        DataGridCell<int>(columnName: 'Stok_out', value: item.Stok_out),
        DataGridCell<int>(columnName: 'Akhir', value: item.Akhir),
        DataGridCell<int>(columnName: 'Change', value: item.change),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _numberFormat;
  late int _totalAwal;
  late int _totalStokIn;
  late int _totalStokOut;
  late int _totalAkhir;
  late int _totalChange;

  @override
  List<DataGridRow> get rows => _data;

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget? buildTableSummaryCellWidget(
      GridTableSummaryRow summaryRow,
      GridSummaryColumn? summaryColumn,
      RowColumnIndex rowColumnIndex,
      String summaryValue) {
    if (summaryColumn == null) {
      if (summaryRow.title != null && summaryRow.title!.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(summaryRow.title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFFF6A918))),
        );
      }
      return Container();
    }

    int? value;
    Color textColor = const Color(0xFFF6A918);

    switch (summaryColumn.name) {
      case 'TotalAwal': value = _totalAwal; break;
      case 'TotalStokIn': value = _totalStokIn; break;
      case 'TotalStokOut': value = _totalStokOut; break;
      case 'TotalAkhir':
        value = _totalAkhir;
        textColor = _getStockColor(value);
        break;
      case 'TotalChange':
        value = _totalChange;
        textColor = value >= 0 ? Colors.green : Colors.red;
        break;
      default: return Container();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.centerRight,
      child: Text(
        _numberFormat.format(value),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textColor),
      ),
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNumber = cell.columnName != 'no' && cell.columnName != 'ID' && cell.columnName != 'NAMA';

        Color? textColor;
        if (cell.columnName == 'Akhir') {
          textColor = _getStockColor(cell.value as int);
        } else if (cell.columnName == 'Change') {
          final value = cell.value as int;
          textColor = value >= 0 ? Colors.green : Colors.red;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isNumber ? _numberFormat.format(cell.value) : cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: textColor ?? (isNumber ? const Color(0xFFF6A918) : Colors.black87),
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'no') return Alignment.center;
    if (columnName == 'ID' || columnName == 'NAMA') return Alignment.centerLeft;
    return Alignment.centerRight;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'no') return TextAlign.center;
    if (columnName == 'ID' || columnName == 'NAMA') return TextAlign.left;
    return TextAlign.right;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName != 'no' && columnName != 'ID' && columnName != 'NAMA') return FontWeight.w600;
    return FontWeight.normal;
  }
}