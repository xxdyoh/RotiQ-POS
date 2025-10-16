import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'customer_select_screen.dart';
import 'product_select_screen.dart';
import 'payment_screen.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import 'printer_settings_screen.dart';
import 'history_tab.dart';
import '../services/cache_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Customer? _selectedCustomer;
  final List<OrderItem> _orderItems = [];
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  double get _grandTotal => _orderItems.fold(0, (sum, item) => sum + item.total);

  late TabController _tabController;

  // Hardcode customer list
  final List<Customer> _customers = [
    Customer(id: 'Umum', name: 'Umum', phone: '-'),
    Customer(id: 'ASA', name: 'ASA', phone: '-'),
    Customer(id: 'BSM', name: 'BSM', phone: '-'),
    Customer(id: 'N3 Plesungan', name: 'N3 Plesungan', phone: '-'),
    Customer(id: 'N3 HF', name: 'N3 HF', phone: '-'),
    Customer(id: 'ROTIQ', name: 'ROTIQ', phone: '-'),
    Customer(id: 'ROSO TRESNO', name: 'ROSO TRESNO', phone: '-'),
    Customer(id: 'RESERVASI', name: 'RESERVASI', phone: '-'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setDefaultCustomer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDefaultCustomer() {
    final defaultCustomer = _customers.firstWhere(
          (customer) => customer.name == 'Umum',
      orElse: () => _customers.first,
    );
    setState(() {
      _selectedCustomer = defaultCustomer;
    });
  }

  void _showCustomerDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Color(0xFFF6A918)),
                  SizedBox(width: 8),
                  Text(
                    'Pilih Customer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _customers.length,
                itemBuilder: (context, index) {
                  final customer = _customers[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFFF6A918).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFFF6A918),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: customer.phone != '-'
                        ? Text(customer.phone!)
                        : null,
                    trailing: _selectedCustomer?.id == customer.id
                        ? Icon(Icons.check, color: Color(0xFFF6A918))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCustomer = customer;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addProduct() async {
    final selectedProducts = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(builder: (context) => const ProductSelectScreen()),
    );

    if (selectedProducts != null && selectedProducts.isNotEmpty) {
      _addMultipleProductsToOrder(selectedProducts);
    }
  }

  void _addMultipleProductsToOrder(Map<String, int> productQuantities) async {
    try {
      // GUNAKAN METHOD OPTIMIZED (tanpa gambar) atau ambil dari cache
      final allProducts = await ApiService.getProductsOptimized(); // <- PAKAI INI

      setState(() {
        int addedCount = 0;

        productQuantities.forEach((productId, quantity) {
          if (quantity > 0) {
            final product = allProducts.firstWhere(
                  (p) => p.id == productId,
              orElse: () => Product(
                id: productId,
                name: 'Unknown',
                price: 0,
                stock: 0,
                category: '',
              ),
            );

            if (product.name == 'Unknown') {
              _showErrorSnackbar('Item tidak ditemukan');
              return;
            }

            if (quantity > product.stock) {
              _showErrorSnackbar('${product.name} melebihi stock (${product.stock})');
              return;
            }

            final existingIndex = _orderItems.indexWhere((item) => item.product.id == productId);

            if (existingIndex >= 0) {
              final newQuantity = _orderItems[existingIndex].quantity + quantity;
              if (newQuantity <= product.stock) {
                _orderItems[existingIndex].quantity = newQuantity;
                addedCount++;
              } else {
                _showErrorSnackbar('${product.name} melebihi stock tersedia');
              }
            } else {
              _orderItems.add(OrderItem(
                product: product,
                quantity: quantity,
                discount: product.discount ?? 0,
                notes: '',
              ));
              addedCount++;
            }
          }
        });

        if (addedCount > 0) {
          _showSuccessSnackbar('$addedCount item berhasil ditambahkan');
        } else {
          _showErrorSnackbar('Tidak ada item yang berhasil ditambahkan');
        }
      });
    } catch (e) {
      _showErrorSnackbar('Gagal memuat data item: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _openPrinterSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
    );
  }

  void _editOrderItem(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditOrderItemSheet(
        orderItem: _orderItems[index],
        onSave: (updatedItem) {
          setState(() {
            _orderItems[index] = updatedItem;
          });
        },
        onDelete: () {
          setState(() {
            _orderItems.removeAt(index);
          });
        },
      ),
    );
  }

  void _clearCache() async {
    try {
      await CacheService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Cache berhasil dihapus'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }

      print('🧹 Cache cleared from HomeScreen');
    } catch (e) {
      print('❌ Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Gagal menghapus cache'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _proceedToPayment() {
    if (_selectedCustomer == null) {
      _showErrorSnackbar('Pilih customer terlebih dahulu');
      return;
    }

    if (_orderItems.isEmpty) {
      _showErrorSnackbar('Tambahkan item terlebih dahulu');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          customer: _selectedCustomer!,
          orderItems: _orderItems,
        ),
      ),
    ).then((_) {
      setState(() {
        _orderItems.clear();
      });
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Order?'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus semua data order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // ✅ JANGAN RESET CUSTOMER, TETAP DEFAULT KE "UMUM"
                // _selectedCustomer = null; // HAPUS BARIS INI
                _orderItems.clear();
              });
              Navigator.pop(context);
              _showSuccessSnackbar('Order berhasil direset');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SessionManager.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = SessionManager.getCurrentUser();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'RotiQ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFFC107),
                Color(0xFFFFD54F),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Tab(
              icon: Icon(Icons.shopping_cart, size: 20),
              text: 'ORDER',
            ),
            Tab(
              icon: Icon(Icons.history, size: 20),
              text: 'HISTORY',
            ),
          ],
        ),
        actions: [
          if (currentUser != null)
            PopupMenuButton<String>(
              icon: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 6),
                  Text(
                    _getShortName(currentUser.name),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'printer_settings') {
                  _openPrinterSettings();
                } else if (value == 'clear_cache') { // <-- TAMBAH INI
                  _clearCache();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'user',
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in as',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        currentUser.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'printer_settings',
                  child: Row(
                    children: [
                      Icon(Icons.print, color: Color(0xFFF6A918), size: 20),
                      SizedBox(width: 8),
                      Text('Printer Settings', style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem<String>( // <-- TAMBAH MENU CLEAR CACHE
                  value: 'clear_cache',
                  child: Row(
                    children: [
                      Icon(Icons.cached, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Clear Cache', style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),

          if (_orderItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.white),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ORDER AKTIF (EXISTING)
          _buildOrderActiveTab(),

          // TAB 2: HISTORY (NEW)
          HistoryTab(
            currentUser: currentUser,
            currencyFormat: currencyFormat,
          ),
        ],
      ),
    );
  }

  String _getShortName(String fullName) {
    final names = fullName.split(' ');
    if (names.length == 1) return fullName;
    return '${names[0]} ${names[1][0]}.';
  }

  Widget _buildCustomerSection() {
    return GestureDetector(
      onTap: _showCustomerDropdown,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedCustomer == null ? Colors.grey[50] : Color(0xFFE8F5E8),
          border: Border.all(
            color: _selectedCustomer == null ? Colors.grey[300]! : Colors.green,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              color: _selectedCustomer == null ? Colors.grey : Colors.green,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCustomer == null ? 'Pilih Customer' : _selectedCustomer!.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _selectedCustomer == null ? Colors.grey : Colors.black87,
                    ),
                  ),
                  if (_selectedCustomer?.phone != null && _selectedCustomer?.phone != '-')
                    Text(
                      _selectedCustomer!.phone!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: _selectedCustomer == null ? Colors.grey : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Row(
      children: [
        _buildSummaryItem(
          icon: Icons.shopping_basket,
          value: _orderItems.length.toString(),
          label: 'Items',
          color: Colors.blue,
        ),
        SizedBox(width: 16),
        _buildSummaryItem(
          icon: Icons.payments,
          value: currencyFormat.format(_grandTotal),
          label: 'Total',
          color: Color(0xFFF6A918),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  Widget _buildOrderActiveTab() {
    return Column(
      children: [
        // EXISTING CUSTOMER SECTION & ORDER LIST
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildCustomerSection(),
            ],
          ),
        ),
        Expanded(
          child: _orderItems.isEmpty
              ? _buildEmptyState()
              : _buildOrderList(),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Belum ada item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap tombol "Tambah Item" untuk memulai order',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                'Daftar Item (${_orderItems.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _orderItems.length,
            itemBuilder: (context, index) {
              final item = _orderItems[index];
              return _buildOrderItem(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(OrderItem item, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editOrderItem(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF6A918),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    currencyFormat.format(item.total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF6A918),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${currencyFormat.format(item.product.price)} × ${item.quantity}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  if (item.discount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.discount, size: 12, color: Colors.red),
                          SizedBox(width: 2),
                          Text(
                            'Disc ${item.discount}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (item.notes.isNotEmpty) ...[
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.blue),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.notes,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalItems = _orderItems.fold(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
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
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      currencyFormat.format(_grandTotal),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF6A918),
                      ),
                    ),
                  ],
                ),
                if (_orderItems.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_orderItems.length} items • $totalItems pcs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF6A918),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addProduct,
                    icon: Icon(Icons.add, size: 20),
                    label: Text('Tambah Item'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      side: BorderSide(color: Color(0xFFF6A918)),
                      foregroundColor: Color(0xFFF6A918),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _proceedToPayment,
                    icon: Icon(Icons.payment, size: 20, color: Colors.white,),
                    label: Text('Bayar'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      backgroundColor: Color(0xFFF6A918),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderItemSheet extends StatefulWidget {
  final OrderItem orderItem;
  final Function(OrderItem) onSave;
  final VoidCallback onDelete;

  const _EditOrderItemSheet({
    required this.orderItem,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditOrderItemSheet> createState() => _EditOrderItemSheetState();
}

class _EditOrderItemSheetState extends State<_EditOrderItemSheet> {
  late int _quantity;
  late double _discount;
  late TextEditingController _notesController;
  late TextEditingController _quantityController;
  late TextEditingController _discountController;
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _quantity = widget.orderItem.quantity;
    _discount = widget.orderItem.discount;
    _notesController = TextEditingController(text: widget.orderItem.notes);
    _quantityController = TextEditingController(text: _quantity.toString());
    _discountController = TextEditingController(text: _discount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _total {
    final subtotal = widget.orderItem.product.price * _quantity;
    return subtotal - (subtotal * _discount / 100);
  }

  void _updateQuantity(String value) {
    if (value.isEmpty) {
      setState(() {
        _quantity = 0;
        _quantityController.text = '0';
        _quantityController.selection = TextSelection.collapsed(offset: 1);
      });
      return;
    }

    final newQuantity = int.tryParse(value) ?? 0;
    if (newQuantity > widget.orderItem.product.stock) {
      _showStockWarning();
      setState(() {
        _quantity = widget.orderItem.product.stock;
        _quantityController.text = widget.orderItem.product.stock.toString();
        _quantityController.selection = TextSelection.collapsed(
          offset: _quantityController.text.length,
        );
      });
    } else if (newQuantity < 1) {
      setState(() {
        _quantity = 1;
        _quantityController.text = '1';
        _quantityController.selection = TextSelection.collapsed(offset: 1);
      });
    } else {
      setState(() {
        _quantity = newQuantity;
      });
    }
  }

  void _updateDiscount(String value) {
    if (value.isEmpty) {
      setState(() {
        _discount = 0;
        _discountController.text = '0';
        _discountController.selection = TextSelection.collapsed(offset: 1);
      });
      return;
    }

    final newDiscount = double.tryParse(value) ?? 0;
    if (newDiscount > 100) {
      setState(() {
        _discount = 100;
        _discountController.text = '100';
        _discountController.selection = TextSelection.collapsed(
          offset: _discountController.text.length,
        );
      });
    } else if (newDiscount < 0) {
      setState(() {
        _discount = 0;
        _discountController.text = '0';
        _discountController.selection = TextSelection.collapsed(offset: 1);
      });
    } else {
      setState(() {
        _discount = newDiscount;
        _discountController.text = newDiscount.toStringAsFixed(0);
        _discountController.selection = TextSelection.collapsed(
          offset: _discountController.text.length,
        );
      });
    }
  }

  void _showStockWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Quantity melebihi stock tersedia. Diatur ke maksimum stock.'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (_quantity > 1) {
                  setState(() {
                    _quantity--;
                    _quantityController.text = _quantity.toString();
                  });
                }
              },
              icon: Icon(Icons.remove_circle_outline, size: 28),
              color: _quantity > 1 ? Color(0xFFF6A918) : Colors.grey,
            ),
            Expanded(
              child: Container(
                height: 50,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFF6A918)),
                    ),
                    hintText: 'Qty',
                  ),
                  onChanged: _updateQuantity,
                  onTap: () {
                    _quantityController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _quantityController.text.length,
                    );
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                if (_quantity < widget.orderItem.product.stock) {
                  setState(() {
                    _quantity++;
                    _quantityController.text = _quantity.toString();
                  });
                } else {
                  _showStockWarning();
                }
              },
              icon: Icon(Icons.add_circle_outline, size: 28),
              color: _quantity < widget.orderItem.product.stock ? Color(0xFFF6A918) : Colors.grey,
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Stock Tersedia',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${widget.orderItem.product.stock}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF6A918),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Klik field quantity untuk edit manual, atau gunakan tombol +/-',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Diskon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_discount.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 50,
          child: TextField(
            controller: _discountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.percent, color: Colors.grey[600]),
              hintText: 'Masukkan diskon (0-100)%',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFF6A918)),
              ),
            ),
            onChanged: _updateDiscount,
            onTap: () {
              _discountController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _discountController.text.length,
              );
            },
          ),
        ),
        SizedBox(height: 12),
        Slider(
          value: _discount,
          min: 0,
          max: 100,
          divisions: 100,
          label: '${_discount.toStringAsFixed(0)}%',
          activeColor: Color(0xFFF6A918),
          inactiveColor: Colors.grey[300],
          onChanged: (value) {
            setState(() {
              _discount = value;
              _discountController.text = value.toStringAsFixed(0);
            });
          },
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [0, 25, 50, 75, 100]
              .map((value) => GestureDetector(
            onTap: () {
              setState(() {
                _discount = value.toDouble();
                _discountController.text = value.toString();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: value == _discount ? Color(0xFFF6A918) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value == _discount ? Color(0xFFF6A918) : Colors.grey[300]!,
                ),
              ),
              child: Text(
                '$value%',
                style: TextStyle(
                  fontSize: 12,
                  color: value == _discount ? Colors.white : Colors.grey[600],
                  fontWeight: value == _discount ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ))
              .toList(),
        ),
        SizedBox(height: 8),
        Text(
          'Ketik langsung atau gunakan slider untuk mengatur diskon',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Item',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                widget.orderItem.product.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                currencyFormat.format(widget.orderItem.product.price),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              _buildQuantitySection(),
              SizedBox(height: 24),
              _buildDiscountSection(),
              SizedBox(height: 24),
              _buildNotesSection(),
              SizedBox(height: 24),
              _buildTotalPreview(),
              SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tambahkan catatan (opsional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFF6A918)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalPreview() {
    final subtotal = widget.orderItem.product.price * _quantity;
    final discountAmount = subtotal * _discount / 100;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF6A918).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFF6A918).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: TextStyle(color: Colors.grey[600])),
              Text(currencyFormat.format(subtotal), style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          if (_discount > 0) ...[
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Diskon (${_discount.toStringAsFixed(0)}%)', style: TextStyle(color: Colors.grey[600])),
                Text('-${currencyFormat.format(discountAmount)}',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          SizedBox(height: 8),
          Divider(),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                currencyFormat.format(_total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF6A918),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            icon: Icon(Icons.delete_outline, size: 20),
            label: Text('Hapus'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              final updatedItem = OrderItem(
                product: widget.orderItem.product,
                quantity: _quantity,
                discount: _discount,
                notes: _notesController.text,
              );
              widget.onSave(updatedItem);
              Navigator.pop(context);
            },
            icon: Icon(Icons.check, size: 20),
            label: Text('Simpan Perubahan'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Color(0xFFF6A918),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}