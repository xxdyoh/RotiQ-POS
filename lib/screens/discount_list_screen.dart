import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:intl/intl.dart';
import '../services/discount_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';

class DiscountListScreen extends StatefulWidget {
  const DiscountListScreen({super.key});

  @override
  State<DiscountListScreen> createState() => _DiscountListScreenState();
}

class _DiscountListScreenState extends State<DiscountListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _discounts = [];

  final DataGridController _dataGridController = DataGridController();
  late DiscountDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = DiscountDataSource(discounts: [], onEdit: _openEditDiscount, onDelete: _deleteDiscount);
    _loadDiscounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscounts() async {
    setState(() => _isLoading = true);
    try {
      final discounts = await DiscountService.getDiscounts();
      setState(() {
        _discounts = discounts;
        _dataSource = DiscountDataSource(
          discounts: _discounts,
          onEdit: _openEditDiscount,
          onDelete: _deleteDiscount,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data discount: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterDiscounts(String query) {
    if (query.isEmpty) {
      _dataSource = DiscountDataSource(
        discounts: _discounts,
        onEdit: _openEditDiscount,
        onDelete: _deleteDiscount,
      );
    } else {
      final filtered = _discounts.where((discount) {
        final name = discount['disc_nama']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();

      _dataSource = DiscountDataSource(
        discounts: filtered,
        onEdit: _openEditDiscount,
        onDelete: _deleteDiscount,
      );
    }
    setState(() {});
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _openAddDiscount() {
    Navigator.pushNamed(
      context,
      AppRoutes.discountForm,
      arguments: {
        'onSaved': _loadDiscounts,
      },
    );
  }

  void _openEditDiscount(Map<String, dynamic> discount) {
    Navigator.pushNamed(
      context,
      AppRoutes.discountForm,
      arguments: {
        'discount': discount,
        'onSaved': _loadDiscounts,
      },
    );
  }

  void _deleteDiscount(Map<String, dynamic> discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Discount?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${discount['disc_nama']}"?',
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(discount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performDelete(Map<String, dynamic> discount) async {
    setState(() => _isLoading = true);
    try {
      final result = await DiscountService.deleteDiscount(discount['disc_id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadDiscounts();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Discount',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;

          return Column(
            children: [
              // ========== SEARCH SECTION ==========
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
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
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari discount...',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterDiscounts,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterDiscounts('');
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _openAddDiscount,
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: Text(
                          'Tambah',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6A918),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== SUMMARY ==========
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_dataSource.rows.length} discount${_dataSource.rows.length != 1 ? 's' : ''}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF6A918),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ========== DATA GRID ==========
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                    : _discounts.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.discount_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada data discount',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : Container(
                  margin: const EdgeInsets.all(12),
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

                      stackedHeaderRows: [
                        StackedHeaderRow(
                          cells: [
                            StackedHeaderCell(
                              columnNames: ['no', 'id', 'nama', 'percentage', 'aksi'],
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
                          columnName: 'id',
                          minimumWidth: 60,
                          maximumWidth: 80,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'ID',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'nama',
                          minimumWidth: 200,
                          maximumWidth: 250,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nama Discount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'percentage',
                          minimumWidth: 90,
                          maximumWidth: 110,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Diskon %',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'aksi',
                          minimumWidth: 80,
                          maximumWidth: 90,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.center,
                            child: const Text(
                              'Aksi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DiscountDataSource extends DataGridSource {
  DiscountDataSource({
    required List<Map<String, dynamic>> discounts,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;

    _data = discounts.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final discount = entry.value;

      final id = discount['disc_id']?.toString() ?? '-';
      final name = discount['disc_nama']?.toString() ?? '-';
      final percentage = double.tryParse(discount['disc_persen']?.toString() ?? '0') ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'id', value: id),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<double>(columnName: 'percentage', value: percentage),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: discount),
      ]);
    }).toList();
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'aksi') {
          final discount = cell.value as Map<String, dynamic>;
          return Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol Edit
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                    onPressed: () => _onEdit(discount),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 2),
                // Tombol Delete
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                    onPressed: () => _onDelete(discount),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'percentage') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              value > 0 ? '${value.toStringAsFixed(0)}%' : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
                color: value > 0 ? const Color(0xFFF6A918) : Colors.black87,
              ),
            ),
          );
        }

        return Container(
          alignment: _getAlignment(cell.columnName),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            cell.value.toString(),
            textAlign: _getTextAlign(cell.columnName),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: _getFontWeight(cell.columnName),
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Alignment _getAlignment(String columnName) {
    switch (columnName) {
      case 'percentage':
        return Alignment.centerRight;
      case 'aksi':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'percentage':
        return TextAlign.right;
      case 'aksi':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    return FontWeight.normal;
  }
}