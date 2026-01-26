import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<SalesInvoice> _filteredInvoices = [];

  // Promo filter
  List<String> _allPromos = [];
  List<String> _selectedPromos = [];
  bool _showPromoFilter = false;

  // Search & Sorting
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date_desc';

  // Expanded cards
  final Set<String> _expandedInvoices = {};

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

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _loadPromos();
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
        _expandedInvoices.clear();
      });

      _applyFilters();
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<SalesInvoice> filtered = _invoices;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final searchLower = _searchController.text.toLowerCase();
        return invoice.nomor.toLowerCase().contains(searchLower) ||
            invoice.customer.toLowerCase().contains(searchLower) ||
            invoice.kasir.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);

    setState(() {
      _filteredInvoices = filtered;
    });
  }

  List<SalesInvoice> _applySorting(List<SalesInvoice> data) {
    switch (_sortBy) {
      case 'date_desc':
        return data..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      case 'date_asc':
        return data..sort((a, b) => a.tanggal.compareTo(b.tanggal));
      case 'invoice_asc':
        return data..sort((a, b) => a.nomor.compareTo(b.nomor));
      case 'invoice_desc':
        return data..sort((a, b) => b.nomor.compareTo(a.nomor));
      case 'amount_desc':
        return data..sort((a, b) => b.amount.compareTo(a.amount));
      case 'amount_asc':
        return data..sort((a, b) => a.amount.compareTo(b.amount));
      case 'customer_asc':
        return data..sort((a, b) => a.customer.compareTo(b.customer));
      case 'customer_desc':
        return data..sort((a, b) => b.customer.compareTo(a.customer));
      default:
        return data;
    }
  }

  void _toggleExpand(String invoiceNo) {
    setState(() {
      if (_expandedInvoices.contains(invoiceNo)) {
        _expandedInvoices.remove(invoiceNo);
      } else {
        _expandedInvoices.add(invoiceNo);
      }
    });
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
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'date_desc': return 'Terbaru';
      case 'date_asc': return 'Terlama';
      case 'invoice_asc': return 'A-Z';
      case 'invoice_desc': return 'Z-A';
      case 'customer_asc': return 'Cust A-Z';
      case 'customer_desc': return 'Cust Z-A';
      case 'amount_desc': return 'Amount ↑';
      case 'amount_asc': return 'Amount ↓';
      default: return 'Urut';
    }
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
              // ========== COMPACT FILTER SECTION ==========
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
                    // ROW 1: DATE FIELDS
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'Dari Tanggal',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDateField(
                            label: 'Sampai Tanggal',
                            date: _endDate,
                            onTap: () => _selectEndDate(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ROW 2: PROMO + LOAD BUTTON
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildPromoFilterButton(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildLoadButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ========== PROMO FILTER PANEL ==========
              if (_showPromoFilter) _buildPromoFilterPanel(isTablet),

              // ========== SEARCH & SORT SECTION ==========
              Container(
                margin: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 10, vertical: 6),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari invoice, customer, atau kasir...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
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
                    const SizedBox(width: 12),
                    Container(
                      height: 36,
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          setState(() {
                            _sortBy = value;
                          });
                          _applyFilters();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'date_desc', child: Text('Tanggal Terbaru')),
                          const PopupMenuItem(value: 'date_asc', child: Text('Tanggal Terlama')),
                          const PopupMenuItem(value: 'invoice_asc', child: Text('A-Z Invoice')),
                          const PopupMenuItem(value: 'invoice_desc', child: Text('Z-A Invoice')),
                          const PopupMenuItem(value: 'customer_asc', child: Text('A-Z Customer')),
                          const PopupMenuItem(value: 'customer_desc', child: Text('Z-A Customer')),
                          const PopupMenuItem(value: 'amount_desc', child: Text('Amount Tertinggi')),
                          const PopupMenuItem(value: 'amount_asc', child: Text('Amount Terendah')),
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
                              Text(
                                _getSortLabel(),
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== REPORT DATA ==========
              Expanded(
                child: _isLoading
                    ? Center(
                  child: CircularProgressIndicator(color: const Color(0xFFF6A918)),
                )
                    : _filteredInvoices.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data invoice'
                            : 'Invoice tidak ditemukan',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  margin: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
                  child: ListView.separated(
                    itemCount: _filteredInvoices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildInvoiceCard(_filteredInvoices[index], index);
                    },
                  ),
                ),
              ),

              // ========== BOTTOM TOTAL BAR ==========
              _buildBottomTotalBar(isTablet),
            ],
          );
        },
      ),
    );
  }

  // ========== WIDGET COMPONENTS ==========

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
          onTap: () {
            setState(() {
              _showPromoFilter = !_showPromoFilter;
            });
          },
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
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPromos = List.from(_allPromos);
                      });
                    },
                    child: Text(
                      'Pilih Semua',
                      style: GoogleFonts.montserrat(fontSize: 10),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPromos = [];
                      });
                    },
                    child: Text(
                      'Hapus',
                      style: GoogleFonts.montserrat(fontSize: 10),
                    ),
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
                        width: 1,
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
                setState(() {
                  _showPromoFilter = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6A918),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Terapkan Filter',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(SalesInvoice invoice, int index) {
    final isExpanded = _expandedInvoices.contains(invoice.nomor);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _toggleExpand(invoice.nomor),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                invoice.nomor,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0066CC),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(invoice.tanggal),
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.customer.isNotEmpty ? invoice.customer : 'Umum',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (invoice.promo.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    invoice.promo,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                invoice.paymentMethodsText,
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(invoice.amount),
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF6A918),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ],
                ),
                // Expanded Details
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          'Items (${invoice.details.length})',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Kasir: ${invoice.kasir}',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...invoice.details.map((detail) => _buildDetailItem(detail)).toList(),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (invoice.cash > 0)
                          _buildPaymentMethod('Cash', invoice.cash),
                        if (invoice.card > 0)
                          _buildPaymentMethod('Card', invoice.card),
                        if (invoice.edc > 0)
                          _buildPaymentMethod('EDC', invoice.edc),
                        if (invoice.dp > 0)
                          _buildPaymentMethod('DP', invoice.dp),
                        if (invoice.otherValue > 0)
                          _buildPaymentMethod('Other', invoice.otherValue),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(InvoiceDetail detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.nama,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Qty: ${detail.qty}',
                      style: GoogleFonts.montserrat(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (detail.disc > 0)
                      Text(
                        'Disc: ${detail.disc}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          color: Colors.red.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (detail.disc > 0)
                Text(
                  _formatCurrency(detail.price),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    color: Colors.grey.shade500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                _formatCurrency(detail.netPrice),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF6A918),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String method, double amount) {
    return Column(
      children: [
        Text(
          method,
          style: GoogleFonts.montserrat(
            fontSize: 8,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: GoogleFonts.montserrat(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF6A918),
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
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_filteredInvoices.length} invoices',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Text(
                _formatCurrency(_paymentSummary.totalAmount),
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
                if (_paymentSummary.totalCash > 0)
                  _buildPaymentSummaryItem('Cash', _paymentSummary.totalCash),
                if (_paymentSummary.totalCard > 0)
                  _buildPaymentSummaryItem('Card', _paymentSummary.totalCard),
                if (_paymentSummary.totalEdc > 0)
                  _buildPaymentSummaryItem('EDC', _paymentSummary.totalEdc),
                if (_paymentSummary.totalDp > 0)
                  _buildPaymentSummaryItem('DP', _paymentSummary.totalDp),
                if (_paymentSummary.totalOther > 0)
                  _buildPaymentSummaryItem('Other', _paymentSummary.totalOther),
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
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF6A918),
            ),
          ),
        ],
      ),
    );
  }
}