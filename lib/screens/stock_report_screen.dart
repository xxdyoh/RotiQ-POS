import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:pivot_table/pivot_table.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/stock_report_service.dart';
import '../models/stock_report.dart';
import '../widgets/base_layout.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<StockReport> _stockData = [];
  List<String> _allCategories = [];
  List<String> _selectedCategories = [];
  bool _isLoading = false;
  String? _error;
  late StockDataSource _dataSource;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  StockSummary _stockSummary = StockSummary(
    totalAwal: 0,
    totalStokIn: 0,
    totalRetur: 0,
    totalSales: 0,
    totalAkhir: 0,
    totalItems: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _dataSource = StockDataSource(stockData: [], currencyFormat: _currencyFormat, numberFormat: _numberFormat);
    _loadCategories();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await StockReportService.getCategories();
      setState(() {
        _allCategories = categories;
        _selectedCategories = List.from(categories);
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await StockReportService.getStockReport(
        startDate: _startDate!,
        endDate: _endDate!,
        selectedCategories: _selectedCategories,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);
      final items = data.map((json) => StockReport.fromJson(json)).toList();

      setState(() {
        _stockData = items;
        _stockSummary = StockSummary.fromJson(response['summary'] ?? {});
        _dataSource = StockDataSource(
          stockData: items,
          currencyFormat: _currencyFormat,
          numberFormat: _numberFormat,
        );
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

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFF6A918),
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
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFF6A918),
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
    for (var item in _stockData) {
      data.add({
        'ID': item.ID,
        'NAMA': item.NAMA,
        'CATEGORY': item.CATEGORY,
        'Awal': item.Awal,
        'Stok_in': item.Stok_in,
        'Retur': item.Retur,
        'Sales': item.Sales,
        'Akhir': item.Akhir,
        'Change': item.change,
      });
    }
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Lap Stock',
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
                          child: _buildCategoryFilter(),
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
                    : _stockData.isEmpty
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
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
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
                    date != null
                        ? DateFormat('dd/MM/yy').format(date)
                        : 'Pilih',
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

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCategories.length == 1 ? _selectedCategories.first : null,
              hint: Text(
                _selectedCategories.length > 1
                    ? '${_selectedCategories.length} kategori dipilih'
                    : 'Pilih kategori',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Semua Kategori', style: TextStyle(fontSize: 12)),
                ),
                ..._allCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category, style: const TextStyle(fontSize: 12)),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == 'all') {
                  setState(() {
                    _selectedCategories = List.from(_allCategories);
                  });
                } else if (value != null) {
                  setState(() {
                    _selectedCategories = [value];
                  });
                }
              },
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
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(Icons.refresh, size: 14, color: Colors.white),
            label: Text(
              'Load',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF6A918),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
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
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
            strokeWidth: 2,
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat data...',
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
          ),
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
          source: _dataSource,
          allowColumnsResizing: true,
          columnResizeMode: ColumnResizeMode.onResize,
          columnWidthMode: ColumnWidthMode.auto,
          headerRowHeight: 32,
          allowSorting: true,
          allowFiltering: true,
          stackedHeaderRows: [
            StackedHeaderRow(
              cells: [
                StackedHeaderCell(
                  columnNames: [
                    'no', 'ID', 'NAMA', 'CATEGORY', 'Awal', 'Stok_in', 'Retur', 'Sales', 'Akhir', 'Change'
                  ],
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
          tableSummaryRows: [
            GridTableSummaryRow(
              showSummaryInRow: false,
              title: 'TOTAL',
              titleColumnSpan: 3,
              columns: [
                GridSummaryColumn(
                  name: 'TotalAwal',
                  columnName: 'Awal',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalStokIn',
                  columnName: 'Stok_in',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalRetur',
                  columnName: 'Retur',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalSales',
                  columnName: 'Sales',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalAkhir',
                  columnName: 'Akhir',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalChange',
                  columnName: 'Change',
                  summaryType: GridSummaryType.sum,
                ),
              ],
              position: GridTableSummaryRowPosition.bottom,
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
              columnName: 'ID',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'NAMA',
              minimumWidth: 200,
              maximumWidth: 250,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Nama Item',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'CATEGORY',
              minimumWidth: 120,
              maximumWidth: 150,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Awal',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Stok Awal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Stok_in',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Stok In',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Retur',
              minimumWidth: 70,
              maximumWidth: 90,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Retur',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Sales',
              minimumWidth: 70,
              maximumWidth: 90,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Sales',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Akhir',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Stok Akhir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'Change',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Perubahan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          ],
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          rowHeight: 30,
          selectionMode: SelectionMode.single,
        ),
      ),
    );
  }

  Widget _buildPivotView() {
    if (_stockData.isEmpty) {
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Rows: Kategori | Columns: - | Values: Stok Awal, Stok In, Retur, Sales, Stok Akhir',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.grey[600],
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
                    cols: const [], // Tidak ada kolom, hanya baris
                    rows: const ['CATEGORY'], // Kategori sebagai baris
                    aggregatorName: AggregatorName.sum,
                    vals: const ['Awal', 'Stok_in', 'Retur', 'Sales', 'Akhir', 'Change'],
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
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 32),
              const SizedBox(height: 8),
              Text(
                'Error: ${e.toString()}',
                style: TextStyle(color: Colors.red[800], fontSize: 11),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox, size: 32, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 32, color: Colors.red[400]),
            ),
            const SizedBox(height: 12),
            Text(
              'Terjadi Kesalahan',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(
                'COBA LAGI',
                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6A918),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
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
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
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
                  Text(
                    'Total Items',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_stockData.length} items',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        'Stok Akhir: ',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _stockSummary.totalAkhir.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _getStockColor(_stockSummary.totalAkhir),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Perubahan: ${totalChange >= 0 ? '+' : ''}$totalChange',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: totalChange >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StockDataSource extends DataGridSource {
  StockDataSource({
    required List<StockReport> stockData,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;

    _totalAwal = stockData.fold<int>(0, (sum, item) => sum + item.Awal);
    _totalStokIn = stockData.fold<int>(0, (sum, item) => sum + item.Stok_in);
    _totalRetur = stockData.fold<int>(0, (sum, item) => sum + item.Retur);
    _totalSales = stockData.fold<int>(0, (sum, item) => sum + item.Sales);
    _totalAkhir = stockData.fold<int>(0, (sum, item) => sum + item.Akhir);
    _totalChange = stockData.fold<int>(0, (sum, item) => sum + item.change);

    _data = stockData.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'ID', value: item.ID),
        DataGridCell<String>(columnName: 'NAMA', value: item.NAMA),
        DataGridCell<String>(columnName: 'CATEGORY', value: item.CATEGORY),
        DataGridCell<int>(columnName: 'Awal', value: item.Awal),
        DataGridCell<int>(columnName: 'Stok_in', value: item.Stok_in),
        DataGridCell<int>(columnName: 'Retur', value: item.Retur),
        DataGridCell<int>(columnName: 'Sales', value: item.Sales),
        DataGridCell<int>(columnName: 'Akhir', value: item.Akhir),
        DataGridCell<int>(columnName: 'Change', value: item.change),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _currencyFormat;
  late NumberFormat _numberFormat;
  late int _totalAwal;
  late int _totalStokIn;
  late int _totalRetur;
  late int _totalSales;
  late int _totalAkhir;
  late int _totalChange;

  @override
  List<DataGridRow> get rows => _data;

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
          child: Text(
            summaryRow.title!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Color(0xFFF6A918),
            ),
          ),
        );
      }
      return Container();
    }

    int? value;
    Color textColor = const Color(0xFFF6A918);

    switch (summaryColumn.name) {
      case 'TotalAwal': value = _totalAwal; break;
      case 'TotalStokIn': value = _totalStokIn; break;
      case 'TotalRetur': value = _totalRetur; break;
      case 'TotalSales': value = _totalSales; break;
      case 'TotalAkhir': value = _totalAkhir;
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: textColor,
        ),
      ),
    );
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNumber = cell.columnName != 'no' &&
            cell.columnName != 'ID' &&
            cell.columnName != 'NAMA' &&
            cell.columnName != 'CATEGORY';

        Color? textColor;
        if (cell.columnName == 'Akhir') {
          final value = cell.value as int;
          textColor = _getStockColor(value);
        } else if (cell.columnName == 'Change') {
          final value = cell.value as int;
          textColor = value >= 0 ? Colors.green : Colors.red;
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isNumber
                ? _numberFormat.format(cell.value)
                : cell.value.toString(),
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
    if (columnName == 'no' || columnName == 'ID' || columnName == 'NAMA' || columnName == 'CATEGORY') {
      return Alignment.centerLeft;
    }
    return Alignment.centerRight;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'no' || columnName == 'ID' || columnName == 'NAMA' || columnName == 'CATEGORY') {
      return TextAlign.left;
    }
    return TextAlign.right;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName != 'no' && columnName != 'ID' && columnName != 'NAMA' && columnName != 'CATEGORY') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}