import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/sales_invoice_service.dart';
import '../models/sales_invoice.dart';
import '../widgets/base_layout.dart';

class SalesByInvoiceScreen extends StatefulWidget {
  const SalesByInvoiceScreen({super.key});

  @override
  State<SalesByInvoiceScreen> createState() => _SalesByInvoiceScreenState();
}

class _SalesByInvoiceScreenState extends State<SalesByInvoiceScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<SalesInvoice> _invoices = [];
  late InvoiceDataSource _dataSource;

  // Promo filter
  List<String> _allPromos = [];
  List<String> _selectedPromos = [];
  bool _showPromoFilter = false;

  // Payment summary
  PaymentSummary _paymentSummary = PaymentSummary(
    totalCash: 0,
    totalCard: 0,
    totalEdc: 0,
    totalDp: 0,
    totalOther: 0,
    totalAmount: 0,
    totalInvoices: 0,
  );

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    // _loadPromos();
    _loadReportData();
  }

  Future<void> _loadPromos() async {
    try {
      final promos = await SalesInvoiceService.getPromos();
      setState(() {
        _allPromos = promos;
        _selectedPromos = List.from(promos);
      });
    } catch (e) {
      print('Error loading promos: $e');
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SalesInvoiceService.getSalesByInvoice(
        startDate: _startDate!,
        endDate: _endDate!,
        selectedPromos: _selectedPromos,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _invoices = data.map((json) => SalesInvoice.fromJson(json)).toList();
        _paymentSummary = PaymentSummary.fromJson(response['summary'] ?? {});
        _dataSource = InvoiceDataSource(
          invoices: _invoices, // Mengirim invoices yang sudah difilter
          currencyFormat: _currencyFormat,
          numberFormat: _numberFormat,
          onTap: _showInvoiceDetailBottomSheet,
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

  void _showInvoiceDetailBottomSheet(SalesInvoice invoice) {
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
                          color: const Color(0xFFF6A918).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFFF6A918), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.nomor,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy HH:mm').format(
                                DateTime.parse(invoice.tanggal)
                            ),
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem('Meja', invoice.meja.isNotEmpty ? invoice.meja : '-'),
                              ),
                              Expanded(
                                child: _buildInfoItem('Customer', invoice.customer.isNotEmpty ? invoice.customer : 'Umum'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem('Kasir', invoice.kasir),
                              ),
                              Expanded(
                                child: _buildInfoItem('Status', invoice.statusOrder),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (invoice.promo.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer, size: 12, color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Promo: ${invoice.promo}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Detail Items',
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
                              DataColumn(label: Text('Varian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Disc %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Net Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Served', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                            rows: invoice.details.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final item = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text(index.toString(), style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.nama, style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.varian.isNotEmpty ? item.varian : '-', style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.salesType, style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.qty.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                                  DataCell(Text(_currencyFormat.format(item.price), style: const TextStyle(fontSize: 10))),
                                  DataCell(Text(item.disc > 0 ? '${item.disc.toStringAsFixed(0)}%' : '-',
                                      style: TextStyle(fontSize: 10, color: item.disc > 0 ? Colors.red : Colors.black87))),
                                  DataCell(Text(_currencyFormat.format(item.netPrice),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF6A918)))),
                                  DataCell(Text(item.served.isNotEmpty ? item.served : '-', style: const TextStyle(fontSize: 10))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Sub Total', invoice.amount - invoice.serviceCharge - invoice.tax),
                          _buildSummaryRow('Service Charge', invoice.serviceCharge),
                          _buildSummaryRow('Tax', invoice.tax),
                          _buildSummaryRow('Discount', invoice.discount, isNegative: true),
                          const Divider(height: 16),
                          _buildSummaryRow('Total', invoice.amount, isTotal: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pembayaran',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (invoice.cash > 0) _buildPaymentDetailRow('Cash', invoice.cash),
                          if (invoice.card > 0) _buildPaymentDetailRow('Card', invoice.card),
                          if (invoice.edc > 0) _buildPaymentDetailRow('EDC', invoice.edc),
                          if (invoice.dp > 0) _buildPaymentDetailRow('DP', invoice.dp),
                          if (invoice.otherValue > 0)
                            _buildPaymentDetailRow(invoice.other.isNotEmpty ? invoice.other : 'Other', invoice.otherValue),
                        ],
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

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 12 : 11,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${_currencyFormat.format(value)}',
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 13 : 11,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal
                  ? const Color(0xFFF6A918)
                  : (isNegative ? Colors.red.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(fontSize: 11),
          ),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF6A918),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 13 : 11,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
              color: isTotal ? const Color(0xFF2C3E50) : Colors.grey.shade700,
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 13 : 11,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? const Color(0xFFF6A918) : Colors.black87,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Sales by Invoice',
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
                          const SizedBox(height: 13), // Untuk menyamakan tinggi dengan label tanggal
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

              // Hapus bagian Promo Filter Panel (_showPromoFilter dan _buildPromoFilterPanel)

              // Data Grid
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(color: const Color(0xFFF6A918)),
                )
                    : _invoices.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada data invoice',
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
                        // Periksa apakah yang di-tap adalah baris data (bukan header)
                        if (details.rowColumnIndex.rowIndex > 0) {
                          // Di SfDataGrid, rowIndex 1 = header, rowIndex 2 = data pertama
                          // Jadi untuk mendapatkan index ke-0 di list, kita kurangi dengan 2
                          final dataRowIndex = details.rowColumnIndex.rowIndex - 2;

                          // Pastikan index valid
                          if (dataRowIndex >= 0 && dataRowIndex < _invoices.length) {
                            final invoice = _invoices[dataRowIndex];
                            _showInvoiceDetailBottomSheet(invoice);
                          }
                        }
                      },

                      stackedHeaderRows: [
                        StackedHeaderRow(
                          cells: [
                            StackedHeaderCell(
                              columnNames: [
                                'no', 'Nomor', 'Tanggal', 'Meja', 'Customer', 'Duration',
                                'Amount', 'SeviceCharge', 'Tax', 'Discount', 'Cash', 'Card',
                                'DP', 'EDC', 'Other_Value', 'Other', 'StatusOrder', 'Promo', 'Kasir'
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
                              name: 'TotalInvoice',
                              columnName: 'Amount',
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
                          columnName: 'Nomor',
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
                          columnName: 'Tanggal',
                          minimumWidth: 130,
                          maximumWidth: 150,
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
                          columnName: 'Meja',
                          minimumWidth: 60,
                          maximumWidth: 80,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Meja',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Customer',
                          minimumWidth: 120,
                          maximumWidth: 150,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Customer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Duration',
                          minimumWidth: 70,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Duration',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Amount',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Amount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'SeviceCharge',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Service Charge',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Tax',
                          minimumWidth: 70,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Tax',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Discount',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Discount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Cash',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Cash',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Card',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Card',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'DP',
                          minimumWidth: 70,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'DP',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'EDC',
                          minimumWidth: 70,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'EDC',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Other_Value',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Other Value',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Other',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Other',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'StatusOrder',
                          minimumWidth: 80,
                          maximumWidth: 100,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Promo',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Promo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'Kasir',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Kasir',
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
              // _buildBottomTotalBar(isTablet),
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

  Widget _buildPromoFilterButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Promo',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _showPromoFilter = !_showPromoFilter),
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
                Icon(Icons.local_offer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_selectedPromos.length} dipilih',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _showPromoFilter ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: Colors.grey.shade600,
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
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadReportData,
            icon: _isLoading
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Icon(Icons.refresh, size: 14, color: Colors.white),
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

  Widget _buildPromoFilterPanel(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 10, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Promo',
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selectedPromos = List.from(_allPromos)),
                    child: Text('Pilih Semua', style: GoogleFonts.montserrat(fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedPromos = []),
                    child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allPromos.map((promo) {
              final isSelected = _selectedPromos.contains(promo);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPromos.remove(promo);
                      } else {
                        _selectedPromos.add(promo);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF6A918) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF6A918) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      promo,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: () {
                _loadReportData();
                setState(() => _showPromoFilter = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6A918),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'Terapkan Filter',
                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTotalBar(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                    'Total Invoice',
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_invoices.length} invoices',
                    style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
              Text(
                _currencyFormat.format(_paymentSummary.totalAmount),
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF6A918),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_paymentSummary.totalCash > 0) _buildPaymentSummaryItem('Cash', _paymentSummary.totalCash),
                if (_paymentSummary.totalCard > 0) _buildPaymentSummaryItem('Card', _paymentSummary.totalCard),
                if (_paymentSummary.totalEdc > 0) _buildPaymentSummaryItem('EDC', _paymentSummary.totalEdc),
                if (_paymentSummary.totalDp > 0) _buildPaymentSummaryItem('DP', _paymentSummary.totalDp),
                if (_paymentSummary.totalOther > 0) _buildPaymentSummaryItem('Other', _paymentSummary.totalOther),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryItem(String label, double amount) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600)),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF6A918)),
          ),
        ],
      ),
    );
  }
}

class InvoiceDataSource extends DataGridSource {
  InvoiceDataSource({
    required List<SalesInvoice> invoices,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
    required Function(SalesInvoice) onTap,
  }) {
    _currencyFormat = currencyFormat;
    _numberFormat = numberFormat;
    _onTap = onTap;
    _invoices = invoices; // Simpan referensi invoices

    _totalAmount = invoices.fold<double>(0, (sum, inv) => sum + inv.amount);

    _data = invoices.asMap().entries.map((entry) {
      final index = entry.key + 1; // Nomor urut dimulai dari 1
      final inv = entry.value;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'Nomor', value: inv.nomor),
        DataGridCell<String>(columnName: 'Tanggal', value: _formatDateTime(inv.tanggal)),
        DataGridCell<String>(columnName: 'Meja', value: inv.meja),
        DataGridCell<String>(columnName: 'Customer', value: inv.customer.isNotEmpty ? inv.customer : 'Umum'),
        DataGridCell<String>(columnName: 'Duration', value: inv.duration),
        DataGridCell<double>(columnName: 'Amount', value: inv.amount),
        DataGridCell<double>(columnName: 'SeviceCharge', value: inv.serviceCharge),
        DataGridCell<double>(columnName: 'Tax', value: inv.tax),
        DataGridCell<double>(columnName: 'Discount', value: inv.discount),
        DataGridCell<double>(columnName: 'Cash', value: inv.cash),
        DataGridCell<double>(columnName: 'Card', value: inv.card),
        DataGridCell<double>(columnName: 'DP', value: inv.dp),
        DataGridCell<double>(columnName: 'EDC', value: inv.edc),
        DataGridCell<double>(columnName: 'Other_Value', value: inv.otherValue),
        DataGridCell<String>(columnName: 'Other', value: inv.other),
        DataGridCell<String>(columnName: 'StatusOrder', value: inv.statusOrder),
        DataGridCell<String>(columnName: 'Promo', value: inv.promo.isNotEmpty ? inv.promo : '-'),
        DataGridCell<String>(columnName: 'Kasir', value: inv.kasir),
      ]);
    }).toList();
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  List<DataGridRow> _data = [];
  late NumberFormat _currencyFormat;
  late NumberFormat _numberFormat;
  late Function(SalesInvoice) _onTap;
  late double _totalAmount;
  late List<SalesInvoice> _invoices; // Simpan referensi

  @override
  List<DataGridRow> get rows => _data;

  @override
  Widget? buildTableSummaryCellWidget(
      GridTableSummaryRow summaryRow,
      GridSummaryColumn? summaryColumn,
      RowColumnIndex rowColumnIndex,
      String summaryValue) {

    if (summaryColumn?.name == 'TotalInvoice') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerRight,
        child: Text(
          _currencyFormat.format(_totalAmount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Color(0xFFF6A918),
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
            color: Color(0xFFF6A918),
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
        final isAmount = cell.columnName == 'Amount' ||
            cell.columnName == 'SeviceCharge' ||
            cell.columnName == 'Tax' ||
            cell.columnName == 'Discount' ||
            cell.columnName == 'Cash' ||
            cell.columnName == 'Card' ||
            cell.columnName == 'DP' ||
            cell.columnName == 'EDC' ||
            cell.columnName == 'Other_Value';

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
              color: isAmount
                  ? const Color(0xFFF6A918)
                  : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'Amount' ||
        columnName == 'SeviceCharge' ||
        columnName == 'Tax' ||
        columnName == 'Discount' ||
        columnName == 'Cash' ||
        columnName == 'Card' ||
        columnName == 'DP' ||
        columnName == 'EDC' ||
        columnName == 'Other_Value') {
      return Alignment.centerRight;
    }
    return Alignment.centerLeft;
  }

  TextAlign _getTextAlign(String columnName) {
    if (columnName == 'Amount' ||
        columnName == 'SeviceCharge' ||
        columnName == 'Tax' ||
        columnName == 'Discount' ||
        columnName == 'Cash' ||
        columnName == 'Card' ||
        columnName == 'DP' ||
        columnName == 'EDC' ||
        columnName == 'Other_Value') {
      return TextAlign.right;
    }
    return TextAlign.left;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'Amount' ||
        columnName == 'SeviceCharge' ||
        columnName == 'Tax' ||
        columnName == 'Discount' ||
        columnName == 'Cash' ||
        columnName == 'Card' ||
        columnName == 'DP' ||
        columnName == 'EDC' ||
        columnName == 'Other_Value') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}