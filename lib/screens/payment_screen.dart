import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../services/session_manager.dart';
import 'package:intl/intl.dart';
import '../services/printer_service.dart';

class PaymentScreen extends StatefulWidget {
  final Customer customer;
  final List<OrderItem> orderItems;

  const PaymentScreen({
    Key? key,
    required this.customer,
    required this.orderItems,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  String _paymentMethod = 'cash';
  final TextEditingController _paidController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isProcessing = false;
  bool _showOrderSummary = false;

  final PrinterService _printerService = PrinterService();
  bool _isThermalPrintAvailable = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  double get _grandTotal => widget.orderItems.fold(0, (sum, item) => sum + item.total);

  double get _paidAmount {
    final text = _paidController.text.replaceAll('.', '').replaceAll(',', '').replaceAll('Rp ', '').trim();
    return double.tryParse(text) ?? 0;
  }

  double get _change {
    if (_paymentMethod == 'transfer') return 0;
    final change = _paidAmount - _grandTotal;
    return change > 0 ? change : 0;
  }

  bool get _isPaymentSufficient {
    if (_paymentMethod == 'transfer') return true;
    return _paidAmount >= _grandTotal;
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _paidController.addListener(_updatePaidAmount);

    if (_paymentMethod == 'transfer') {
      _paidController.text = _grandTotal.toStringAsFixed(0);
    }

    _checkThermalPrinter();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _paidController.removeListener(_updatePaidAmount);
    _paidController.dispose();
    super.dispose();
  }

  void _updatePaidAmount() {
    setState(() {});
  }

  void _addAmount(double amount) {
    final newAmount = _paidAmount + amount;
    _paidController.text = newAmount.toStringAsFixed(0);
  }

  void _setExactAmount() {
    _paidController.text = _grandTotal.toStringAsFixed(0);
  }

  void _clearAmount() {
    _paidController.clear();
  }

  // Numeric keypad input
  void _appendNumber(String number) {
    final currentText = _paidController.text.replaceAll('.', '').replaceAll(',', '').replaceAll('Rp ', '').trim();
    final newText = currentText + number;
    _paidController.text = newText;
  }

  void _deleteLastDigit() {
    final currentText = _paidController.text.replaceAll('.', '').replaceAll(',', '').replaceAll('Rp ', '').trim();
    if (currentText.isNotEmpty) {
      _paidController.text = currentText.substring(0, currentText.length - 1);
    }
  }

  Future<void> _checkThermalPrinter() async {
    await _printerService.initialize();
    setState(() {
      _isThermalPrintAvailable = _printerService.isPrinterReady;
    });
  }

  Future<void> _processPayment() async {
    if (_paymentMethod == 'cash' && _paidAmount < _grandTotal) {
      _showErrorSnackbar('Jumlah pembayaran kurang');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = SessionManager.getCurrentUser();

      final order = Order(
        customer: widget.customer,
        items: widget.orderItems,
        paymentMethod: _paymentMethod,
        paidAmount: _paidAmount,
        userName: currentUser?.name ?? 'ADMIN',
        userId: currentUser?.id ?? '01',
      );

      final result = await ApiService.submitOrder(order);

      if (result['success']) {
        if (mounted) {
          final orderId = result['order_id']?.toString() ?? '';
          await _printThermalReceipt(order, orderId, widget.customer.name);
          _showSuccessDialog(order, orderId);
        }
      } else {
        if (mounted) {
          _showErrorSnackbar(result['message'] ?? 'Gagal menyimpan order');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _printThermalReceipt(Order order, String orderId, String customerName) async {
    try {
      final items = order.items.map((item) {
        return {
          'product_name': item.product.name,
          'quantity': item.quantity,
          'price': item.product.price,
          'total': item.total,
          'discount': item.discountAmount,
          'notes': item.notes,
        };
      }).toList();

      await PrinterService().printReceipt(
        orderId: orderId,
        customerName: customerName,
        items: items,
        grandTotal: order.grandTotal,
        paidAmount: order.paidAmount,
        change: order.change,
        paymentMethod: order.paymentMethod,
        cashierName: order.userName ?? 'ADMIN',
        createdAt: order.createdAt,
      );
    } catch (e) {
      print('Thermal print error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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

  void _showSuccessDialog(Order order, String orderId) {
    final changeAmount = _paidAmount - _grandTotal;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pembayaran Berhasil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order: $orderId',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer: ${widget.customer.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Color(0xFFF6A918).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFF6A918).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Dibayar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
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
              ),
              if (_paymentMethod == 'cash' && changeAmount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kembalian',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        currencyFormat.format(changeAmount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_isThermalPrintAvailable) {
                          _showPrintOptionsDialog(order, orderId);
                        } else {
                          await ReceiptService.printReceipt(order, orderId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF6A918),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isThermalPrintAvailable ? 'Cetak Struk' : 'Print PDF',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            _showShareFormatDialog(order, orderId);
                          },
                          icon: Icon(
                            Icons.share,
                            size: 18,
                            color: Color(0xFFF6A918),
                          ),
                          label: Text(
                            'Share',
                            style: TextStyle(
                              color: Color(0xFFF6A918),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Selesai',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  void _showShareFormatDialog(Order order, String orderId) {
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
                'Pilih Format Struk',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Pilih format file untuk share struk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),
              _buildShareOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF Document',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ReceiptService.shareReceipt(order, orderId, asImage: false);
                  } catch (e) {
                    _showErrorSnackbar('Error: ${e.toString()}');
                  }
                },
              ),
              SizedBox(height: 12),
              _buildShareOption(
                icon: Icons.image,
                title: 'JPG (Gambar)',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ReceiptService.shareReceipt(order, orderId, asImage: true);
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

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    String? subtitle,
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
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12))
            : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Pembayaran',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer & Order Info Card
                  _buildCustomerOrderCard(),
                  SizedBox(height: 16),

                  // Grand Total Card
                  _buildGrandTotalCard(),
                  SizedBox(height: 16),

                  // Payment Method
                  _buildPaymentMethodSection(),
                  SizedBox(height: 16),

                  // Payment Input Section
                  _buildPaymentInputSection(),
                ],
              ),
            ),
          ),

          // Process Button
          _buildProcessButton(),
        ],
      ),
    );
  }

  Widget _buildCustomerOrderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Customer Info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF6A918).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: Color(0xFFF6A918), size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.customer.phone != null && widget.customer.phone != '-')
                        Text(
                          widget.customer.phone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Divider
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Colors.grey[300]),
            ),

            // Order Summary Toggle
            InkWell(
              onTap: () {
                setState(() {
                  _showOrderSummary = !_showOrderSummary;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      '${widget.orderItems.length} items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Spacer(),
                    Text(
                      _showOrderSummary ? 'Tutup' : 'Lihat Detail',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF6A918),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      _showOrderSummary ? Icons.expand_less : Icons.expand_more,
                      color: Color(0xFFF6A918),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Order Items List (Expandable)
            if (_showOrderSummary) ...[
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(12),
                  itemCount: widget.orderItems.length,
                  separatorBuilder: (context, index) => Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = widget.orderItems[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFF6A918).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantity}x',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF6A918),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Text(
                                  item.notes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.total),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrandTotalCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6A918),
            Color(0xFFFFC107),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFF6A918).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Pembayaran',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            currencyFormat.format(_grandTotal),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metode Pembayaran',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodButton(
                'cash',
                'Cash',
                Icons.payments_rounded,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildPaymentMethodButton(
                'transfer',
                'Transfer',
                Icons.account_balance_wallet_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodButton(String method, String label, IconData icon) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _paymentMethod = method;
          if (method == 'transfer') {
            _paidController.text = _grandTotal.toStringAsFixed(0);
          } else {
            _paidController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFF6A918) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFF6A918) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Color(0xFFF6A918).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jumlah Dibayar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),

        // Amount Display
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPaymentSufficient ? Colors.green : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Rp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _paymentMethod == 'cash' ? Color(0xFFF6A918) : Colors.grey,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _paidAmount > 0
                          ? NumberFormat('#,##0', 'id_ID').format(_paidAmount)
                          : '0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _paymentMethod == 'cash' ? Colors.grey[800] : Colors.grey,
                      ),
                    ),
                  ),
                  if (_paymentMethod == 'cash' && _paidAmount > 0)
                    IconButton(
                      icon: Icon(Icons.backspace_outlined, color: Colors.red[400]),
                      onPressed: _clearAmount,
                      tooltip: 'Clear',
                    )
                  else
                    SizedBox(width: 48),
                ],
              ),
              if (_paymentMethod == 'transfer')
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Otomatis sesuai total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Change/Status Display
        if (_paymentMethod == 'cash') ...[
          SizedBox(height: 12),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isPaymentSufficient
                  ? Colors.green[50]
                  : _paidAmount > 0
                  ? Colors.red[50]
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPaymentSufficient
                    ? Colors.green
                    : _paidAmount > 0
                    ? Colors.red
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isPaymentSufficient
                      ? Icons.check_circle
                      : _paidAmount > 0
                      ? Icons.warning
                      : Icons.info_outline,
                  color: _isPaymentSufficient
                      ? Colors.green
                      : _paidAmount > 0
                      ? Colors.red
                      : Colors.grey[600],
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _paidAmount == 0
                        ? 'Masukkan jumlah pembayaran'
                        : _isPaymentSufficient
                        ? 'Kembalian'
                        : 'Kurang Bayar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isPaymentSufficient
                          ? Colors.green[700]
                          : _paidAmount > 0
                          ? Colors.red[700]
                          : Colors.grey[700],
                    ),
                  ),
                ),
                if (_paidAmount > 0)
                  Text(
                    currencyFormat.format((_paidAmount - _grandTotal).abs()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isPaymentSufficient
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Quick Actions for Cash
        if (_paymentMethod == 'cash') ...[
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _setExactAmount,
                  icon: Icon(Icons.check, size: 16),
                  label: Text('Pas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFF6A918),
                    side: BorderSide(color: Color(0xFFF6A918)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearAmount,
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Numeric Keypad
          _buildNumericKeypad(),

          SizedBox(height: 16),

          // Quick Amount Buttons
          Text(
            'Quick Amount',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountChip(10000),
              _buildQuickAmountChip(20000),
              _buildQuickAmountChip(50000),
              _buildQuickAmountChip(100000),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNumericKeypad() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildKeypadButton('000'),
              _buildKeypadButton('0'),
              _buildKeypadButton('⌫', isDelete: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String value, {bool isDelete = false}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Material(
          color: isDelete ? Colors.red[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              if (isDelete) {
                _deleteLastDigit();
              } else {
                _appendNumber(value);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isDelete ? Colors.red[700] : Colors.grey[800],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(double amount) {
    return InkWell(
      onTap: () => _addAmount(amount),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF6A918).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color(0xFFF6A918).withOpacity(0.3),
          ),
        ),
        child: Text(
          '+ ${currencyFormat.format(amount)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF6A918),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Payment Info Summary
            if (_paymentMethod == 'cash' && _paidAmount > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(_grandTotal),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dibayar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          currencyFormat.format(_paidAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_isPaymentSufficient)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kembali',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            currencyFormat.format(_change),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12),
            ],

            // Process Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing || !_isPaymentSufficient ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaymentSufficient ? Color(0xFFF6A918) : Colors.grey[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: _isPaymentSufficient ? 4 : 0,
                  shadowColor: Color(0xFFF6A918).withOpacity(0.4),
                ),
                child: _isProcessing
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 22, color: Colors.white,),
                    SizedBox(width: 12),
                    Text(
                      'Proses Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}