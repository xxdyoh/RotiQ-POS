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

  double _orderDiscount = 0.0;
  final TextEditingController _discountController = TextEditingController();

  final PrinterService _printerService = PrinterService();
  bool _isThermalPrintAvailable = false;

  bool _isSharing = false;
  bool _isPrinting = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  double _roundToNearest(double value) {
    return (value).roundToDouble();
  }

  double get _subtotal {
    final raw = widget.orderItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    return _roundToNearest(raw);
  }

  double get _itemDiscounts {
    final raw = widget.orderItems.fold(0.0, (sum, item) => sum + item.discountAmount);
    return _roundToNearest(raw);
  }

  double get _totalAfterItemDiscounts => _roundToNearest(_subtotal - _itemDiscounts);

  double get _orderDiscountAmount => _roundToNearest(_totalAfterItemDiscounts * (_orderDiscount / 100));

  double get _grandTotal => _roundToNearest(_totalAfterItemDiscounts - _orderDiscountAmount);

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
    _discountController.dispose(); // ✅ DISPOSE DISCOUNT CONTROLLER
    super.dispose();
  }

  void _updatePaidAmount() {
    setState(() {});
  }

  // GANTI METHOD _showOrderDiscountDialog dengan ini:
  void _showOrderDiscountDialog() {
    final discountController = TextEditingController(text: _orderDiscount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.discount, color: Color(0xFFF6A918)),
            SizedBox(width: 8),
            Text('Diskon Faktur'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masukkan persentase diskon'),
            SizedBox(height: 16),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Diskon (%)',
                hintText: '0 - 100',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                final newDiscount = double.tryParse(value) ?? 0;
                setState(() {
                  _orderDiscount = newDiscount.clamp(0, 100).toDouble();
                });
              },
            ),
            SizedBox(height: 12),
            // Quick percentage buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 5, 10, 15, 20, 25, 50]
                  .map((value) => ActionChip(
                label: Text('$value%'),
                backgroundColor: value == _orderDiscount
                    ? Color(0xFFF6A918)
                    : Colors.grey[200],
                labelStyle: TextStyle(
                  color: value == _orderDiscount ? Colors.white : Colors.grey[700],
                  fontWeight: value == _orderDiscount ? FontWeight.bold : FontWeight.normal,
                ),
                onPressed: () {
                  setState(() {
                    _orderDiscount = value.toDouble();
                  });
                  discountController.text = value.toString();
                },
              ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF6A918),
            ),
            child: Text('Simpan'),
          ),
        ],
      ),
    );
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

      // ✅ DEBUG: CEK NILAI SEBELUM BUAT ORDER
      print('DEBUG - Grand Total: $_grandTotal');
      print('DEBUG - Paid Amount: $_paidAmount');
      print('DEBUG - Payment Method: $_paymentMethod');

      // ✅ PASTIKAN PAID AMOUNT BENAR
      final paidAmount = _paymentMethod == 'transfer' ? _grandTotal : _paidAmount;

      final order = Order(
        customer: widget.customer,
        items: widget.orderItems,
        paymentMethod: _paymentMethod,
        paidAmount: paidAmount, // ✅ GUNAKAN VARIABLE YANG SUDAH DICEK
        userName: currentUser?.name ?? 'ADMIN',
        userId: currentUser?.id ?? '01',
        globalDiscount: _orderDiscount,
      );

      // ✅ DEBUG: CEK ORDER OBJECT
      print('DEBUG - Order Paid Amount: ${order.paidAmount}');
      print('DEBUG - Order Grand Total: ${order.grandTotal}');

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
          'total': item.total, // ✅ 5810 (bukan 7000)
          'discount': item.discountAmount,
        };
      }).toList();

      // ✅ SUBTOTAL = TOTAL SETELAH DISKON ITEM
      final subtotal = _totalAfterItemDiscounts; // dari getter di payment_screen
      final orderDiscountAmount = _orderDiscountAmount; // diskon global
      final grandTotal = _grandTotal;

      await PrinterService().printReceipt(
        orderId: orderId,
        customerName: customerName,
        items: items,
        subtotal: subtotal, // ✅ SUDAH SETELAH DISKON ITEM
        orderDiscountAmount: orderDiscountAmount, // diskon global
        grandTotal: grandTotal,
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

    final actualPaidAmount = _paymentMethod == 'transfer' ? _grandTotal : _paidAmount;
    final actualChange = _paymentMethod == 'cash' ? (_paidAmount - _grandTotal) : 0;

    print('DEBUG Success Dialog - Paid: $actualPaidAmount, Change: $actualChange');

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
                      currencyFormat.format(actualPaidAmount),
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
                        currencyFormat.format(actualChange),
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
                          Icon(Icons.print, size: 18, color: Colors.white,),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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

                  // PDF Option dengan loading state
                  _buildShareOption(
                    icon: Icons.picture_as_pdf,
                    title: 'PDF Document',
                    color: Colors.red,
                    isLoading: _isSharing,
                    onTap: () async {
                      if (_isSharing) return; // ✅ JIKA SEDANG LOADING, JANGAN EXECUTE

                      setModalState(() {
                        _isSharing = true;
                      });

                      try {
                        await ReceiptService.shareReceipt(order, orderId, asImage: false);
                      } catch (e) {
                        _showErrorSnackbar('Error: ${e.toString()}');
                      } finally {
                        if (mounted) {
                          setModalState(() {
                            _isSharing = false;
                          });
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),

                  SizedBox(height: 12),

                  // JPG Option dengan loading state
                  _buildShareOption(
                    icon: Icons.image,
                    title: 'JPG (Gambar)',
                    color: Colors.blue,
                    isLoading: _isSharing,
                    onTap: () async {
                      if (_isSharing) return; // ✅ JIKA SEDANG LOADING, JANGAN EXECUTE

                      setModalState(() {
                        _isSharing = true;
                      });

                      try {
                        await ReceiptService.shareReceipt(order, orderId, asImage: true);
                      } catch (e) {
                        _showErrorSnackbar('Error: ${e.toString()}');
                      } finally {
                        if (mounted) {
                          setModalState(() {
                            _isSharing = false;
                          });
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),

                  SizedBox(height: 16),

                  // Loading indicator ketika sedang proses
                  if (_isSharing) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Mempersiapkan file...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  OutlinedButton(
                    onPressed: _isSharing ? null : () => Navigator.pop(context), // ✅ DISABLE JIKA LOADING
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
          );
        },
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required bool isLoading, // ✅ TAMBAH PARAMETER LOADING
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
          child: isLoading
              ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
              : Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12))
            : null,
        trailing: isLoading
            ? SizedBox(width: 24, height: 24)
            : Icon(Icons.chevron_right, color: Colors.grey),
        onTap: isLoading ? null : onTap, // ✅ DISABLE TAP JIKA LOADING
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

                  // ✅ TAMBAH CARD DISKON ORDER
                  _buildOrderDiscountCard(),
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

  // GANTI _buildOrderDiscountCard dengan ini:
  Widget _buildOrderDiscountCard() {
    final discountController = TextEditingController();
    bool isExpanded = false;
    double tempDiscount = 0.0; // ✅ STATE SEMENTARA

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Header yang bisa di-tap
                InkWell(
                  onTap: () {
                    setLocalState(() {
                      isExpanded = !isExpanded;
                      if (isExpanded) {
                        // ✅ INIT DENGAN NILAI SEKARANG, BUKAN TEMP
                        discountController.text = _orderDiscount.toStringAsFixed(0);
                        tempDiscount = _orderDiscount; // ✅ SYNC TEMP DENGAN NILAI SEKARANG
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _orderDiscount > 0 ? Colors.orange[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.discount,
                          color: _orderDiscount > 0 ? Colors.orange : Colors.grey[600],
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diskon',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_orderDiscount > 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    '${_orderDiscount.toStringAsFixed(0)}% dari ${currencyFormat.format(_totalAfterItemDiscounts)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '= ${currencyFormat.format(_orderDiscountAmount)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Ketuk untuk tambah diskon',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Color(0xFFF6A918),
                      ),
                    ],
                  ),
                ),

                // Input Section (Expandable)
                if (isExpanded) ...[
                  SizedBox(height: 16),
                  Divider(height: 1),
                  SizedBox(height: 16),

                  // Input Field - HANYA UPDATE TEMP, TIDAK SETSTATE
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Masukkan Diskon (%)',
                      hintText: '0 - 100',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      final newDiscount = double.tryParse(value) ?? 0;
                      // ✅ HANYA UPDATE TEMP, TIDAK SETSTATE → TIDAK REBUILD
                      setLocalState(() {
                        tempDiscount = newDiscount.clamp(0, 100).toDouble();
                      });
                    },
                  ),

                  SizedBox(height: 12),

                  // Preview jumlah diskon (HANYA DISPLAY, TIDAK REAL)
                  if (tempDiscount > 0)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Diskon:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                          ),
                          Text(
                            '${currencyFormat.format(_totalAfterItemDiscounts * tempDiscount / 100)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 12),

                  // Quick Percentage Buttons - HANYA UPDATE TEMP
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0, 5, 10, 15, 20, 25, 50].map((value) {
                      return ActionChip(
                        label: Text('$value%'),
                        backgroundColor: value == tempDiscount // ✅ COMPARE DENGAN TEMP
                            ? Color(0xFFF6A918)
                            : Colors.grey[200],
                        labelStyle: TextStyle(
                          color: value == tempDiscount ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        onPressed: () {
                          setLocalState(() {
                            tempDiscount = value.toDouble();
                            discountController.text = value.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setLocalState(() {
                              tempDiscount = 0;
                              discountController.text = '0';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                          ),
                          child: Text('Reset'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // ✅ BARU SEKARANG APPLY KE STATE REAL
                            setState(() {
                              _orderDiscount = tempDiscount;
                            });
                            setLocalState(() => isExpanded = false);

                            // ✅ UPDATE PAID AMOUNT JIKA TRANSFER
                            if (_paymentMethod == 'transfer') {
                              _paidController.text = _grandTotal.toStringAsFixed(0);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF6A918),
                          ),
                          child: Text('Selesai'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
                              // ✅ TAMPILKAN DISKON ITEM JIKA ADA
                              if (item.discount > 0)
                                Container(
                                  margin: EdgeInsets.only(top: 2),
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

          // ✅ TAMPILKAN BREAKDOWN PERHITUNGAN
          if (_itemDiscounts > 0 || _orderDiscount > 0) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal:', style: TextStyle(fontSize: 11, color: Colors.white)),
                      Text(currencyFormat.format(_subtotal), style: TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),

                  // Diskon Item
                  if (_itemDiscounts > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diskon Item:', style: TextStyle(fontSize: 11, color: Colors.white)),
                        Text('-${currencyFormat.format(_itemDiscounts)}', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                    ),

                  // Total setelah diskon item
                  if (_itemDiscounts > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Setelah Disc Item:', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                        Text(currencyFormat.format(_totalAfterItemDiscounts), style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),

                  // Diskon Order
                  if (_orderDiscount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diskon ${_orderDiscount.toStringAsFixed(0)}%:', style: TextStyle(fontSize: 11, color: Colors.white)),
                        Text('-${currencyFormat.format(_orderDiscountAmount)}', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                    ),
                ],
              ),
            ),
          ],
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