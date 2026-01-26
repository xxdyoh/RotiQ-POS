import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stock_report_service.dart';
import '../models/stock_report.dart';
import '../widgets/base_layout.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<StockReport> _stockData = [];
  List<StockReport> _filteredData = [];
  List<String> _allCategories = [];
  List<String> _selectedCategories = [];
  bool _showCategoryFilter = false;
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'name_asc';
  final Set<String> _expandedItems = {};
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
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _loadCategories();
    _loadReportData();
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

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await StockReportService.getStockReport(
        startDate: _startDate!,
        endDate: _endDate!,
        selectedCategories: _selectedCategories,
      );

      final data = List<Map<String, dynamic>>.from(response['data']);

      setState(() {
        _stockData = data.map((json) => StockReport.fromJson(json)).toList();
        _stockSummary = StockSummary.fromJson(response['summary'] ?? {});
        _expandedItems.clear();
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
    List<StockReport> filtered = _stockData;

    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchLower = _searchController.text.toLowerCase();
        return item.NAMA.toLowerCase().contains(searchLower) ||
            item.CATEGORY.toLowerCase().contains(searchLower);
      }).toList();
    }

    filtered = _applySorting(filtered);
    setState(() {
      _filteredData = filtered;
    });
  }

  List<StockReport> _applySorting(List<StockReport> data) {
    switch (_sortBy) {
      case 'name_asc':
        return data..sort((a, b) => a.NAMA.compareTo(b.NAMA));
      case 'name_desc':
        return data..sort((a, b) => b.NAMA.compareTo(a.NAMA));
      case 'category_asc':
        return data..sort((a, b) => a.CATEGORY.compareTo(b.CATEGORY));
      case 'category_desc':
        return data..sort((a, b) => b.CATEGORY.compareTo(a.CATEGORY));
      case 'akhir_desc':
        return data..sort((a, b) => b.Akhir.compareTo(a.Akhir));
      case 'akhir_asc':
        return data..sort((a, b) => a.Akhir.compareTo(b.Akhir));
      case 'sales_desc':
        return data..sort((a, b) => b.Sales.compareTo(a.Sales));
      case 'sales_asc':
        return data..sort((a, b) => a.Sales.compareTo(b.Sales));
      case 'stokin_desc':
        return data..sort((a, b) => b.Stok_in.compareTo(a.Stok_in));
      case 'stokin_asc':
        return data..sort((a, b) => a.Stok_in.compareTo(b.Stok_in));
      default:
        return data;
    }
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedItems.contains(id)) {
        _expandedItems.remove(id);
      } else {
        _expandedItems.add(id);
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

  String _formatPeriod() {
    if (_startDate == null || _endDate == null) return '';
    final startStr = DateFormat('dd/MM').format(_startDate!);
    final endStr = DateFormat('dd/MM').format(_endDate!);
    return '$startStr - $endStr';
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'name_asc': return 'A-Z';
      case 'name_desc': return 'Z-A';
      case 'category_asc': return 'Kat A-Z';
      case 'category_desc': return 'Kat Z-A';
      case 'akhir_desc': return 'Stok ↑';
      case 'akhir_asc': return 'Stok ↓';
      case 'sales_desc': return 'Sales ↑';
      case 'sales_asc': return 'Sales ↓';
      case 'stokin_desc': return 'Stok In ↑';
      case 'stokin_asc': return 'Stok In ↓';
      default: return 'Urut';
    }
  }

  Color _getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 10) return Colors.orange;
    return Colors.green;
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'Dari Tanggal',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildCategoryFilterButton(),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          flex: 1,
                          child: _buildLoadButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ========== CATEGORY FILTER PANEL ==========
              if (_showCategoryFilter) _buildCategoryFilterPanel(isTablet),

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
                                  hintText: 'Cari item atau kategori...',
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
                          const PopupMenuItem(value: 'name_asc', child: Text('A-Z Nama')),
                          const PopupMenuItem(value: 'name_desc', child: Text('Z-A Nama')),
                          const PopupMenuItem(value: 'category_asc', child: Text('A-Z Kategori')),
                          const PopupMenuItem(value: 'category_desc', child: Text('Z-A Kategori')),
                          const PopupMenuItem(value: 'akhir_desc', child: Text('Stok Tertinggi')),
                          const PopupMenuItem(value: 'akhir_asc', child: Text('Stok Terendah')),
                          const PopupMenuItem(value: 'sales_desc', child: Text('Penjualan Tertinggi')),
                          const PopupMenuItem(value: 'sales_asc', child: Text('Penjualan Terendah')),
                          const PopupMenuItem(value: 'stokin_desc', child: Text('Stok In Tertinggi')),
                          const PopupMenuItem(value: 'stokin_asc', child: Text('Stok In Terendah')),
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
                    : _filteredData.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Tidak ada data stok'
                            : 'Data stok tidak ditemukan',
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
                    itemCount: _filteredData.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _buildStockCard(_filteredData[index], index, isTablet);
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

  Widget _buildCategoryFilterButton() {
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
        InkWell(
          onTap: () {
            setState(() {
              _showCategoryFilter = !_showCategoryFilter;
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
                Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_selectedCategories.length} dipilih',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _showCategoryFilter ? Icons.expand_less : Icons.expand_more,
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

  Widget _buildCategoryFilterPanel(bool isTablet) {
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
                'Pilih Kategori',
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
                        _selectedCategories = List.from(_allCategories);
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
                        _selectedCategories = [];
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
            children: _allCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(category);
                      } else {
                        _selectedCategories.add(category);
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
                      category,
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
                  _showCategoryFilter = false;
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

  Widget _buildStockCard(StockReport item, int index, bool isTablet) {
    final isExpanded = _expandedItems.contains(item.ID);
    final change = item.change;

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
          onTap: () => _toggleExpand(item.ID),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header Section
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _getStockColor(item.Akhir),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.Akhir > 0 ? Icons.inventory : Icons.inventory_2_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.NAMA,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  item.CATEGORY,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Periode: ${_formatPeriod()}',
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
                        Row(
                          children: [
                            Text(
                              'Stok: ',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              item.Akhir.toString(),
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _getStockColor(item.Akhir),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          change >= 0 ? '+$change' : '$change',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: change >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ],
                ),
                // Expanded Section
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Stock Details Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isTablet ? 4 : 2,
                    childAspectRatio: isTablet ? 1.5 : 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _buildStockDetailItem(
                        'Stok Awal',
                        item.Awal.toString(),
                        Colors.grey.shade700,
                        Icons.play_arrow,
                      ),
                      _buildStockDetailItem(
                        'Stok In',
                        '+${item.Stok_in}',
                        Colors.green,
                        Icons.add_circle_outline,
                      ),
                      _buildStockDetailItem(
                        'Retur',
                        '+${item.Retur}',
                        Colors.blue,
                        Icons.reply,
                      ),
                      _buildStockDetailItem(
                        'Sales',
                        '-${item.Sales}',
                        Colors.red,
                        Icons.remove_circle_outline,
                      ),
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

  Widget _buildStockDetailItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
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
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
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
                    '${_filteredData.length} items',
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTotalItem('Awal', _stockSummary.totalAwal, Colors.grey.shade700),
                _buildTotalItem('Stok In', _stockSummary.totalStokIn, Colors.green),
                _buildTotalItem('Retur', _stockSummary.totalRetur, Colors.blue),
                _buildTotalItem('Sales', _stockSummary.totalSales, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, int value, Color color) {
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
              value.toString(),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        )
    );
    }
}