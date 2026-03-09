import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../services/item_service.dart';
import '../services/category_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DataGridController _dataGridController = DataGridController();

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _numberFormat = NumberFormat('#,##0');

  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  List<Map<String, dynamic>> _categories = [];
  late ItemDataSource _dataSource;

  int _totalItems = 0;
  int _totalStock = 0;
  double _totalValue = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final [items, categories] = await Future.wait([
        ItemService.getItems(),
        CategoryService.getCategories(),
      ]);

      setState(() {
        _items = items;
        _filteredItems = items;
        _categories = categories;
        _calculateTotals();
        _dataSource = ItemDataSource(
          items: _filteredItems,
          onEdit: _openEditItem,
          onDelete: _deleteItem,
          formatCurrency: currencyFormat,
          numberFormat: _numberFormat,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals() {
    _totalItems = _filteredItems.length;
    _totalStock = _filteredItems.fold(0, (sum, item) {
      return sum + (int.tryParse(item['Stok']?.toString() ?? '0') ?? 0);
    });
    _totalValue = _filteredItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
      return sum + (price * stock);
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items.where((item) {
        final name = item['Nama']?.toString().toLowerCase() ?? '';
        final category = item['Category']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            category.contains(query.toLowerCase());
      }).toList();

      _calculateTotals();

      _dataSource = ItemDataSource(
        items: _filteredItems,
        onEdit: _openEditItem,
        onDelete: _deleteItem,
        formatCurrency: currencyFormat,
        numberFormat: _numberFormat,
      );
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _openAddItem() {
    Navigator.pushNamed(
      context,
      AppRoutes.itemForm,
      arguments: {
        'categories': _categories,
        'onSaved': _loadData,
      },
    );
  }

  void _openEditItem(Map<String, dynamic> item) {
    Navigator.pushNamed(
      context,
      AppRoutes.itemForm,
      arguments: {
        'categories': _categories,
        'item': item,
        'onSaved': _loadData,
      },
    );
  }

  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Hapus Item?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${item['Nama']}"?',
            style: GoogleFonts.montserrat(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text('Hapus', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final result = await ItemService.deleteItem(item['id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadData();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showItemDetailBottomSheet(Map<String, dynamic> item) {
    final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
    final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
    final totalValue = price * stock;
    final hasFoto = item['foto'] != null && item['foto'].toString().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(0xFFF6A918).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFFF6A918),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['Nama'] ?? '-',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF6A918).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ID: ${item['id'] ?? '-'}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFF6A918),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Stat Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.category_outlined,
                            label: 'Kategori',
                            value: item['Category'] ?? '-',
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.attach_money,
                            label: 'Harga',
                            value: currencyFormat.format(price),
                            color: Color(0xFFF6A918),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.inventory,
                            label: 'Stok',
                            value: _numberFormat.format(stock),
                            color: stock <= 10 ? Colors.orange : Colors.green,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.account_balance_wallet,
                            label: 'Total Nilai',
                            value: currencyFormat.format(totalValue),
                            color: Color(0xFFF6A918),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Detail Section
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Lengkap',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 12),

                          _buildInfoRow('Nama Item', item['Nama'] ?? '-'),
                          _buildInfoRow('Kategori', item['Category'] ?? '-'),
                          _buildInfoRow('Harga', currencyFormat.format(price)),
                          _buildInfoRow('Stok Saat Ini', _numberFormat.format(stock)),
                          _buildInfoRow('Total Nilai Stok', currencyFormat.format(totalValue)),

                          if (hasFoto) ...[
                            Divider(height: 16, color: Colors.grey.shade200),
                            Row(
                              children: [
                                Icon(Icons.image, size: 14, color: Colors.grey.shade600),
                                SizedBox(width: 6),
                                Text(
                                  'Foto tersedia',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openEditItem(item);
                      },
                      icon: Icon(Icons.edit, size: 14),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteItem(item);
                      },
                      icon: Icon(Icons.delete, size: 14),
                      label: Text(
                        'Hapus',
                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return BaseLayout(
      title: 'Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      child: Column(
        children: [
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
                  child: Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 14, color: const Color(0xFFF6A918)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari item...',
                              hintStyle: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey.shade500),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: GoogleFonts.montserrat(fontSize: 11),
                            onChanged: _filterItems,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                            onPressed: () {
                              _searchController.clear();
                              _filterItems('');
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _openAddItem,
                    icon: Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      'Tambah',
                      style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
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
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                : _filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                  SizedBox(height: 12),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Tidak ada data item'
                        : 'Item tidak ditemukan',
                    style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            )
                : Container(
              margin: EdgeInsets.all(isTablet ? 12 : 10),
              decoration: BoxDecoration(
                color: Colors.white,
                // borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    // blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                // borderRadius: BorderRadius.circular(12),
                child: SfDataGrid(
                  controller: _dataGridController,
                  source: _dataSource,
                  allowColumnsResizing: true,
                  columnResizeMode: ColumnResizeMode.onResize,
                  columnWidthMode: ColumnWidthMode.fill,
                  headerRowHeight: 32,
                  rowHeight: 30,
                  allowSorting: true,
                  allowFiltering: true,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  selectionMode: SelectionMode.single,

                  onCellTap: (details) {
                    if (details.rowColumnIndex.rowIndex > 0) {
                      final rowIndex = details.rowColumnIndex.rowIndex - 1;
                      final row = _dataSource.rows[rowIndex];
                      final item = row.getCells().firstWhere(
                              (cell) => cell.columnName == 'aksi'
                      ).value as Map<String, dynamic>;

                      _showItemDetailBottomSheet(item);
                    }
                  },

                  tableSummaryRows: [
                    GridTableSummaryRow(
                      showSummaryInRow: false,
                      title: 'TOTAL',
                      titleColumnSpan: 3,
                      columns: [
                        GridSummaryColumn(
                          name: 'TotalQty',
                          columnName: 'stok',
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

                  // stackedHeaderRows: [
                  //   StackedHeaderRow(
                  //     cells: [
                  //       StackedHeaderCell(
                  //         columnNames: ['no', 'nama', 'category', 'harga', 'stok', 'nilai', 'aksi'],
                  //         child: Container(
                  //           height: 12,
                  //           alignment: Alignment.centerRight,
                  //           padding: const EdgeInsets.only(right: 4),
                  //           // child: Row(
                  //           //   mainAxisAlignment: MainAxisAlignment.end,
                  //           //   children: [
                  //           //     Icon(Icons.filter_list, size: 10, color: Colors.grey[500]),
                  //           //     const SizedBox(width: 2),
                  //           //     Icon(Icons.unfold_more, size: 10, color: Colors.grey[500]),
                  //           //   ],
                  //           // ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],

                  columns: [
                    GridColumn(
                      columnName: 'no',
                      minimumWidth: 80,
                      maximumWidth: 100,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'No',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'nama',
                      minimumWidth: 150,
                      maximumWidth: 250,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Nama Item',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'category',
                      minimumWidth: 100,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Kategori',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'harga',
                      minimumWidth: 100,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Harga',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'stok',
                      minimumWidth: 70,
                      maximumWidth: 90,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Stok',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'nilai',
                      minimumWidth: 100,
                      maximumWidth: 150,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Nilai',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    GridColumn(
                      columnName: 'aksi',
                      minimumWidth: 90,
                      maximumWidth: 100,
                      label: Container(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        alignment: Alignment.center,
                        child: const Text(
                          'Aksi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ItemDataSource extends DataGridSource {
  ItemDataSource({
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
    required NumberFormat formatCurrency,
    required NumberFormat numberFormat,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;
    _formatCurrency = formatCurrency;
    _numberFormat = numberFormat;

    _totalStock = items.fold<int>(0, (sum, item) {
      return sum + (int.tryParse(item['Stok']?.toString() ?? '0') ?? 0);
    });

    _totalNilai = items.fold<double>(0, (sum, item) {
      final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
      return sum + (price * stock);
    });

    _data = items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;

      final name = item['Nama']?.toString() ?? '-';
      final category = item['Category']?.toString() ?? '-';
      final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
      final totalValue = price * stock;

      // Di ItemDataSource
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<String>(columnName: 'category', value: category),
        DataGridCell<String>(columnName: 'harga', value: _formatCurrency.format(price)),
        DataGridCell<int>(columnName: 'stok', value: stock),
        DataGridCell<double>(columnName: 'nilai', value: totalValue),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: item), // item disimpan di sini
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late NumberFormat _formatCurrency;
  late NumberFormat _numberFormat;
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;
  late int _totalStock;
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
          _numberFormat.format(_totalStock),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: Color(0xFFF6A918),
          ),
        ),
      );
    } else if (summaryColumn?.name == 'TotalNilai') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.centerRight,
        child: Text(
          _formatCurrency.format(_totalNilai),
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
        if (cell.columnName == 'aksi') {
          final item = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol edit
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                    onPressed: () => _onEdit(item),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(width: 2),
                // Tombol delete
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                    onPressed: () => _onDelete(item),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'itemData') {
          return const SizedBox.shrink(); // Hidden column
        }

        final isLowStock = cell.columnName == 'stok' &&
            (cell.value is int ? cell.value : 0) <= 10;

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.columnName == 'nilai'
                ? _formatCurrency.format(cell.value)
                : cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: isLowStock
                  ? Colors.orange.shade700
                  : (cell.columnName == 'nilai' || cell.columnName == 'harga'
                  ? const Color(0xFFF6A918)
                  : Colors.black87),
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return TextAlign.right;
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    switch (columnName) {
      case 'harga':
      case 'stok':
      case 'nilai':
        return FontWeight.w600;
      default:
        return FontWeight.normal;
    }
  }
}