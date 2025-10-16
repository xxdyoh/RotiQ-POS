// history_tab.dart - FILE YANG SUDAH DIPERBAIKI
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../services/printer_service.dart';

class HistoryTab extends StatefulWidget {
  final User? currentUser;
  final NumberFormat currencyFormat;

  const HistoryTab({
    Key? key,
    required this.currentUser,
    required this.currencyFormat,
  }) : super(key: key);

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<Order> _orders = [];
  double _totalSales = 0;
  double _totalCash = 0;
  double _totalTransfer = 0;
  bool _isLoading = false;
  Set<String> _expandedOrders = Set();
  bool _showSalesBreakdown = false;

  final PrinterService _printerService = PrinterService();

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (widget.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getOrdersByDate(
        startDate: _startDate,
        endDate: _endDate,
        userId: widget.currentUser!.name,
      );

      print("===DEBUG");
      print(result['data']);

      if (result['success'] == true) {
        final ordersData = result['data'] as List<dynamic>? ?? [];

        List<Order> orders = ordersData.map<Order>((orderJson) {
          return Order.fromJson(orderJson);
        }).toList();

        setState(() {
          _orders = orders;
          // ✅ PAKAI TOTAL SALES DARI API YANG SUDAH BENAR
          _totalSales = (result['total_sales'] as num?)?.toDouble() ?? 0.0;
        });
      } else {
        final errorMessage = result['message'] as String? ?? 'Gagal memuat data history';
        _showErrorSnackbar(errorMessage);
      }
    } catch (e) {
      print('Error loading orders: $e');
      _showErrorSnackbar('Gagal memuat data history: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Mock data untuk testing - nanti ganti dengan API real
  Future<void> _loadMockData() async {
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _orders = [
        Order(
          id: '001',
          customer: Customer(id: '1', name: 'ASA', phone: '08123456789'),
          items: [
            OrderItem(
              product: Product(id: '1', name: 'Roti Coklat', price: 20000, stock: 10),
              quantity: 2,
              discount: 10,
            ),
            OrderItem(
              product: Product(id: '2', name: 'Roti Keju', price: 25000, stock: 15),
              quantity: 1,
              discount: 0,
            ),
          ],
          paymentMethod: 'cash',
          paidAmount: 61000,
          userName: 'Admin',
          userId: '1',
          createdAt: DateTime.now().subtract(Duration(hours: 2)),
        ),
        Order(
          id: '002',
          customer: Customer(id: '2', name: 'Umum', phone: '-'),
          items: [
            OrderItem(
              product: Product(id: '3', name: 'Roti Coklat', price: 20000, stock: 10),
              quantity: 3,
              discount: 5,
            ),
          ],
          paymentMethod: 'transfer',
          paidAmount: 57000,
          userName: 'Admin',
          userId: '1',
          createdAt: DateTime.now().subtract(Duration(days: 1)),
        ),
      ];
    });
  }

  void _calculateTotalSales() {
    _totalSales = _orders.fold(0, (sum, order) => sum + order.grandTotal);
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

  void _toggleExpand(String orderId) {
    setState(() {
      if (_expandedOrders.contains(orderId)) {
        _expandedOrders.remove(orderId);
      } else {
        _expandedOrders.add(orderId);
      }
    });
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  double get _totalCashSales {
    return _orders.where((order) => order.paymentMethod == 'cash')
        .fold(0.0, (sum, order) => sum + order.grandTotal);
  }

  double get _totalTransferSales {
    return _orders.where((order) => order.paymentMethod == 'transfer')
        .fold(0.0, (sum, order) => sum + order.grandTotal);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // FILTER SECTION
        _buildFilterSection(),

        // TOTAL SALES CARD
        _buildTotalSalesCard(),

        // ORDER LIST
        Expanded(
          child: _isLoading
              ? _buildLoadingIndicator()
              : _orders.isEmpty
              ? _buildEmptyState()
              : _buildOrderList(),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal Mulai',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    GestureDetector(
                      onTap: _selectStartDate,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Color(0xFFF6A918)),
                            SizedBox(width: 8),
                            Text(_dateFormat.format(_startDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal Akhir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    GestureDetector(
                      onTap: _selectEndDate,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Color(0xFFF6A918)),
                            SizedBox(width: 8),
                            Text(_dateFormat.format(_endDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: Icon(Icons.search, size: 18),
            label: Text('CARI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF6A918),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSalesCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          setState(() {
            _showSalesBreakdown = !_showSalesBreakdown;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // HEADER TOTAL SALES
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF6A918).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bar_chart, color: Color(0xFFF6A918), size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Penjualan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_orders.length} Transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.currencyFormat.format(_totalSales),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF6A918),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _showSalesBreakdown ? 'Tutup' : 'Detail',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF6A918),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            _showSalesBreakdown ? Icons.expand_less : Icons.expand_more,
                            color: Color(0xFFF6A918),
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // SALES BREAKDOWN (EXPANDABLE)
              if (_showSalesBreakdown) ...[
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 12),

                // CASH SALES
                _buildSalesBreakdownItem(
                  icon: Icons.payments,
                  title: 'Penjualan Tunai',
                  amount: _totalCashSales,
                  color: Colors.green,
                  count: _orders.where((o) => o.paymentMethod == 'cash').length,
                ),

                SizedBox(height: 12),

                // TRANSFER SALES
                _buildSalesBreakdownItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Penjualan Transfer',
                  amount: _totalTransferSales,
                  color: Colors.blue,
                  count: _orders.where((o) => o.paymentMethod == 'transfer').length,
                ),

                // PERCENTAGE BREAKDOWN
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPercentageItem(
                        'Tunai',
                        _totalCashSales / _totalSales,
                        Colors.green,
                      ),
                      _buildPercentageItem(
                        'Transfer',
                        _totalTransferSales / _totalSales,
                        Colors.blue,
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFF6A918)),
          SizedBox(height: 16),
          Text(
            'Memuat data...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Tidak ada transaksi',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tidak ada transaksi pada periode yang dipilih',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageItem(String label, double percentage, Color color) {
    final percent = (percentage * 100).toStringAsFixed(1);
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final isExpanded = _expandedOrders.contains(order.id);

        return _buildOrderCard(order, isExpanded);
      },
    );
  }

  // history_tab.dart - PERBAIKI _buildOrderCard METHOD
  // history_tab.dart - REDESIGN ORDER CARD
  // history_tab.dart - REDESIGN 2 KOLOM
  Widget _buildOrderCard(Order order, bool isExpanded) {
    double totalDiscount = order.items.fold(0, (sum, item) => sum + item.discountAmount);

    print('=== DEBUG ORDER ${order.id} ===');
    print('From API - global_discount_amount: ${order.globalDiscountAmount}');
    print('From API - global_discount: ${order.globalDiscount}%');
    print('From API - subtotal_before_discount: ${order.subtotalBeforeDiscount}');
    print('From API - grand_total: ${order.grandTotal}');

    // Hitung ulang di Flutter untuk compare
    final calculatedDiscount = order.subtotalBeforeDiscount * (order.globalDiscount / 100);
    print('Calculated in Flutter: $calculatedDiscount');
    print('Difference: ${order.globalDiscountAmount - calculatedDiscount}');

    // Format tanggal
    String formatDate(DateTime date) {
      return DateFormat('dd MMM yy • HH:mm').format(date);
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _toggleExpand(order.id!),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ HEADER 2 KOLOM
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KOLOM KIRI - ID & TANGGAL
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ORDER ID
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFF6A918).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${order.id}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6A918),
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        // TANGGAL & ITEM COUNT
                        Text(
                          formatDate(order.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        // SizedBox(height: 2),
                        // Text(
                        //   '${order.items.length} items • ${order.items.fold(0, (sum, item) => sum + item.quantity)} pcs',
                        //   style: TextStyle(
                        //     fontSize: 12,
                        //     color: Colors.grey[600],
                        //   ),
                        // ),
                      ],
                    ),
                  ),

                  SizedBox(width: 12),

                  // KOLOM KANAN - HARGA & PAYMENT METHOD
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // TOTAL HARGA
                      Text(
                        widget.currencyFormat.format(order.grandTotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF6A918),
                        ),
                      ),
                      SizedBox(height: 6),
                      // PAYMENT METHOD
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.paymentMethod == 'cash'
                              ? Colors.green[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: order.paymentMethod == 'cash'
                                ? Colors.green[100]!
                                : Colors.blue[100]!,
                          ),
                        ),
                        child: Text(
                          order.paymentMethod == 'cash' ? 'TUNAI' : 'TRANSFER',
                          style: TextStyle(
                            fontSize: 10,
                            color: order.paymentMethod == 'cash'
                                ? Colors.green[700]
                                : Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(width: 8),

                  // EXPAND ICON
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Color(0xFFF6A918),
                    size: 20,
                  ),
                ],
              ),

              // EXPANDED CONTENT - SAMA SEPERTI SEBELUMNYA
              if (isExpanded) ...[
                SizedBox(height: 16),
                Divider(color: Colors.grey[300]),
                SizedBox(height: 12),

                // CUSTOMER INFO
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Customer:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customer.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // ORDER ITEMS
                ...order.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final hasDiscount = item.discount > 0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(0xFFF6A918).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF6A918),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (hasDiscount) ...[
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      widget.currencyFormat.format(item.subtotal),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Disc ${item.discount}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'x${item.quantity}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          widget.currencyFormat.format(item.total),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF6A918),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // DISCOUNT SUMMARY

                if (totalDiscount > 0) ...[
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Diskon Item',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '-${widget.currencyFormat.format(totalDiscount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                if (order.globalDiscountAmount  > 0) ...[
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Diskon ${order.globalDiscount}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '-${widget.currencyFormat.format(order.globalDiscountAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                // ACTION BUTTONS
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printReceipt(order),
                        icon: Icon(Icons.print, size: 18, color: Colors.white),
                        label: Text('Print Struk', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF6A918),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareReceipt(order),
                        icon: Icon(Icons.share, size: 18, color: Colors.white),
                        label: Text('Share', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesBreakdownItem({
    required IconData icon,
    required String title,
    required double amount,
    required Color color,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count transaksi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Text(
          widget.currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _printReceipt(Order order) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // ✅ INISIALISASI PRINTER SERVICE
      await _printerService.initialize();
      final isThermalAvailable = _printerService.isPrinterReady;

      if (isThermalAvailable) {
        // Thermal printer available - show options
        _showPrintOptionsDialog(order, order.id!);
      } else {
        // Thermal printer not available - langsung PDF
        await ReceiptService.printReceipt(order, order.id!);
        _showSuccessSnackbar('Struk PDF berhasil dibuat');
      }
    } catch (e) {
      print('Print error: $e');
      _showErrorSnackbar('Gagal print struk: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPrintOptionsDialog(Order order, String orderId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Pilih Metode Print',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pilih cara mencetak struk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),

              // THERMAL PRINT OPTION
              _buildPrintOption(
                icon: Icons.receipt_long,
                title: 'Print Thermal',
                subtitle: 'Cetak langsung ke printer thermal',
                color: Color(0xFFF6A918),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final success = await ReceiptService.printThermalReceipt(order, orderId);
                    if (success) {
                      _showSuccessSnackbar('Struk berhasil dicetak ke thermal printer');
                    } else {
                      _showErrorSnackbar('Gagal mencetak ke thermal printer');
                    }
                  } catch (e) {
                    _showErrorSnackbar('Error: ${e.toString()}');
                  }
                },
              ),
              SizedBox(height: 12),

              // PDF PRINT OPTION
              _buildPrintOption(
                icon: Icons.picture_as_pdf,
                title: 'Print PDF',
                subtitle: 'Cetak sebagai dokumen PDF',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ReceiptService.printReceipt(order, orderId);
                    _showSuccessSnackbar('Struk PDF berhasil dibuat');
                  } catch (e) {
                    _showErrorSnackbar('Error: ${e.toString()}');
                  }
                },
              ),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _shareReceipt(Order order) async {
    try {
      // Share sebagai image (WhatsApp friendly)
      await ReceiptService.shareReceipt(order, order.id!, asImage: true);
    } catch (e) {
      _showErrorSnackbar('Gagal share struk: ${e.toString()}');
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
}