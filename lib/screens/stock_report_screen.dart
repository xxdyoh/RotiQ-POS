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
    totalSTBJ: 0,
    totalMutasiIn: 0,
    totalMutasiOut: 0,
    totalKoreksi: 0,
    totalRetur: 0,
    totalSales: 0,
    totalAkhir: 0,
    totalItems: 0,
  );

  // Color Palette
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _accentMint = Color(0xFF06D6A0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _dataSource = StockDataSource(stockData: [], numberFormat: _numberFormat);
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
      debugPrint('Error loading categories: $e');
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
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _accentGold, onPrimary: Colors.white),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _accentGold, onPrimary: Colors.white),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
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
        'STBJ': item.STBJ,
        'Mutasi_in': item.Mutasi_in,
        'Mutasi_out': item.Mutasi_out,
        'Koreksi': item.Koreksi,
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Lap Stock',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Filter Section
            Container(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 12),
              child: Row(
                children: [
                  // Tanggal Mulai
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
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
                                _startDate != null ? _displayDateFormat.format(_startDate!) : 'Dari',
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
                      onTap: () => _selectEndDate(context),
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
                                _endDate != null ? _displayDateFormat.format(_endDate!) : 'Sampai',
                                style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Kategori Dropdown
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCategories.length == 1 ? _selectedCategories.first : null,
                          hint: Text(
                            _selectedCategories.length > 1 ? '${_selectedCategories.length} kategori' : 'Semua',
                            style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary),
                          ),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: _textSecondary),
                          style: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary),
                          items: [
                            DropdownMenuItem(value: 'all', child: Text('Semua Kategori', style: GoogleFonts.montserrat(fontSize: 11))),
                            ..._allCategories.map((category) => DropdownMenuItem(value: category, child: Text(category, style: GoogleFonts.montserrat(fontSize: 11)))),
                          ],
                          onChanged: (value) {
                            if (value == 'all') {
                              setState(() => _selectedCategories = List.from(_allCategories));
                            } else if (value != null) {
                              setState(() => _selectedCategories = [value]);
                            }
                          },
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
                    onPressed: _isLoading ? null : _loadData,
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: _surfaceWhite,
              child: TabBar(
                controller: _tabController,
                indicatorColor: _accentGold,
                indicatorWeight: 2,
                labelColor: _accentGold,
                unselectedLabelColor: _textSecondary,
                labelStyle: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 10),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.grid_on, size: 14), SizedBox(width: 4), Text('DATA GRID')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.pivot_table_chart, size: 14), SizedBox(width: 4), Text('PIVOT')])),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                  ? _buildErrorState()
                  : _stockData.isEmpty
                  ? _buildEmptyState()
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildDataGridView(isTablet),
                  _buildPivotView(),
                ],
              ),
            ),

            // Bottom Total Bar
            _buildBottomTotalBar(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
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

  Widget _buildDataGridView(bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(
        left: isTablet ? 16 : 12,
        right: isTablet ? 16 : 12,
        bottom: isTablet ? 0 : 0,
        top: 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border.all(color: _borderColor),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: SfDataGrid(
            source: _dataSource,
            allowColumnsResizing: true,
            columnResizeMode: ColumnResizeMode.onResizeEnd,
            columnWidthMode: ColumnWidthMode.fill,
            headerRowHeight: 32,
            rowHeight: 28,
            allowSorting: true,
            allowFiltering: true,
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            selectionMode: SelectionMode.none,
            tableSummaryRows: [
              GridTableSummaryRow(
                showSummaryInRow: false,
                title: 'TOTAL',
                titleColumnSpan: 3,
                columns: [
                  GridSummaryColumn(name: 'TotalAwal', columnName: 'Awal', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalSTBJ', columnName: 'STBJ', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalMutasiIn', columnName: 'Mutasi_in', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalMutasiOut', columnName: 'Mutasi_out', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalKoreksi', columnName: 'Koreksi', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalRetur', columnName: 'Retur', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalSales', columnName: 'Sales', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalAkhir', columnName: 'Akhir', summaryType: GridSummaryType.sum),
                  GridSummaryColumn(name: 'TotalChange', columnName: 'Change', summaryType: GridSummaryType.sum),
                ],
                position: GridTableSummaryRowPosition.bottom,
              ),
            ],
            columns: [
              _buildGridColumn('no', 'No', width: 100, alignment: Alignment.center),
              _buildGridColumn('ID', 'ID', width: 100, alignment: Alignment.centerLeft),
              _buildGridColumn('NAMA', 'Nama Item', width: 200, alignment: Alignment.centerLeft),
              _buildGridColumn('CATEGORY', 'Kategori', width: 140, alignment: Alignment.centerLeft),
              _buildGridColumn('Awal', 'Awal', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('STBJ', 'STBJ', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('Mutasi_in', 'Mutasi In', width: 170, alignment: Alignment.centerRight),
              _buildGridColumn('Mutasi_out', 'Mutasi Out', width: 170, alignment: Alignment.centerRight),
              _buildGridColumn('Koreksi', 'Koreksi', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('Retur', 'Retur', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('Sales', 'Sales', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('Akhir', 'Akhir', width: 120, alignment: Alignment.centerRight),
              _buildGridColumn('Change', 'Change', width: 120, alignment: Alignment.centerRight),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: alignment,
        child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 10, color: _textSecondary)),
      ),
    );
  }

  Widget _buildPivotView() {
    if (_stockData.isEmpty) {
      return _buildEmptyState();
    }

    try {
      final jsonData = _convertToPivotJson();

      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _bgLight,
                border: Border(bottom: BorderSide(color: _borderColor)),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Rows: Kategori | Values: Awal, STBJ, Mutasi In, Mutasi Out, Koreksi, Retur, Sales, Akhir, Change',
                      style: GoogleFonts.montserrat(fontSize: 9, color: _textSecondary),
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
                    cols: const [],
                    rows: const ['CATEGORY'],
                    aggregatorName: AggregatorName.sum,
                    vals: const ['Awal', 'STBJ', 'Mutasi_in', 'Mutasi_out', 'Koreksi', 'Retur', 'Sales', 'Akhir', 'Change'],
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
          child: Text('Error: ${e.toString()}', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.red)),
        ),
      );
    }
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
            child: Icon(Icons.inbox_outlined, size: 28, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Tidak ada data stok', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Pilih filter dan klik Load', style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.error_outline, size: 28, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text('Terjadi Kesalahan', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 4),
          Text(_error!, style: GoogleFonts.montserrat(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.refresh_rounded,
            label: 'Coba Lagi',
            color: _accentMint,
            onPressed: _loadData,
            isMobile: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTotalBar(bool isTablet) {
    final totalChange = _stockSummary.totalChange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_stockData.length} items', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textPrimary)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text('Stok Akhir: ', style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)),
                  Text(
                    _numberFormat.format(_stockSummary.totalAkhir),
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _getStockColor(_stockSummary.totalAkhir)),
                  ),
                ],
              ),
              Text(
                'Perubahan: ${totalChange >= 0 ? '+' : ''}${_numberFormat.format(totalChange)}',
                style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w500, color: totalChange >= 0 ? Colors.green : Colors.red),
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
    required NumberFormat numberFormat,
  }) {
    _numberFormat = numberFormat;

    _totalAwal = stockData.fold<int>(0, (sum, item) => sum + item.Awal);
    _totalSTBJ = stockData.fold<int>(0, (sum, item) => sum + item.STBJ);
    _totalMutasiIn = stockData.fold<int>(0, (sum, item) => sum + item.Mutasi_in);
    _totalMutasiOut = stockData.fold<int>(0, (sum, item) => sum + item.Mutasi_out);
    _totalKoreksi = stockData.fold<int>(0, (sum, item) => sum + item.Koreksi);
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
        DataGridCell<int>(columnName: 'STBJ', value: item.STBJ),
        DataGridCell<int>(columnName: 'Mutasi_in', value: item.Mutasi_in),
        DataGridCell<int>(columnName: 'Mutasi_out', value: item.Mutasi_out),
        DataGridCell<int>(columnName: 'Koreksi', value: item.Koreksi),
        DataGridCell<int>(columnName: 'Retur', value: item.Retur),
        DataGridCell<int>(columnName: 'Sales', value: item.Sales),
        DataGridCell<int>(columnName: 'Akhir', value: item.Akhir),
        DataGridCell<int>(columnName: 'Change', value: item.change),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _numberFormat;
  late int _totalAwal, _totalSTBJ, _totalMutasiIn, _totalMutasiOut, _totalKoreksi, _totalRetur, _totalSales, _totalAkhir, _totalChange;

  @override
  List<DataGridRow> get rows => _data;

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget? buildTableSummaryCellWidget(GridTableSummaryRow summaryRow, GridSummaryColumn? summaryColumn, RowColumnIndex rowColumnIndex, String summaryValue) {
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
      case 'TotalSTBJ': value = _totalSTBJ; break;
      case 'TotalMutasiIn': value = _totalMutasiIn; break;
      case 'TotalMutasiOut': value = _totalMutasiOut; break;
      case 'TotalKoreksi': value = _totalKoreksi; break;
      case 'TotalRetur': value = _totalRetur; break;
      case 'TotalSales': value = _totalSales; break;
      case 'TotalAkhir': value = _totalAkhir; textColor = _getStockColor(value); break;
      case 'TotalChange': value = _totalChange; textColor = value >= 0 ? Colors.green : Colors.red; break;
      default: return Container();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.centerRight,
      child: Text(_numberFormat.format(value), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textColor)),
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNumber = cell.columnName != 'no' && cell.columnName != 'ID' && cell.columnName != 'NAMA' && cell.columnName != 'CATEGORY';

        Color? textColor;
        if (cell.columnName == 'Akhir') {
          textColor = _getStockColor(cell.value as int);
        } else if (cell.columnName == 'Change') {
          final value = cell.value as int;
          textColor = value >= 0 ? Colors.green : Colors.red;
        } else if (cell.columnName == 'Koreksi') {
          textColor = const Color(0xFF3B82F6);
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isNumber ? _numberFormat.format(cell.value) : cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(fontSize: 10, fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal, color: textColor ?? (isNumber ? const Color(0xFFF6A918) : Colors.black87)),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'no') return Alignment.center;
    if (columnName == 'ID' || columnName == 'NAMA' || columnName == 'CATEGORY') return Alignment.centerLeft;
    return Alignment.centerRight;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'no') return TextAlign.center;
    if (columnName == 'ID' || columnName == 'NAMA' || columnName == 'CATEGORY') return TextAlign.left;
    return TextAlign.right;
  }
}