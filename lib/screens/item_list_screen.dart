import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  List<Map<String, dynamic>> _categories = [];

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
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items.where((item) {
        final name = item['Nama']?.toString().toLowerCase() ?? '';
        final category = item['Category']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) ||
            category.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
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
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BaseLayout(
      title: 'Item',
      showBackButton: false,
      showSidebar: !isMobile,
      isFormScreen: false,
      // autoManageSidebar: false,
      // preventBack: true,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Section - COMPACT
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 14, color: Colors.grey.shade500),
                          SizedBox(width: 6),
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
                  SizedBox(width: 10),
                  Container(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: _openAddItem,
                      icon: Icon(Icons.add, size: 14, color: Colors.white),
                      label: Text('Tambah', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF6A918),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary - COMPACT
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_filteredItems.length} item${_filteredItems.length != 1 ? 's' : ''}',
                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  if (_isLoading)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF6A918))),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Items List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
                  : _filteredItems.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                    SizedBox(height: 8),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada data item'
                          : 'Item tidak ditemukan',
                      style: GoogleFonts.montserrat(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              )
                  : Container(
                margin: EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  itemCount: _filteredItems.length,
                  separatorBuilder: (context, index) => SizedBox(height: 6),
                  itemBuilder: (context, index) => _buildItemCard(_filteredItems[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['Nama']?.toString() ?? '-';
    final category = item['Category']?.toString() ?? '-';
    final price = double.tryParse(item['Price']?.toString() ?? '0') ?? 0;
    final stock = int.tryParse(item['Stok']?.toString() ?? '0') ?? 0;
    final isLowStock = stock <= 10;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openEditItem(item),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.inventory_2_outlined, size: 14, color: Colors.green.shade700),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 2),
                      Text(category,
                          style: GoogleFonts.montserrat(fontSize: 9, color: Colors.grey.shade600)),
                      SizedBox(height: 4),
                      Text(currencyFormat.format(price),
                          style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF6A918))),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isLowStock ? Colors.orange.shade200 : Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text('STOK: $stock',
                      style: GoogleFonts.montserrat(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: isLowStock ? Colors.orange.shade700 : Colors.green.shade700,
                      )),
                ),
                SizedBox(width: 6),
                // POPUP MENU DENGAN INKWELL
                PopupMenuButton(
                  itemBuilder: (context) => [
                    // Edit Menu
                    PopupMenuItem(
                      value: 'edit',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.pop(context);
                            _openEditItem(item);
                          },
                          splashColor: Colors.blue.shade100,
                          highlightColor: Colors.blue.shade50.withOpacity(0.3),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Hapus Menu
                    PopupMenuItem(
                      value: 'delete',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            Navigator.pop(context);
                            _deleteItem(item);
                          },
                          splashColor: Colors.red.shade100,
                          highlightColor: Colors.red.shade50.withOpacity(0.3),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(Icons.delete, size: 12, color: Colors.red.shade700),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Hapus',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    // Aksi sudah ditangani di InkWell onTap
                  },
                  icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                  offset: Offset(0, 0),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  elevation: 2,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}