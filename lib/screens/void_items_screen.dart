import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:pivot_table/pivot_table.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/void_items_service.dart';
import '../models/void_item.dart';
import '../widgets/base_layout.dart';

class VoidItemsScreen extends StatefulWidget {
  const VoidItemsScreen({super.key});

  @override
  State<VoidItemsScreen> createState() => _VoidItemsScreenState();
}

class _VoidItemsScreenState extends State<VoidItemsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<VoidItem> _voidItems = [];
  bool _isLoading = false;
  String? _error;
  late VoidItemDataSource _dataSource;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _dataSource = VoidItemDataSource(voidItems: [], currencyFormat: _currencyFormat, numberFormat: _numberFormat);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await VoidItemsService.getVoidItems(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);
      final items = data.map((json) => VoidItem.fromJson(json)).toList();

      setState(() {
        _voidItems = items;
        _dataSource = VoidItemDataSource(
          voidItems: items,
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

  String _formatCurrency(dynamic amount) {
    final num value = amount is int ? amount : (amount ?? 0);
    return _currencyFormat.format(value);
  }

  String _convertToPivotJson() {
    final List<Map<String, dynamic>> data = [];
    for (var item in _voidItems) {
      data.add({
        'bulan': item.bulan,
        'tahun': item.tahun,
        'nomor': item.nomor,
        'tanggal': item.tanggal,
        'nama': item.nama,
        'varian': item.varian,
        'salesType': item.salesType,
        'qty': item.qty,
        'nilai': item.nilai,
        'served': item.served,
        'category': item.category,
      });
    }
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'List Void',
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
                child: Row(
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
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildLoadButton(),
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
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDataGridView(),
                    _buildPivotView(),
                  ],
                ),
              ),
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
    if (_voidItems.isEmpty) {
      return _buildEmptyState('Tidak ada data void untuk ditampilkan');
    }

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
                    'no', 'bulan', 'tahun', 'nomor', 'tanggal', 'nama',
                    'varian', 'salesType', 'qty', 'nilai', 'served', 'category'
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
              titleColumnSpan: 6,
              columns: [
                GridSummaryColumn(
                  name: 'TotalQty',
                  columnName: 'qty',
                  summaryType: GridSummaryType.sum,
                ),
                GridSummaryColumn(
                  name: 'TotalNilai',
                  columnName: 'nilai',
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
              columnName: 'bulan',
              minimumWidth: 60,
              maximumWidth: 70,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Bulan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'tahun',
              minimumWidth: 60,
              maximumWidth: 70,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Tahun',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'nomor',
              minimumWidth: 120,
              maximumWidth: 140,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'No. Invoice',
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
              columnName: 'nama',
              minimumWidth: 150,
              maximumWidth: 200,
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
              columnName: 'varian',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Varian',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'salesType',
              minimumWidth: 80,
              maximumWidth: 100,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'qty',
              minimumWidth: 60,
              maximumWidth: 80,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Qty',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'nilai',
              minimumWidth: 100,
              maximumWidth: 130,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Nilai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'served',
              minimumWidth: 90,
              maximumWidth: 110,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Served',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            GridColumn(
              columnName: 'category',
              minimumWidth: 100,
              maximumWidth: 120,
              label: Container(
                padding: const EdgeInsets.only(left: 4, top: 4),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Kategori',
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
    if (_voidItems.isEmpty) {
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
                    'Anda dapat mengatur kolom pivot dengan drag & drop',
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
                    cols: const ['category'], // Default: Kategori sebagai kolom
                    rows: const ['nama'], // Default: Nama Item sebagai baris
                    aggregatorName: AggregatorName.sum,
                    vals: const ['qty', 'nilai'], // Default: Qty dan Nilai sebagai value
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
}

class VoidItemDataSource extends DataGridSource {
  VoidItemDataSource({
    required List<VoidItem> voidItems,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;

    _totalQty = voidItems.fold<int>(0, (sum, item) => sum + item.qty);
    _totalNilai = voidItems.fold<double>(0, (sum, item) => sum + item.nilai);

    _data = voidItems.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'bulan', value: item.bulan),
        DataGridCell<String>(columnName: 'tahun', value: item.tahun),
        DataGridCell<String>(columnName: 'nomor', value: item.nomor),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(item.tanggal)),
        DataGridCell<String>(columnName: 'nama', value: item.nama),
        DataGridCell<String>(columnName: 'varian', value: item.varian.isNotEmpty ? item.varian : '-'),
        DataGridCell<String>(columnName: 'salesType', value: item.salesType),
        DataGridCell<int>(columnName: 'qty', value: item.qty),
        DataGridCell<double>(columnName: 'nilai', value: item.nilai),
        DataGridCell<String>(columnName: 'served', value: item.served),
        DataGridCell<String>(columnName: 'category', value: item.category.isNotEmpty ? item.category : '-'),
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
  late NumberFormat _currencyFormat;
  late NumberFormat _numberFormat;
  late int _totalQty;
  late double _totalNilai;

  @override
  List<DataGridRow> get rows => _data;

  @override
  Widget? buildTableSummaryCellWidget(
      GridTableSummaryRow summaryRow,
      GridSummaryColumn? summaryColumn,
      RowColumnIndex rowColumnIndex,
      String summaryValue) {

    if (summaryColumn?.name == 'TotalQty') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerRight,
        child: Text(
          _numberFormat.format(_totalQty),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Colors.red,
          ),
        ),
      );
    } else if (summaryColumn?.name == 'TotalNilai') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerRight,
        child: Text(
          _currencyFormat.format(_totalNilai),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Colors.red,
          ),
        ),
      );
    } else if (summaryColumn == null && summaryRow.title != null && summaryRow.title!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          summaryRow.title!,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Colors.red,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(summaryValue),
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isAmount = cell.columnName == 'nilai';
        final isQty = cell.columnName == 'qty';

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isAmount
                ? _currencyFormat.format(cell.value)
                : (isQty ? _numberFormat.format(cell.value) : cell.value.toString()),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: isAmount ? Colors.red : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'qty' || columnName == 'nilai') {
      return Alignment.centerRight;
    }
    return Alignment.centerLeft;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'qty' || columnName == 'nilai') {
      return TextAlign.right;
    }
    return TextAlign.left;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'qty' || columnName == 'nilai') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}