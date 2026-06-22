import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/sales_invoice_service.dart';
import '../models/sales_invoice.dart';
import '../widgets/base_layout.dart';
import '../services/session_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Row, Border, Column;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class SalesByInvoiceScreen extends StatefulWidget {
  const SalesByInvoiceScreen({super.key});

  @override
  State<SalesByInvoiceScreen> createState() => _SalesByInvoiceScreenState();
}

class _SalesByInvoiceScreenState extends State<SalesByInvoiceScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  bool _isPusat = false;
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

  // Totals untuk footer
  double _totalAmount = 0;
  double _totalServiceCharge = 0;
  double _totalTax = 0;
  double _totalDiscount = 0;
  double _totalCash = 0;
  double _totalCard = 0;
  double _totalDp = 0;
  double _totalEdc = 0;
  double _totalOtherValue = 0;
  int _totalFilteredInvoices = 0;

  final NumberFormat _currencyFormat =
  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');
  final DateFormat _displayDateFormat = DateFormat('dd/MM/yy');

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month, 1);

    final cabang = SessionManager.getCurrentCabang();
    _isPusat = cabang?.kode == '00';

    _dataSource = InvoiceDataSource(
      invoices: [],
      currencyFormat: _currencyFormat,
      numberFormat: _numberFormat,
      isPusat: _isPusat,
      onFilterChanged: _onFilterChanged,
      onTap: _showInvoiceDetailBottomSheet,
    );

    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      final response = await SalesInvoiceService.getSalesByInvoice(
        startDate: _startDate!,
        endDate: _endDate!,
        selectedPromos: _selectedPromos,
        isPusat: _isPusat,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _invoices = data.map((json) => SalesInvoice.fromJson(json)).toList();
        _paymentSummary = PaymentSummary.fromJson(response['summary'] ?? {});

        _calculateTotals(_invoices);

        _dataSource = InvoiceDataSource(
          invoices: _invoices,
          currencyFormat: _currencyFormat,
          numberFormat: _numberFormat,
          isPusat: _isPusat,
          onFilterChanged: _onFilterChanged,
          onTap: _showInvoiceDetailBottomSheet,
        );
      });
    } catch (e) {
      _showSnackbar('Error: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ CALLBACK FILTER - Total dinamis sesuai filter
  void _onFilterChanged(DataGridFilterChangeDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dataSource.effectiveRows != null) {
        final filteredRows = _dataSource.effectiveRows!;

        double totalAmount = 0, totalSc = 0, totalTax = 0, totalDisc = 0;
        double totalCash = 0, totalCard = 0, totalDp = 0, totalEdc = 0, totalOther = 0;

        for (var row in filteredRows) {
          final cells = row.getCells();
          for (var cell in cells) {
            final val = (cell.value is num) ? (cell.value as num).toDouble() : 0.0;
            switch (cell.columnName) {
              case 'Amount': totalAmount += val;
              case 'SeviceCharge': totalSc += val;
              case 'Tax': totalTax += val;
              case 'Discount': totalDisc += val;
              case 'Cash': totalCash += val;
              case 'Card': totalCard += val;
              case 'DP': totalDp += val;
              case 'EDC': totalEdc += val;
              case 'Other_Value': totalOther += val;
            }
          }
        }

        setState(() {
          _totalFilteredInvoices = filteredRows.length;
          _totalAmount = totalAmount;
          _totalServiceCharge = totalSc;
          _totalTax = totalTax;
          _totalDiscount = totalDisc;
          _totalCash = totalCash;
          _totalCard = totalCard;
          _totalDp = totalDp;
          _totalEdc = totalEdc;
          _totalOtherValue = totalOther;
        });
      }
    });
  }

  Future<void> _exportToExcel() async {
    if (_invoices.isEmpty) {
      _showSnackbar('Tidak ada data untuk di-export', false);
      return;
    }

    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Sales by Invoice';

      final colCount = _isPusat ? 20 : 19;

      sheet.getRangeByIndex(1, 1).columnWidth = 6;
      sheet.getRangeByIndex(1, 2).columnWidth = 18;
      sheet.getRangeByIndex(1, 3).columnWidth = 14;
      sheet.getRangeByIndex(1, 4).columnWidth = 8;
      sheet.getRangeByIndex(1, 5).columnWidth = 15;
      sheet.getRangeByIndex(1, 6).columnWidth = 10;
      sheet.getRangeByIndex(1, 7).columnWidth = 14;
      sheet.getRangeByIndex(1, 8).columnWidth = 12;
      sheet.getRangeByIndex(1, 9).columnWidth = 10;
      sheet.getRangeByIndex(1, 10).columnWidth = 10;
      sheet.getRangeByIndex(1, 11).columnWidth = 12;
      sheet.getRangeByIndex(1, 12).columnWidth = 10;
      sheet.getRangeByIndex(1, 13).columnWidth = 10;
      sheet.getRangeByIndex(1, 14).columnWidth = 10;
      sheet.getRangeByIndex(1, 15).columnWidth = 12;
      sheet.getRangeByIndex(1, 16).columnWidth = 12;
      sheet.getRangeByIndex(1, 17).columnWidth = 10;
      sheet.getRangeByIndex(1, 18).columnWidth = 12;
      sheet.getRangeByIndex(1, 19).columnWidth = 12;
      if (_isPusat) sheet.getRangeByIndex(1, 20).columnWidth = 12;

      final periodeRange = sheet.getRangeByIndex(1, 1, 1, colCount);
      periodeRange.merge();
      periodeRange.setText(
          'Periode: ${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}');
      periodeRange.cellStyle.fontSize = 11;
      periodeRange.cellStyle.bold = true;
      periodeRange.cellStyle.hAlign = HAlignType.left;
      periodeRange.cellStyle.backColor = '#F1F5F9';

      int row = 3;
      final headerRange = sheet.getRangeByIndex(row, 1, row, colCount);
      headerRange.cellStyle.backColor = '#2C3E50';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.fontSize = 10;
      headerRange.cellStyle.hAlign = HAlignType.center;
      headerRange.cellStyle.vAlign = VAlignType.center;

      final headers = [
        'No', 'Nomor', 'Tanggal', 'Meja', 'Customer', 'Durasi',
        'Amount', 'Service', 'Tax', 'Disc', 'Cash', 'Card', 'DP', 'EDC',
        'Other Value', 'Other', 'Status', 'Promo', 'Kasir'
      ];
      if (_isPusat) headers.add('Cabang');

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(row, i + 1).setText(headers[i]);
      }
      row++;

      for (var invoice in _invoices) {
        final values = [
          (row - 3).toString(),
          invoice.nomor,
          _formatDateTime(invoice.tanggal),
          invoice.meja,
          invoice.customer.isNotEmpty ? invoice.customer : 'Umum',
          invoice.duration,
          invoice.amount,
          invoice.serviceCharge,
          invoice.tax,
          invoice.discount,
          invoice.cash,
          invoice.card,
          invoice.dp,
          invoice.edc,
          invoice.otherValue,
          invoice.other,
          invoice.statusOrder,
          invoice.promo.isNotEmpty ? invoice.promo : '-',
          invoice.kasir,
        ];
        if (_isPusat) values.add(invoice.cabang);

        for (int i = 0; i < values.length; i++) {
          final cell = sheet.getRangeByIndex(row, i + 1);
          if (values[i] is double || values[i] is int) {
            cell.setNumber((values[i] as num).toDouble());
          } else {
            cell.setText(values[i].toString());
          }
        }

        final dataRange = sheet.getRangeByIndex(row, 1, row, colCount);
        dataRange.cellStyle.fontSize = 9;
        dataRange.cellStyle.vAlign = VAlignType.center;
        sheet.getRangeByIndex(row, 1).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 4).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 6).cellStyle.hAlign = HAlignType.center;
        sheet.getRangeByIndex(row, 17).cellStyle.hAlign = HAlignType.center;
        for (int i = 7; i <= 15; i++) {
          sheet.getRangeByIndex(row, i).cellStyle.hAlign = HAlignType.right;
        }
        sheet.getRangeByIndex(row, 10).cellStyle.fontColor = '#EF4444';
        if (row % 2 == 0) {
          dataRange.cellStyle.backColor = '#F8FAFC';
        }
        row++;
      }

      final totalRow = row;
      final totalRange = sheet.getRangeByIndex(totalRow, 1, totalRow, colCount);
      totalRange.cellStyle.backColor = '#E9ECEF';
      totalRange.cellStyle.bold = true;
      totalRange.cellStyle.fontSize = 9;
      sheet.getRangeByIndex(totalRow, 1).setText('');
      sheet.getRangeByIndex(totalRow, 2).setText('TOTAL');
      sheet.getRangeByIndex(totalRow, 2).cellStyle.hAlign = HAlignType.left;
      sheet.getRangeByIndex(totalRow, 3).setText('$_totalFilteredInvoices Invoice');

      final totals = <double>[
        0, 0, 0, _totalAmount, _totalServiceCharge, _totalTax,
        _totalDiscount, _totalCash, _totalCard, _totalDp,
        _totalEdc, _totalOtherValue
      ];
      final totalCols = [7, 8, 9, 10, 11, 12, 13, 14, 15];
      for (int i = 0; i < totalCols.length; i++) {
        sheet.getRangeByIndex(totalRow, totalCols[i]).setNumber(totals[i + 3]);
        sheet.getRangeByIndex(totalRow, totalCols[i]).cellStyle.hAlign = HAlignType.right;
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final fileName = 'Sales_Invoice_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        final blob = html.Blob([bytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..target = 'blank'
          ..download = fileName
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackbar('File Excel berhasil di-download', true);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        _showSnackbar('File Excel berhasil disimpan', true);
      }
    } catch (e) {
      debugPrint('Export Excel error: $e');
      _showSnackbar('Gagal export Excel: ${e.toString()}', false);
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _calculateTotals(List<SalesInvoice> invoices) {
    _totalFilteredInvoices = invoices.length;
    _totalAmount = invoices.fold(0.0, (sum, inv) => sum + inv.amount);
    _totalServiceCharge = invoices.fold(0.0, (sum, inv) => sum + inv.serviceCharge);
    _totalTax = invoices.fold(0.0, (sum, inv) => sum + inv.tax);
    _totalDiscount = invoices.fold(0.0, (sum, inv) => sum + inv.discount);
    _totalCash = invoices.fold(0.0, (sum, inv) => sum + inv.cash);
    _totalCard = invoices.fold(0.0, (sum, inv) => sum + inv.card);
    _totalDp = invoices.fold(0.0, (sum, inv) => sum + inv.dp);
    _totalEdc = invoices.fold(0.0, (sum, inv) => sum + inv.edc);
    _totalOtherValue = invoices.fold(0.0, (sum, inv) => sum + inv.otherValue);
  }

  // ✅ BUILD FOOTER WIDGET (bukan FooterRow)
  Widget _buildFooterWidget(double screenWidth) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _bgSoft,
        border: Border(top: BorderSide(color: _borderSoft)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: screenWidth - 40,
          child: Row(
            children: [
              Container(width: 50, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center,
                  child: Text('Total', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: _textDark))),
              Container(width: 130, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerLeft,
                  child: Row(children: [
                    Icon(Icons.receipt, size: 11, color: _primaryDark),
                    const SizedBox(width: 4),
                    Text('$_totalFilteredInvoices Inv', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _primaryDark)),
                  ])),
              Container(width: 130, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerLeft,
                  child: Text('${_displayDateFormat.format(_startDate!)} - ${_displayDateFormat.format(_endDate!)}',
                      style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.w500, color: _textDark))),
              Container(width: 60),
              Container(width: 120),
              Container(width: 70),
              Container(width: 110, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalAmount), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: _accentGold))),
              Container(width: 90, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalServiceCharge), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textDark))),
              Container(width: 80, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalTax), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textDark))),
              Container(width: 80, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalDiscount), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red.shade600))),
              Container(width: 90, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalCash), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint))),
              Container(width: 80, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalCard), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint))),
              Container(width: 80, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalDp), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint))),
              Container(width: 80, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalEdc), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint))),
              Container(width: 90, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.centerRight,
                  child: Text(_currencyFormat.format(_totalOtherValue), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _accentMint))),
              Container(width: 80),
              Container(width: 70),
              Container(width: 100),
              Container(width: 100),
              if (_isPusat) Container(width: 100),
            ],
          ),
        ),
      ),
    );
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
                          Text(invoice.nomor,
                              style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF2C3E50))),
                          Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(invoice.tanggal)),
                              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: Icon(Icons.close, color: Colors.grey.shade600), onPressed: () => Navigator.pop(context)),
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
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildInfoItem('Meja', invoice.meja.isNotEmpty ? invoice.meja : '-')),
                              Expanded(child: _buildInfoItem('Customer', invoice.customer.isNotEmpty ? invoice.customer : 'Umum')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildInfoItem('Kasir', invoice.kasir)),
                              Expanded(child: _buildInfoItem('Status', invoice.statusOrder)),
                            ],
                          ),
                          if (_isPusat) ...[
                            const SizedBox(height: 8),
                            Row(children: [Expanded(child: _buildInfoItem('Cabang', invoice.cabang)), const Expanded(child: SizedBox())]),
                          ],
                          const SizedBox(height: 8),
                          if (invoice.promo.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer, size: 12, color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text('Promo: ${invoice.promo}',
                                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Detail Items', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
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
                              return DataRow(cells: [
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
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
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
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pembayaran',
                              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50))),
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
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.montserrat(fontSize: isTotal ? 12 : 11, fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal)),
          Text('${isNegative ? '-' : ''}${_currencyFormat.format(value)}',
              style: GoogleFonts.montserrat(
                  fontSize: isTotal ? 13 : 11,
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: isTotal ? const Color(0xFFF6A918) : (isNegative ? Colors.red.shade700 : Colors.black87))),
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
          Text(label, style: GoogleFonts.montserrat(fontSize: 11)),
          Text(_currencyFormat.format(amount),
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF6A918))),
        ],
      ),
    );
  }

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
        ],
      ),
      backgroundColor: isSuccess ? _accentMint : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: _primaryDark, onPrimary: Colors.white, surface: _surfaceWhite, onSurface: _textDark),
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
          colorScheme: ColorScheme.light(primary: _primaryDark, onPrimary: Colors.white, surface: _surfaceWhite, onSurface: _textDark),
          dialogBackgroundColor: _surfaceWhite,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return BaseLayout(
      title: 'Sales by Invoice',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Container(
        color: _bgSoft,
        child: Column(
          children: [
            // Header filter - compact
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                border: Border(bottom: BorderSide(color: _borderSoft)),
              ),
              child: Row(
                children: [
                  // Tanggal Mulai
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
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
                                  Text('Tanggal Mulai',
                                      style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                  Text(
                                    _startDate != null ? _displayDateFormat.format(_startDate!) : '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark),
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
                      onTap: () => _selectEndDate(context),
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
                                  Text('Tanggal Selesai',
                                      style: GoogleFonts.montserrat(fontSize: 9, color: _textLight)),
                                  Text(
                                    _endDate != null ? _displayDateFormat.format(_endDate!) : '-',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: _textDark),
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
                  // Load Button
                  Container(
                    width: 90,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentMint, _accentMint.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: _accentMint.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _loadReportData,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Load',
                                  style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Excel Button
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentGold, _accentGold.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: _accentGold.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _invoices.isEmpty ? null : _exportToExcel,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Icons.table_chart, size: 14, color: Colors.white),
                              if (!isMobile) ...[
                                const SizedBox(width: 6),
                                Text('Export Excel',
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
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
            // Data Grid
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _accentGold, strokeWidth: 2)),
                    const SizedBox(height: 12),
                    Text('Memuat data invoice...', style: GoogleFonts.montserrat(fontSize: 11, color: _textMedium)),
                  ],
                ),
              )
                  : _invoices.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(color: _bgSoft, shape: BoxShape.circle),
                        child: Icon(Icons.receipt_long_outlined, size: 35, color: _textLight)),
                    const SizedBox(height: 12),
                    Text('Tidak ada data invoice',
                        style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textDark)),
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
                    boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
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
                            source: _dataSource,
                            allowColumnsResizing: true,
                            columnResizeMode: ColumnResizeMode.onResize,
                            columnWidthMode: ColumnWidthMode.fill,
                            headerRowHeight: 32,
                            rowHeight: 32,
                            allowSorting: true,
                            allowFiltering: true,
                            onFilterChanged: _onFilterChanged,
                            gridLinesVisibility: GridLinesVisibility.both,
                            headerGridLinesVisibility: GridLinesVisibility.both,
                            selectionMode: SelectionMode.none,
                            onCellTap: (details) {
                              if (details.rowColumnIndex.rowIndex > 0) {
                                final dataRowIndex = details.rowColumnIndex.rowIndex - 1;
                                if (dataRowIndex >= 0 && dataRowIndex < _invoices.length) {
                                  _showInvoiceDetailBottomSheet(_invoices[dataRowIndex]);
                                }
                              }
                            },
                            columns: [
                              _buildGridColumn('no', 'No', width: 50, align: Alignment.center),
                              _buildGridColumn('Nomor', 'Nomor', width: 130),
                              _buildGridColumn('Tanggal', 'Tanggal', width: 130),
                              _buildGridColumn('Meja', 'Meja', width: 60, align: Alignment.center),
                              _buildGridColumn('Customer', 'Customer', width: 120),
                              _buildGridColumn('Duration', 'Durasi', width: 70, align: Alignment.center),
                              _buildGridColumn('Amount', 'Amount', width: 110, align: Alignment.centerRight),
                              _buildGridColumn('SeviceCharge', 'Service', width: 90, align: Alignment.centerRight),
                              _buildGridColumn('Tax', 'Tax', width: 80, align: Alignment.centerRight),
                              _buildGridColumn('Discount', 'Disc', width: 80, align: Alignment.centerRight),
                              _buildGridColumn('Cash', 'Cash', width: 90, align: Alignment.centerRight),
                              _buildGridColumn('Card', 'Card', width: 80, align: Alignment.centerRight),
                              _buildGridColumn('DP', 'DP', width: 80, align: Alignment.centerRight),
                              _buildGridColumn('EDC', 'EDC', width: 80, align: Alignment.centerRight),
                              _buildGridColumn('Other_Value', 'Other', width: 90, align: Alignment.centerRight),
                              _buildGridColumn('Other', 'Jenis Other', width: 80),
                              _buildGridColumn('StatusOrder', 'Status', width: 70, align: Alignment.center),
                              _buildGridColumn('Promo', 'Promo', width: 100),
                              _buildGridColumn('Kasir', 'Kasir', width: 100),
                              if (_isPusat) _buildGridColumn('Cabang', 'Cabang', width: 100),
                            ],
                          ),
                        ),
                      ),
                      // ✅ Footer widget (selalu di bawah grid)
                      _buildFooterWidget(screenWidth),
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

  GridColumn _buildGridColumn(String columnName, String title, {double width = 100, Alignment align = Alignment.centerLeft}) {
    return GridColumn(
      columnName: columnName,
      width: width,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: align,
        child: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 10, color: _textDark)),
      ),
    );
  }
}

// InvoiceDataSource dengan filter support
class InvoiceDataSource extends DataGridSource {
  final List<SalesInvoice> _invoices;
  final NumberFormat _currencyFormat;
  final NumberFormat _numberFormat;
  final Function(SalesInvoice) _onTap;
  final Function(DataGridFilterChangeDetails) _onFilterChanged;
  final bool isPusat;
  List<DataGridRow> _data = [];

  InvoiceDataSource({
    required List<SalesInvoice> invoices,
    required NumberFormat currencyFormat,
    required NumberFormat numberFormat,
    required this.isPusat,
    required Function(DataGridFilterChangeDetails) onFilterChanged,
    required Function(SalesInvoice) onTap,
  })  : _invoices = invoices,
        _currencyFormat = currencyFormat,
        _numberFormat = numberFormat,
        _onFilterChanged = onFilterChanged,
        _onTap = onTap {
    _data = invoices.asMap().entries.map((entry) {
      final index = entry.key + 1;
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
        if (isPusat) DataGridCell<String>(columnName: 'Cabang', value: inv.cabang),
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

  @override
  List<DataGridRow> get rows => _data;

  @override
  Future<void> handleFilterChange(DataGridFilterChangeDetails details) async {
    _onFilterChanged(details);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isAmount = cell.columnName == 'Amount' || cell.columnName == 'SeviceCharge' || cell.columnName == 'Tax' ||
            cell.columnName == 'Discount' || cell.columnName == 'Cash' || cell.columnName == 'Card' ||
            cell.columnName == 'DP' || cell.columnName == 'EDC' || cell.columnName == 'Other_Value';

        Color textColor = const Color(0xFF1A202C);
        if (cell.columnName == 'Discount') {
          textColor = Colors.red.shade600;
        } else if (isAmount) {
          textColor = const Color(0xFFF6A918);
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            isAmount ? _currencyFormat.format(cell.value) : cell.value.toString(),
            style: GoogleFonts.montserrat(fontSize: 10, fontWeight: _getFontWeight(cell.columnName), color: textColor),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    if (columnName == 'Amount' || columnName == 'SeviceCharge' || columnName == 'Tax' || columnName == 'Discount' ||
        columnName == 'Cash' || columnName == 'Card' || columnName == 'DP' || columnName == 'EDC' || columnName == 'Other_Value') {
      return Alignment.centerRight;
    }
    if (columnName == 'no' || columnName == 'Meja' || columnName == 'Duration' || columnName == 'StatusOrder') {
      return Alignment.center;
    }
    return Alignment.centerLeft;
  }

  FontWeight _getFontWeight(String columnName) {
    if (columnName == 'Amount' || columnName == 'SeviceCharge' || columnName == 'Tax' || columnName == 'Discount' ||
        columnName == 'Cash' || columnName == 'Card' || columnName == 'DP' || columnName == 'EDC' || columnName == 'Other_Value') {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }
}