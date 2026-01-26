import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/void_items_service.dart';
import '../models/void_item.dart';
import '../widgets/base_layout.dart';

class VoidItemsScreen extends StatefulWidget {
  const VoidItemsScreen({super.key});

  @override
  State<VoidItemsScreen> createState() => _VoidItemsScreenState();
}

class _VoidItemsScreenState extends State<VoidItemsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<VoidItem> _voidItems = [];
  List<VoidItem> _filteredItems = [];

  // Search & Sorting
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date_desc';

  // Void summary
  VoidSummary _voidSummary = VoidSummary(
    totalItems: 0,
    totalQty: 0,
    totalNilai: 0,
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
      final response = await VoidItemsService.getVoidItems(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _voidItems = data.map((json) => VoidItem.fromJson(json)).toList();
        _voidSummary = VoidSummary.fromJson(response['summary'] ?? {});
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
    List<VoidItem> filtered = _voidItems;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchLower = _searchController.text.toLowerCase();
        return item.nomor.toLowerCase().contains(searchLower) ||
            item.nama.toLowerCase().contains(searchLower) ||
            item.served.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);

    setState(() {
      _filteredItems = filtered;
    });
  }

  List<VoidItem> _applySorting(List<VoidItem> data) {
    switch (_sortBy) {
      case 'date_desc':
        return data..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      case 'date_asc':
        return data..sort((a, b) => a.tanggal.compareTo(b.tanggal));
      case 'invoice_asc':
        return data..sort((a, b) => a.nomor.compareTo(b.nomor));
      case 'invoice_desc':
        return data..sort((a, b) => b.nomor.compareTo(a.nomor));
      case 'served_asc':
        return data..sort((a, b) => a.served.compareTo(b.served));
      case 'served_desc':
        return data..sort((a, b) => b.served.compareTo(a.served));
      case 'qty_desc':
        return data..sort((a, b) => b.qty.compareTo(a.qty));
      case 'qty_asc':
        return data..sort((a, b) => a.qty.compareTo(b.qty));
      case 'nilai_desc':
        return data..sort((a, b) => b.nilai.compareTo(a.nilai));
      case 'nilai_asc':
        return data..sort((a, b) => a.nilai.compareTo(b.nilai));
      default:
        return data;
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
      case 'invoice_asc': return 'A-Z';
      case 'invoice_desc': return 'Z-A';
      case 'served_asc': return 'Served A-Z';
      case 'served_desc': return 'Served Z-A';
      case 'qty_desc': return 'Qty ↑';
      case 'qty_asc': return 'Qty ↓';
      case 'nilai_desc': return 'Nilai ↑';
      case 'nilai_asc': return 'Nilai ↓';
      default: return 'Urut';
    }
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
                                  hintText: 'Cari invoice, item, atau served...',
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
                          const PopupMenuItem(value: 'served_asc', child: Text('A-Z Served')),
                          const PopupMenuItem(value: 'served_desc', child: Text('Z-A Served')),
                          const PopupMenuItem(value: 'qty_desc', child: Text('Qty Tertinggi')),
                          const PopupMenuItem(value: 'qty_asc', child: Text('Qty Terendah')),
                          const PopupMenuItem(value: 'nilai_desc', child: Text('Nilai Tertinggi')),
                          const PopupMenuItem(value: 'nilai_asc', child: Text('Nilai Terendah')),
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
                    : _filteredItems.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data void'
                            : 'Data void tidak ditemukan',
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
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildVoidItemCard(_filteredItems[index], index);
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

  Widget _buildVoidItemCard(VoidItem item, int index) {
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
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.block,
                    size: 14,
                    color: Colors.red.shade700,
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
                            item.nomor,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(item.tanggal),
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
                        item.nama,
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
                          Text(
                            'Qty: ${item.qty}',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Served: ${item.served}',
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
                      _formatCurrency(item.nilai),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                    if (item.category.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.category,
                          style: GoogleFonts.montserrat(
                            fontSize: 7,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                    'Total Void',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_voidSummary.totalItems} items • Qty: ${_voidSummary.totalQty}',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Text(
                _formatCurrency(_voidSummary.totalNilai),
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}