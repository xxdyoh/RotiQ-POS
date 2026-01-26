import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/setoran_service.dart';
import '../models/setoran_model.dart';
import '../widgets/base_layout.dart';

class SalesDepositScreen extends StatefulWidget {
  const SalesDepositScreen({super.key});

  @override
  State<SalesDepositScreen> createState() => _SalesDepositScreenState();
}

class _SalesDepositScreenState extends State<SalesDepositScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<SalesDeposit> _deposits = [];
  List<SalesDeposit> _filteredDeposits = [];
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date_desc';
  final Set<String> _expandedDeposits = {};
  DepositSummary _depositSummary = DepositSummary(
    totalSetoran: 0,
    totalSelisih: 0,
    totalCash: 0,
    totalCard: 0,
    totalPiutang: 0,
    totalDpCash: 0,
    totalDpBank: 0,
    totalBiaya: 0,
    totalPendapatan: 0,
    totalGrandTotal: 0,
    totalCount: 0,
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
      final response = await SalesDepositService.getSalesDeposit(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _deposits = data.map((json) => SalesDeposit.fromJson(json)).toList();
        _depositSummary = DepositSummary.fromJson(response['summary'] ?? {});
        _expandedDeposits.clear();
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
    List<SalesDeposit> filtered = _deposits;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((deposit) {
        final searchLower = _searchController.text.toLowerCase();
        return deposit.Kode.toLowerCase().contains(searchLower) ||
            deposit.Tanggal.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);
    setState(() {
      _filteredDeposits = filtered;
    });
  }

  List<SalesDeposit> _applySorting(List<SalesDeposit> data) {
    switch (_sortBy) {
      case 'date_desc':
        return data..sort((a, b) => b.Tanggal.compareTo(a.Tanggal));
      case 'date_asc':
        return data..sort((a, b) => a.Tanggal.compareTo(b.Tanggal));
      case 'kode_asc':
        return data..sort((a, b) => a.Kode.compareTo(b.Kode));
      case 'kode_desc':
        return data..sort((a, b) => b.Kode.compareTo(a.Kode));
      case 'total_desc':
        return data..sort((a, b) => b.Total.compareTo(a.Total));
      case 'total_asc':
        return data..sort((a, b) => a.Total.compareTo(b.Total));
      default:
        return data;
    }
  }

  void _toggleExpand(String key) {
    setState(() {
      if (_expandedDeposits.contains(key)) {
        _expandedDeposits.remove(key);
      } else {
        _expandedDeposits.add(key);
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
      case 'kode_asc': return 'A-Z';
      case 'kode_desc': return 'Z-A';
      case 'total_desc': return 'Total ↑';
      case 'total_asc': return 'Total ↓';
      default: return 'Urut';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Setoran',
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
                                  hintText: 'Cari kode atau tanggal...',
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
                          const PopupMenuItem(value: 'kode_asc', child: Text('A-Z Kode')),
                          const PopupMenuItem(value: 'kode_desc', child: Text('Z-A Kode')),
                          const PopupMenuItem(value: 'total_desc', child: Text('Total Tertinggi')),
                          const PopupMenuItem(value: 'total_asc', child: Text('Total Terendah')),
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
                    : _filteredDeposits.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data setoran'
                            : 'Data setoran tidak ditemukan',
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
                    itemCount: _filteredDeposits.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildDepositCard(_filteredDeposits[index], index, isTablet);
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

  Widget _buildDepositCard(SalesDeposit deposit, int index, bool isTablet) {
    final cardKey = '${deposit.Kode}-${deposit.Tanggal}';
    final isExpanded = _expandedDeposits.contains(cardKey);

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
          onTap: () => _toggleExpand(cardKey),
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
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: 14,
                        color: Colors.purple.shade700,
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
                                deposit.Kode,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(deposit.Tanggal),
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _buildBadge('Setoran', deposit.Setoran, Colors.blue),
                              const SizedBox(width: 6),
                              _buildBadge('Selisih', deposit.Selisih,
                                  deposit.Selisih >= 0 ? Colors.green : Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(deposit.Total),
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
                  // Grid Details - responsive columns
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isTablet ? 4 : 2,
                    childAspectRatio: isTablet ? 1.8 : 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _buildDetailItem('Cash', deposit.Cash, Colors.green),
                      _buildDetailItem('Card', deposit.Card, Colors.blue),
                      _buildDetailItem('Piutang', deposit.Piutang, Colors.orange),
                      _buildDetailItem('DP Cash', deposit.DpCash, Colors.teal),
                      _buildDetailItem('DP Bank', deposit.DpBank, Colors.indigo),
                      _buildDetailItem('Biaya', deposit.Biaya, Colors.red),
                      _buildDetailItem('Pendapatan', deposit.Pendapatan, Colors.green.shade700),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatCurrency(value),
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatCurrency(value),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
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
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Setoran',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_filteredDeposits.length} data',
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
                  Text(
                    _formatCurrency(_depositSummary.totalGrandTotal),
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF6A918),
                    ),
                  ),
                  Text(
                    'Setoran: ${_formatCurrency(_depositSummary.totalSetoran)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // First row of totals
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_depositSummary.totalSelisih != 0)
                  _buildTotalItem('Selisih', _depositSummary.totalSelisih,
                      _depositSummary.totalSelisih >= 0 ? Colors.green : Colors.red),
                if (_depositSummary.totalCash > 0)
                  _buildTotalItem('Cash', _depositSummary.totalCash, Colors.green),
                if (_depositSummary.totalCard > 0)
                  _buildTotalItem('Card', _depositSummary.totalCard, Colors.blue),
                if (_depositSummary.totalPiutang > 0)
                  _buildTotalItem('Piutang', _depositSummary.totalPiutang, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Second row of totals
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_depositSummary.totalDpCash > 0)
                  _buildTotalItem('DP Cash', _depositSummary.totalDpCash, Colors.teal),
                if (_depositSummary.totalDpBank > 0)
                  _buildTotalItem('DP Bank', _depositSummary.totalDpBank, Colors.indigo),
                if (_depositSummary.totalBiaya > 0)
                  _buildTotalItem('Biaya', _depositSummary.totalBiaya, Colors.red),
                if (_depositSummary.totalPendapatan > 0)
                  _buildTotalItem('Pendapatan', _depositSummary.totalPendapatan, Colors.green.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, double value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
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
            _formatCurrency(value),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}