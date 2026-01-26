import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sales_order_service.dart';
import '../models/sales_order.dart';
import '../widgets/base_layout.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  State<SalesOrderScreen> createState() => _SalesOrderScreenState();
}

class _SalesOrderScreenState extends State<SalesOrderScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<SalesOrder> _orders = [];
  List<SalesOrder> _filteredOrders = [];

  // Search & Sorting
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date_desc';

  // Expanded cards
  final Set<String> _expandedOrders = {};

  // Order summary
  OrderSummary _orderSummary = OrderSummary(
    totalOrders: 0,
    totalNilai: 0,
    totalDp: 0,
    totalBelum: 0,
    totalSudah: 0,
  );

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
      final response = await SalesOrderService.getSalesOrders(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _orders = data.map((json) => SalesOrder.fromJson(json)).toList();
        _orderSummary = OrderSummary.fromJson(response['summary'] ?? {});
        _expandedOrders.clear();
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
    List<SalesOrder> filtered = _orders;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((order) {
        final searchLower = _searchController.text.toLowerCase();
        return order.nomor.toLowerCase().contains(searchLower) ||
            order.atasNama.toLowerCase().contains(searchLower) ||
            order.noHp.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);

    setState(() {
      _filteredOrders = filtered;
    });
  }

  List<SalesOrder> _applySorting(List<SalesOrder> data) {
    switch (_sortBy) {
      case 'date_desc':
        return data..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      case 'date_asc':
        return data..sort((a, b) => a.tanggal.compareTo(b.tanggal));
      case 'order_asc':
        return data..sort((a, b) => a.nomor.compareTo(b.nomor));
      case 'order_desc':
        return data..sort((a, b) => b.nomor.compareTo(a.nomor));
      case 'customer_asc':
        return data..sort((a, b) => a.atasNama.compareTo(b.atasNama));
      case 'customer_desc':
        return data..sort((a, b) => b.atasNama.compareTo(a.atasNama));
      case 'nilai_desc':
        return data..sort((a, b) => b.nilai.compareTo(a.nilai));
      case 'nilai_asc':
        return data..sort((a, b) => a.nilai.compareTo(b.nilai));
      case 'dp_desc':
        return data..sort((a, b) => b.dp.compareTo(a.dp));
      case 'dp_asc':
        return data..sort((a, b) => a.dp.compareTo(b.dp));
      case 'status':
        return data..sort((a, b) => b.status.compareTo(a.status));
      default:
        return data;
    }
  }

  void _toggleExpand(String orderNo) {
    setState(() {
      if (_expandedOrders.contains(orderNo)) {
        _expandedOrders.remove(orderNo);
      } else {
        _expandedOrders.add(orderNo);
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
    if (dateString.isEmpty || dateString == 'null') return '';
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
      case 'order_asc': return 'A-Z';
      case 'order_desc': return 'Z-A';
      case 'customer_asc': return 'Cust A-Z';
      case 'customer_desc': return 'Cust Z-A';
      case 'nilai_desc': return 'Nilai ↑';
      case 'nilai_asc': return 'Nilai ↓';
      case 'dp_desc': return 'DP ↑';
      case 'dp_asc': return 'DP ↓';
      case 'status': return 'Status';
      default: return 'Urut';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'List Sales Order',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // ========== COMPACT FILTER SECTION - 1 ROW ==========
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
                    // From Date
                    Expanded(
                      child: _buildDateField(
                        label: 'Dari Tanggal',
                        date: _startDate,
                        onTap: () => _selectStartDate(context),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),

                    // To Date
                    Expanded(
                      child: _buildDateField(
                        label: 'Sampai Tanggal',
                        date: _endDate,
                        onTap: () => _selectEndDate(context),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),

                    // Load Button
                    SizedBox(
                      width: isTablet ? 100 : 80,
                      child: _buildLoadButton(),
                    ),
                  ],
                ),
              ),

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
                                  hintText: 'Cari order, customer, atau no HP...',
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
                          const PopupMenuItem(value: 'order_asc', child: Text('A-Z Order')),
                          const PopupMenuItem(value: 'order_desc', child: Text('Z-A Order')),
                          const PopupMenuItem(value: 'customer_asc', child: Text('A-Z Customer')),
                          const PopupMenuItem(value: 'customer_desc', child: Text('Z-A Customer')),
                          const PopupMenuItem(value: 'nilai_desc', child: Text('Nilai Tertinggi')),
                          const PopupMenuItem(value: 'nilai_asc', child: Text('Nilai Terendah')),
                          const PopupMenuItem(value: 'dp_desc', child: Text('DP Tertinggi')),
                          const PopupMenuItem(value: 'dp_asc', child: Text('DP Terendah')),
                          const PopupMenuItem(value: 'status', child: Text('Status (Sudah→Belum)')),
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
                    : _filteredOrders.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.list_alt,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data order'
                            : 'Order tidak ditemukan',
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
                    itemCount: _filteredOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildOrderCard(_filteredOrders[index], index);
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

  Widget _buildLoadButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 13),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loadReportData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF6A918),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(70, 36),
            ),
            child: _isLoading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(Icons.refresh, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(SalesOrder order, int index) {
    final isExpanded = _expandedOrders.contains(order.nomor);

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
          onTap: () => _toggleExpand(order.nomor),
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
                        color: order.isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        order.isPaid ? Icons.check_circle : Icons.pending,
                        size: 14,
                        color: order.isPaid ? Colors.green.shade700 : Colors.orange.shade700,
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
                                order.nomor,
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
                                _formatDate(order.tanggal),
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
                            order.customerDisplay,
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: order.isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  order.status,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w500,
                                    color: order.isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (order.hasAmbilDate)
                                Text(
                                  'Ambil: ${_formatDate(order.tglAmbil)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
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
                          _formatCurrency(order.nilai),
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF6A918),
                          ),
                        ),
                        if (order.dp > 0)
                          Text(
                            'DP: ${_formatCurrency(order.dp)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
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
                if (isExpanded && order.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          'Items (${order.details.length})',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (order.hasBayarDate)
                          Text(
                            'Bayar: ${_formatDate(order.tglBayar)}',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...order.details.map((detail) => _buildDetailItem(detail)).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(OrderDetail detail) {
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
                    const SizedBox(width: 8),
                    if (detail.salesType.isNotEmpty)
                      Text(
                        detail.salesType,
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          color: Colors.blue.shade600,
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
                    'Total Order',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_orderSummary.totalSudah} Sudah',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_orderSummary.totalBelum} Belum',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(_orderSummary.totalNilai),
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF6A918),
                    ),
                  ),
                  if (_orderSummary.totalDp > 0)
                    Text(
                      'DP: ${_formatCurrency(_orderSummary.totalDp)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
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