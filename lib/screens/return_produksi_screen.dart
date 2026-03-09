import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/return_produksi_service.dart';
import '../models/return_produksi.dart';
import '../widgets/base_layout.dart';

class ReturnProduksiScreen extends StatefulWidget {
  const ReturnProduksiScreen({super.key});

  @override
  State<ReturnProduksiScreen> createState() => _ReturnProduksiScreenState();
}

class _ReturnProduksiScreenState extends State<ReturnProduksiScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<ReturnProduksi> _returns = [];

  final DataGridController _dataGridController = DataGridController();
  late ReturnDataSource _dataSource;

  // Return summary
  ReturnSummary _returnSummary = ReturnSummary(
    totalReturns: 0,
    totalNilaiJual: 0,
    totalItems: 0,
  );

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ReturnProduksiService.getReturnProduksi(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _returns = data.map((json) => ReturnProduksi.fromJson(json)).toList();
        _returnSummary = ReturnSummary.fromJson(response['summary'] ?? {});
        _dataSource = ReturnDataSource(
          returns: _returns,
          currencyFormat: _currencyFormat,
          numberFormat: _numberFormat,
          onTap: _showReturnDetailBottomSheet,
        );
      });
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showReturnDetailBottomSheet(ReturnProduksi ret) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_return, color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ret.nomor,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            _formatDate(ret.tanggal),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Keterangan
                    if (ret.keterangan.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.note, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ret.keterangan,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Items
                    Text(
                      'Detail Items (${ret.details.length})',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            headingRowHeight: 36,
                            dataRowHeight: 32,
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                            columns: const [
                              DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Nama Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Harga Jual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Nilai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                            rows: ret.details.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final item = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text(index.toString(), style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.nama, style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.qty.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                                  DataCell(Text(_currencyFormat.format(item.hargaJual), style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(_currencyFormat.format(item.nilaiJual),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      lastDate: DateTime.now(),
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

  String _formatDate(String dateString) {
    if (dateString.isEmpty || dateString == 'null') return '';
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
      title: 'Return Produksi',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // Filter Section - Satu baris dengan tanggal dan tombol load
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
                    // Dari Tanggal
                    Expanded(
                      flex: 2,
                      child: _buildDateField(
                        label: 'Dari Tanggal',
                        date: _startDate,
                        onTap: () => _selectStartDate(context),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sampai Tanggal
                    Expanded(
                      flex: 2,
                      child: _buildDateField(
                        label: 'Sampai Tanggal',
                        date: _endDate,
                        onTap: () => _selectEndDate(context),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tombol Load
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 13),
                          Container(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _loadReportData,
                              icon: _isLoading
                                  ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white
                                ),
                              )
                                  : Icon(Icons.refresh, size: 14, color: Colors.white),
                              label: Text(
                                'Load',
                                style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF6A918),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(70, 36),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Data Grid
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(color: const Color(0xFFF6A918)),
                )
                    : _returns.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_return, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada data return',
                        style: GoogleFonts.montserrat(
                            color: Colors.grey.shade500,
                            fontSize: 13
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  margin: EdgeInsets.all(isTablet ? 12 : 10),
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

                      onCellTap: (details) {
                        if (details.rowColumnIndex.rowIndex > 0) {
                          final rowIndex = details.rowColumnIndex.rowIndex - 2;
                          if (rowIndex >= 0 && rowIndex < _returns.length) {
                            final ret = _returns[rowIndex];
                            _showReturnDetailBottomSheet(ret);
                          }
                        }
                      },

                      stackedHeaderRows: [
                        StackedHeaderRow(
                          cells: [
                            StackedHeaderCell(
                              columnNames: [
                                'no', 'nomor', 'tanggal', 'keterangan', 'nilai_jual', 'total_items'
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
                          titleColumnSpan: 4,
                          columns: [
                            GridSummaryColumn(
                              name: 'TotalNilai',
                              columnName: 'nilai_jual',
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
                          columnName: 'nomor',
                          minimumWidth: 120,
                          maximumWidth: 140,
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
                          minimumWidth: 200,
                          maximumWidth: 300,
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
                          columnName: 'nilai_jual',
                          minimumWidth: 120,
                          maximumWidth: 150,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nilai Jual',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'total_items',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Items',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildBottomTotalBar(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Return',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_returnSummary.totalReturns} return • ${_returnSummary.totalItems} items',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Text(
            _currencyFormat.format(_returnSummary.totalNilaiJual),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class ReturnDataSource extends DataGridSource {
  ReturnDataSource({
    required List<ReturnProduksi> returns,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
    required Function(ReturnProduksi) onTap,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;
    _onTap = onTap;
    _returns = returns;

    _totalNilai = returns.fold<double>(0, (sum, ret) => sum + ret.nilaiJual);

    _data = returns.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final ret = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nomor', value: ret.nomor),
        DataGridCell<String>(columnName: 'tanggal', value: _formatDate(ret.tanggal)),
        DataGridCell<String>(columnName: 'keterangan', value: ret.keterangan.isNotEmpty ? ret.keterangan : '-'),
        DataGridCell<double>(columnName: 'nilai_jual', value: ret.nilaiJual),
        DataGridCell<int>(columnName: 'total_items', value: ret.details.length),
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
  late Function(ReturnProduksi) _onTap;
  late List<ReturnProduksi> _returns;
  late double _totalNilai;

  @override
  List<DataGridRow> get rows => _data;

  @override
  Widget? buildTableSummaryCellWidget(
      GridTableSummaryRow summaryRow,
      GridSummaryColumn? summaryColumn,
      RowColumnIndex rowColumnIndex,
      String summaryValue) {

    if (summaryColumn?.name == 'TotalNilai') {
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
        final isAmount = cell.columnName == 'nilai_jual';

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            isAmount
                ? _currencyFormat.format(cell.value)
                : cell.value.toString(),
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
    if (columnName == 'nilai_jual' || columnName == 'total_items') {
      return Alignment.centerRight;
    }
    return Alignment.centerLeft;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'nilai_jual' || columnName == 'total_items') {
      return TextAlign.right;
    }
    return TextAlign.left;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'nilai_jual' || columnName == 'total_items') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}