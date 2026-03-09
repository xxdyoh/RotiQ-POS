import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:intl/intl.dart';
import '../services/category_service.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];

  final DataGridController _dataGridController = DataGridController();
  late CategoryDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = CategoryDataSource(categories: [], onEdit: _openEditCategory, onDelete: _deleteCategory);
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await CategoryService.getCategories();
      setState(() {
        _categories = categories;
        _dataSource = CategoryDataSource(
          categories: _categories,
          onEdit: _openEditCategory,
          onDelete: _deleteCategory,
        );
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data kategori: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCategories(String query) {
    if (query.isEmpty) {
      _dataSource = CategoryDataSource(
        categories: _categories,
        onEdit: _openEditCategory,
        onDelete: _deleteCategory,
      );
    } else {
      final filtered = _categories.where((category) {
        final name = category['ct_nama']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();

      _dataSource = CategoryDataSource(
        categories: filtered,
        onEdit: _openEditCategory,
        onDelete: _deleteCategory,
      );
    }
    setState(() {});
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
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
            Icon(Icons.check_circle, color: Colors.white, size: 16),
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

  void _openAddCategory() {
    Navigator.pushNamed(
      context,
      AppRoutes.categoryForm,
      arguments: {
        'onSaved': _loadCategories,
      },
    );
  }

  void _openEditCategory(Map<String, dynamic> category) {
    Navigator.pushNamed(
      context,
      AppRoutes.categoryForm,
      arguments: {
        'category': category,
        'onSaved': _loadCategories,
      },
    );
  }

  void _deleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Hapus Kategori?', style: GoogleFonts.montserrat(fontSize: 14)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${category['ct_nama']}"?',
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
              await _performDelete(category);
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

  Future<void> _performDelete(Map<String, dynamic> category) async {
    setState(() => _isLoading = true);
    try {
      final result = await CategoryService.deleteCategory(category['ct_id'].toString());
      if (result['success']) {
        _showSuccessSnackbar(result['message']);
        await _loadCategories();
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getPrinterTypeBadge(String printerName) {
    switch (printerName) {
      case 'DRINK':
        return 'MINUMAN';
      case 'FOOD':
        return 'MAKANAN';
      default:
        return 'LAINNYA';
    }
  }

  Color _getPrinterTypeColor(String printerName) {
    switch (printerName) {
      case 'DRINK':
        return Colors.blue;
      case 'FOOD':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Category',
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
                                  hintText: 'Cari kategori...',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.montserrat(fontSize: 11),
                                onChanged: _filterCategories,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, size: 12, color: Colors.grey.shade500),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterCategories('');
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
                        onPressed: _openAddCategory,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                      'Total: ${_dataSource.rows.length} kategori',
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
                    : _categories.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada data kategori',
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
                              columnNames: [
                                'no', 'nama', 'printer_type', 'discount_percent',
                                'discount_rp', 'is_print', 'aksi'
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
                          columnName: 'nama',
                          minimumWidth: 150,
                          maximumWidth: 200,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Nama Kategori',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'printer_type',
                          minimumWidth: 100,
                          maximumWidth: 120,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Tipe Printer',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'discount_percent',
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
                          columnName: 'discount_rp',
                          minimumWidth: 120,
                          maximumWidth: 150,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Diskon Rp',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        GridColumn(
                          columnName: 'is_print',
                          minimumWidth: 70,
                          maximumWidth: 80,
                          label: Container(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Print',
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

class CategoryDataSource extends DataGridSource {
  CategoryDataSource({
    required List<Map<String, dynamic>> categories,
    required Function(Map<String, dynamic>) onEdit,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    _onEdit = onEdit;
    _onDelete = onDelete;

    _data = categories.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final category = entry.value;

      final name = category['ct_nama']?.toString() ?? '-';
      final printerName = category['ct_PrinterName']?.toString() ?? '-';
      final isPrint = category['ct_isprint'] == 1;
      final discountPercent = double.tryParse(category['ct_disc']?.toString() ?? '0') ?? 0;
      final discountRp = double.tryParse(category['ct_disc_rp']?.toString() ?? '0') ?? 0;

      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'no', value: index),
        DataGridCell<String>(columnName: 'nama', value: name),
        DataGridCell<String>(columnName: 'printer_type', value: _getPrinterTypeBadge(printerName)),
        DataGridCell<double>(columnName: 'discount_percent', value: discountPercent),
        DataGridCell<double>(columnName: 'discount_rp', value: discountRp),
        DataGridCell<bool>(columnName: 'is_print', value: isPrint),
        DataGridCell<Map<String, dynamic>>(columnName: 'aksi', value: category),
      ]);
    }).toList();
  }

  String _getPrinterTypeBadge(String printerName) {
    switch (printerName) {
      case 'DRINK':
        return 'MINUMAN';
      case 'FOOD':
        return 'MAKANAN';
      default:
        return 'LAINNYA';
    }
  }

  List<DataGridRow> _data = [];
  late Function(Map<String, dynamic>) _onEdit;
  late Function(Map<String, dynamic>) _onDelete;

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'aksi') {
          final category = cell.value as Map<String, dynamic>;
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
                    onPressed: () => _onEdit(category),
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
                    onPressed: () => _onDelete(category),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          );
        }

        if (cell.columnName == 'is_print') {
          final isPrint = cell.value == true;
          return Container(
            alignment: Alignment.center,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isPrint ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isPrint ? Colors.green.shade200 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: isPrint
                  ? Icon(Icons.check, size: 10, color: Colors.green.shade700)
                  : null,
            ),
          );
        }

        if (cell.columnName == 'discount_percent') {
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

        if (cell.columnName == 'discount_rp') {
          final value = cell.value as double;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              value > 0 ? formatCurrency.format(value) : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
                color: value > 0 ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          );
        }

        if (cell.columnName == 'printer_type') {
          final printerType = cell.value.toString();
          Color color;
          switch (printerType) {
            case 'MINUMAN':
              color = Colors.blue;
              break;
            case 'MAKANAN':
              color = Colors.green;
              break;
            default:
              color = Colors.grey;
          }

          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Text(
                printerType,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
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
      case 'discount_percent':
      case 'discount_rp':
        return Alignment.centerRight;
      case 'aksi':
      case 'is_print':
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextAlign _getTextAlign(String columnName) {
    switch (columnName) {
      case 'discount_percent':
      case 'discount_rp':
        return TextAlign.right;
      case 'aksi':
      case 'is_print':
        return TextAlign.center;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _getFontWeight(String columnName) {
    return FontWeight.normal;
  }
}