import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../models/order.dart';
import '../models/uangmuka_model.dart';
import '../services/api_service.dart';
import '../services/uangmuka_service.dart';
import '../services/receipt_service.dart';
import '../services/session_manager.dart';
import '../services/printer_service.dart';
import '../services/universal_printer_service.dart';

enum PaymentType { cash, edc, dp, piutang }

class PaymentItem {
  final PaymentType type;
  final String? subType;
  final double amount;
  final String? reference;

  PaymentItem({
    required this.type,
    this.subType,
    required this.amount,
    this.reference,
  });

  String get displayName {
    switch (type) {
      case PaymentType.cash:
        return 'CASH';
      case PaymentType.edc:
        return 'EDC ${subType ?? ""}';
      case PaymentType.dp:
        return 'DP ${reference ?? ""}';
      case PaymentType.piutang:
        return 'PIUTANG ${subType ?? ""}';
    }
  }

  IconData get icon {
    switch (type) {
      case PaymentType.cash:
        return Icons.money_rounded;
      case PaymentType.edc:
        return Icons.credit_card_rounded;
      case PaymentType.dp:
        return Icons.account_balance_wallet_rounded;
      case PaymentType.piutang:
        return Icons.receipt_long_rounded;
    }
  }

  Color get color {
    switch (type) {
      case PaymentType.cash:
        return Color(0xFFF6A918);
      case PaymentType.edc:
        return Color(0xFF4CC9F0);
      case PaymentType.dp:
        return Color(0xFF9D4EDD);
      case PaymentType.piutang:
        return Color(0xFF06D6A0);
    }
  }
}

class PaymentScreen extends StatefulWidget {
  final Customer customer;
  final List<OrderItem> orderItems;
  final String promoName;

  const PaymentScreen({
    Key? key,
    required this.customer,
    required this.orderItems,
    this.promoName = 'NONE',
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final List<PaymentItem> _paymentItems = [];
  PaymentType _selectedPaymentType = PaymentType.cash;

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _edcController = TextEditingController();
  final TextEditingController _dpNumberController = TextEditingController();
  final TextEditingController _dpAmountController = TextEditingController();
  final TextEditingController _piutangController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  String _selectedEdcType = 'QRIS';
  String _selectedPiutangType = 'ASA';

  bool _isProcessing = false;
  double _orderDiscount = 0.0;

  final List<String> _edcOptions = ['QRIS', 'BCA', 'MANDIRI', 'BRI', 'BNI', 'OTHER'];
  final List<String> _piutangOptions = ['ASA', 'BSM KANTOR', 'N3 PLESUNGAN', 'ROTIQ', 'SPI', 'OTHER'];

  final Color _primaryDark = Color(0xFF2C3E50);
  final Color _primaryLight = Color(0xFF34495E);
  final Color _accentGold = Color(0xFFF6A918);
  final Color _accentMint = Color(0xFF06D6A0);
  final Color _accentCoral = Color(0xFFFF6B6B);
  final Color _accentSky = Color(0xFF4CC9F0);
  final Color _accentPurple = Color(0xFF9D4EDD);
  final Color _bgLight = Color(0xFFFAFAFA);
  final Color _bgCard = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1A202C);
  final Color _textSecondary = Color(0xFF718096);
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _successGreen = Color(0xFF06D6A0);

  double get _subtotal => widget.orderItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));

  double get _itemDiscounts => widget.orderItems.fold(0.0, (sum, item) => sum + item.discountAmount);

  double get _totalAfterItemDiscounts => _subtotal - _itemDiscounts;

  double get _orderDiscountAmount => _totalAfterItemDiscounts * (_orderDiscount / 100);

  double get _grandTotal => _totalAfterItemDiscounts - _orderDiscountAmount;

  double get _totalPaid => _paymentItems.fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBalance => _grandTotal - _totalPaid;

  double get _change => _totalPaid > _grandTotal ? _totalPaid - _grandTotal : 0;

  double get _paymentProgress => _totalPaid / _grandTotal;

  bool get _isPaymentComplete => _remainingBalance <= 0;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() {
      final discount = double.tryParse(_discountController.text) ?? 0;
      if (discount >= 0 && discount <= 100) {
        setState(() => _orderDiscount = discount);
      }
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _edcController.dispose();
    _dpNumberController.dispose();
    _dpAmountController.dispose();
    _piutangController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _handleCashInput(String value) {
    final amount = double.tryParse(value.replaceAll('.', '').replaceAll(',', '')) ?? 0;

    final cashIndex = _paymentItems.indexWhere((p) => p.type == PaymentType.cash);
    if (cashIndex >= 0) {
      setState(() {
        _paymentItems[cashIndex] = PaymentItem(type: PaymentType.cash, amount: amount);
      });
    } else if (amount > 0) {
      setState(() {
        _paymentItems.add(PaymentItem(type: PaymentType.cash, amount: amount));
      });
    }
  }

  void _handleEdcInput(String value) {
    final amount = double.tryParse(value.replaceAll('.', '').replaceAll(',', '')) ?? 0;

    final edcIndex = _paymentItems.indexWhere((p) => p.type == PaymentType.edc);
    if (edcIndex >= 0) {
      setState(() {
        _paymentItems[edcIndex] = PaymentItem(
          type: PaymentType.edc,
          subType: _selectedEdcType,
          amount: amount,
        );
      });
    } else if (amount > 0) {
      setState(() {
        _paymentItems.add(PaymentItem(
          type: PaymentType.edc,
          subType: _selectedEdcType,
          amount: amount,
        ));
      });
    }
  }

  void _handleDpInput() {
    // final amount = double.tryParse(_dpAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    // final nomor = _dpNumberController.text.trim();
    //
    // if (nomor.isEmpty || amount <= 0) return;
    //
    // final dpIndex = _paymentItems.indexWhere((p) => p.type == PaymentType.dp);
    // if (dpIndex >= 0) {
    //   setState(() {
    //     _paymentItems[dpIndex] = PaymentItem(
    //       type: PaymentType.dp,
    //       subType: 'Uang Muka',
    //       amount: amount,
    //       reference: nomor,
    //     );
    //   });
    // } else {
    //   setState(() {
    //     _paymentItems.add(PaymentItem(
    //       type: PaymentType.dp,
    //       subType: 'Uang Muka',
    //       amount: amount,
    //       reference: nomor,
    //     ));
    //   });
    // }
  }

  void _handlePiutangInput(String value) {
    final amount = double.tryParse(value.replaceAll('.', '').replaceAll(',', '')) ?? 0;

    final piutangIndex = _paymentItems.indexWhere((p) => p.type == PaymentType.piutang);
    if (piutangIndex >= 0) {
      setState(() {
        _paymentItems[piutangIndex] = PaymentItem(
          type: PaymentType.piutang,
          subType: _selectedPiutangType,
          amount: amount,
        );
      });
    } else if (amount > 0) {
      setState(() {
        _paymentItems.add(PaymentItem(
          type: PaymentType.piutang,
          subType: _selectedPiutangType,
          amount: amount,
        ));
      });
    }
  }

  void _removePayment(PaymentType type) {
    setState(() => _paymentItems.removeWhere((p) => p.type == type));

    switch (type) {
      case PaymentType.cash:
        _cashController.clear();
        break;
      case PaymentType.edc:
        _edcController.clear();
        break;
      case PaymentType.dp:
        _dpNumberController.clear(); // Clear nomor DP
        // Tidak perlu clear _dpAmountController karena sudah tidak digunakan
        break;
      case PaymentType.piutang:
        _piutangController.clear();
        break;
    }
  }

  void _clearAllPayments() {
    setState(() => _paymentItems.clear());
    _cashController.clear();
    _edcController.clear();
    _dpNumberController.clear();
    _dpAmountController.clear();
    _piutangController.clear();
  }

  void _applyQuickDiscount(double percent) {
    setState(() => _orderDiscount = percent);
    _discountController.text = percent.toStringAsFixed(0);
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    );
  }

  void _onBackPressed() {
    if (_isProcessing) return;
    Navigator.pop(context, 'cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _bgLight,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              return isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildLandscapeOrderPanel(),
        ),
        Expanded(
          flex: 6,
          child: _buildLandscapePaymentPanel(),
        ),
      ],
    );
  }

  Widget _buildLandscapeOrderPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _bgLight,
        border: Border(right: BorderSide(color: _borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  onPressed: _onBackPressed,
                  padding: EdgeInsets.all(4),
                ),
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PEMBAYARAN',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _primaryDark.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _primaryDark.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.person_rounded, color: _primaryDark, size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customer.name,
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              if (widget.customer.phone != null && widget.customer.phone != '-')
                                Text(
                                  widget.customer.phone!,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _primaryDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _primaryDark.withOpacity(0.2)),
                              ),
                              child: Icon(Icons.receipt_long_rounded, color: _primaryDark, size: 16),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Detail Order',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accentGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _accentGold.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${widget.orderItems.length} item',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _accentGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        ...widget.orderItems.map((item) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _bgLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _accentGold.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _accentGold,
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
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      if (item.discountAmount > 0)
                                        Container(
                                          margin: EdgeInsets.only(top: 4),
                                          child: Text(
                                            item.discountType == 'rp'
                                                ? 'Disc Rp ${_formatCurrency(item.discountRp)}'
                                                : 'Disc ${item.discount}%',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              color: _accentMint,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(item.total),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _accentGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _accentGold.withOpacity(0.2)),
                              ),
                              child: Icon(Icons.discount_rounded, color: _accentGold, size: 16),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Diskon Order',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Masukkan diskon (%)',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: _borderColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.percent, size: 18, color: _textSecondary),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [5, 10, 15, 20, 25, 50].map((percent) {
                            return GestureDetector(
                              onTap: () => _applyQuickDiscount(percent.toDouble()),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _orderDiscount == percent ? _accentGold : _borderColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _orderDiscount == percent ? _accentGold : _borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '$percent%',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _orderDiscount == percent ? Colors.white : _textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryDark, _primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PEMBAYARAN',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          currencyFormat.format(_grandTotal),
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow('Subtotal:', _subtotal),
                              if (_itemDiscounts > 0)
                                _buildDetailRow('Diskon Item:', -_itemDiscounts, isNegative: true),
                              if (_orderDiscount > 0)
                                _buildDetailRow('Diskon ${_orderDiscount}%:', -_orderDiscountAmount, isNegative: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, {bool isNegative = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white.withOpacity(0.9))),
          Text(
            isNegative ? '-${currencyFormat.format(value)}' : currencyFormat.format(value),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isNegative ? _accentMint : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapePaymentPanel() {
    return Container(
      color: _bgLight,
      child: Column(
        children: [
          Container(
            height: 4,
            color: _borderColor,
            child: AnimatedFractionallySizedBox(
              duration: Duration(milliseconds: 300),
              widthFactor: _paymentProgress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_accentGold, _accentMint]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Container(
            height: 60,
            decoration: BoxDecoration(
              color: _bgCard,
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                _buildPaymentTab(PaymentType.cash, 'CASH', Icons.money_rounded),
                _buildPaymentTab(PaymentType.edc, 'EDC', Icons.credit_card_rounded),
                _buildPaymentTab(PaymentType.dp, 'DP', Icons.account_balance_wallet_rounded),
                _buildPaymentTab(PaymentType.piutang, 'PIUTANG', Icons.receipt_long_rounded),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: _buildCurrentPaymentInput(),
                ),
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bgCard,
              border: Border(top: BorderSide(color: _borderColor)),
            ),
            child: Column(
              children: [
                if (_paymentItems.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_rounded, color: _textSecondary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Pembayaran',
                              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                            ),
                            Spacer(),
                            Text(
                              currencyFormat.format(_totalPaid),
                              style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: _accentGold),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _paymentItems.map((payment) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: payment.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: payment.color.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(payment.icon, size: 13, color: payment.color),
                                  SizedBox(width: 5),
                                  Text(
                                    payment.displayName,
                                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _textPrimary),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    currencyFormat.format(payment.amount),
                                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: payment.color),
                                  ),
                                  SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removePayment(payment.type),
                                    child: Icon(Icons.close_rounded, size: 13, color: _textSecondary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Tagihan:', style: GoogleFonts.montserrat(fontSize: 13, color: _textPrimary)),
                          Text(
                            currencyFormat.format(_grandTotal),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Dibayar:', style: GoogleFonts.montserrat(fontSize: 13, color: _textPrimary)),
                          Text(
                            currencyFormat.format(_totalPaid),
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _isPaymentComplete ? _successGreen : _accentGold,
                            ),
                          ),
                        ],
                      ),
                      if (_remainingBalance > 0) ...[
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kurang Bayar:', style: GoogleFonts.montserrat(fontSize: 13, color: _accentCoral)),
                            Text(
                              currencyFormat.format(_remainingBalance),
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _accentCoral,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_change > 0) ...[
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kembalian:', style: GoogleFonts.montserrat(fontSize: 13, color: _successGreen)),
                            Text(
                              currencyFormat.format(_change),
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _successGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearAllPayments,
                        icon: Icon(Icons.clear_all_rounded, size: 16),
                        label: Text('Reset Semua'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentCoral,
                          side: BorderSide(color: _accentCoral),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isPaymentComplete ? _primaryDark : _borderColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isPaymentComplete ? _processPayment : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Center(
                              child: _isProcessing
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'PROSES PEMBAYARAN',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(PaymentType type, String label, IconData icon) {
    final isSelected = _selectedPaymentType == type;
    final color = _getPaymentTypeColor(type);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedPaymentType = type),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : _bgLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isSelected ? color.withOpacity(0.3) : _borderColor),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSelected ? color : _textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPaymentTypeColor(PaymentType type) {
    switch (type) {
      case PaymentType.cash:
        return _accentGold;
      case PaymentType.edc:
        return _accentSky;
      case PaymentType.dp:
        return _accentPurple;
      case PaymentType.piutang:
        return _accentMint;
    }
  }

  Widget _buildCurrentPaymentInput() {
    switch (_selectedPaymentType) {
      case PaymentType.cash:
        return _buildCashInput();
      case PaymentType.edc:
        return _buildEdcInput();
      case PaymentType.dp:
        return _buildDpInput();
      case PaymentType.piutang:
        return _buildPiutangInput();
    }
  }

  Widget _buildCashInput() {
    final cashPayment = _paymentItems.firstWhere(
          (p) => p.type == PaymentType.cash,
      orElse: () => PaymentItem(type: PaymentType.cash, amount: 0),
    );

    if (_cashController.text.isEmpty && cashPayment.amount > 0) {
      _cashController.text = cashPayment.amount.toStringAsFixed(0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pembayaran Cash',
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        SizedBox(height: 20),

        Container(
          height: 60,
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Center(
            child: TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, color: _primaryDark),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.montserrat(fontSize: 24, color: _textSecondary),
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('Rp', style: GoogleFonts.montserrat(fontSize: 20, color: _textSecondary)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              onChanged: _handleCashInput,
            ),
          ),
        ),
        SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _cashController.text = _grandTotal.toStringAsFixed(0);
                  _handleCashInput(_grandTotal.toStringAsFixed(0));
                },
                icon: Icon(Icons.check_rounded, size: 14),
                label: Text('UANG PAS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _successGreen,
                  side: BorderSide(color: _successGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _cashController.clear();
                  _handleCashInput('');
                },
                icon: Icon(Icons.clear_rounded, size: 14),
                label: Text('HAPUS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accentCoral,
                  side: BorderSide(color: _accentCoral),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 20),
        Text('Quick Amount:', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
        SizedBox(height: 12),

        _buildClosestAmounts(),
      ],
    );
  }

  List<double> _getClosestDenominations(double amount) {
    const List<double> denominations = [1000, 2000, 5000, 10000, 20000, 50000, 100000];

    if (amount <= 0) return [10000, 20000, 50000];

    List<double> greaterOrEqual = denominations.where((denom) => denom >= amount).toList();

    if (greaterOrEqual.length < 3) {
      final sortedDenoms = [...denominations]..sort((a, b) => b.compareTo(a));
      for (final denom in sortedDenoms) {
        if (!greaterOrEqual.contains(denom)) {
          greaterOrEqual.add(denom);
          if (greaterOrEqual.length >= 3) break;
        }
      }
    }

    greaterOrEqual.sort((a, b) {
      final diffA = (a - amount).abs();
      final diffB = (b - amount).abs();
      return diffA.compareTo(diffB);
    });

    return greaterOrEqual.take(3).toList();
  }

  Widget _buildClosestAmounts() {
    final closestAmounts = _getClosestDenominations(_remainingBalance > 0 ? _remainingBalance : _grandTotal);

    return Row(
      children: [
        Expanded(
          child: _buildClosestAmountCard(closestAmounts[0], 'TERDEKAT'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildClosestAmountCard(closestAmounts[1], 'DEKAT'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildClosestAmountCard(closestAmounts[2], 'MENDATANGI'),
        ),
      ],
    );
  }

  Widget _buildClosestAmountCard(double amount, String label) {
    return Material(
      color: _primaryDark.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          final current = double.tryParse(_cashController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
          _cashController.text = (current + amount).toStringAsFixed(0);
          _handleCashInput((current + amount).toStringAsFixed(0));
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: _accentGold.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                currencyFormat.format(amount),
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDenominationCards() {
    const commonDenominations = [10000.0, 20000.0, 50000.0, 100000.0, 500000.0, 0.0];
    const labels = ['10K', '20K', '50K', '100K', '500K', '+ CUSTOM'];

    return List.generate(commonDenominations.length, (index) {
      return _buildQuickAmountCard(
        commonDenominations[index],
        label: labels[index],
      );
    });
  }

  Widget _buildQuickAmountCard(double amount, {String? label}) {
    return Material(
      color: _bgCard,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (amount > 0) {
            final current = double.tryParse(_cashController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
            _cashController.text = (current + amount).toStringAsFixed(0);
            _handleCashInput((current + amount).toStringAsFixed(0));
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: label != null
                ? Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary))
                : Text(
              currencyFormat.format(amount),
              style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdcInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pembayaran EDC',
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jenis EDC:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  SizedBox(height: 8),
                  Container(
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEdcType,
                        items: _edcOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type, style: GoogleFonts.montserrat(fontSize: 13, color: _textPrimary)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedEdcType = value!),
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: _textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jumlah:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _edcController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderSide: BorderSide(color: _borderColor)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accentSky)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: _handleEdcInput,
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_remainingBalance > 0) ...[
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _edcController.text = _remainingBalance.toStringAsFixed(0);
                _handleEdcInput(_remainingBalance.toStringAsFixed(0));
              },
              icon: Icon(Icons.autorenew_rounded, size: 14),
              label: Text('ISI SISA (${currencyFormat.format(_remainingBalance)})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentSky,
                side: BorderSide(color: _accentSky),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDpInput() {
    // Cek apakah sudah ada DP di payment items
    final dpPayment = _paymentItems.firstWhere(
          (p) => p.type == PaymentType.dp,
      orElse: () => PaymentItem(type: PaymentType.dp, amount: 0),
    );

    final hasDp = dpPayment.amount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pembayaran DP (Uang Muka)',
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        SizedBox(height: 20),

        if (!hasDp) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor Uang Muka:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dpNumberController,
                      enabled: false, // Disable karena hanya bisa dipilih dari pencarian
                      decoration: InputDecoration(
                        hintText: 'Klik tombol CARI untuk memilih uang muka...',
                        border: OutlineInputBorder(borderSide: BorderSide(color: _borderColor)),
                        prefixIcon: Icon(Icons.numbers, color: _textSecondary),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accentPurple)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 90,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _accentPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showDpSearchModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('CARI', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ] else ...[
          // Tampilkan info DP yang sudah dipilih
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentPurple.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accentPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dpPayment.reference ?? 'No Reference',
                            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                          ),
                          Text(
                            'Uang Muka',
                            style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(dpPayment.amount),
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: _accentPurple),
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _removePayment(PaymentType.dp),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _accentCoral.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 12, color: _accentCoral),
                                SizedBox(width: 4),
                                Text('Hapus', style: GoogleFonts.montserrat(fontSize: 10, color: _accentCoral)),
                              ],
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
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDpSearchModal,
              icon: Icon(Icons.swap_horiz_rounded, size: 14),
              label: Text('GANTI DP LAIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentPurple,
                side: BorderSide(color: _accentPurple),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPiutangInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pembayaran Piutang',
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jenis Piutang:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  SizedBox(height: 8),
                  Container(
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPiutangType,
                        items: _piutangOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type, style: GoogleFonts.montserrat(fontSize: 13, color: _textPrimary)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedPiutangType = value!),
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: _textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jumlah:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  SizedBox(height: 8),
                  TextField(
                    controller: _piutangController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderSide: BorderSide(color: _borderColor)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accentMint)),
                    ),
                    onChanged: _handlePiutangInput,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                onPressed: _onBackPressed,
                padding: EdgeInsets.all(4),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Icon(Icons.payment_rounded, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PEMBAYARAN',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_rounded, color: _primaryDark, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.customer.name, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                                if (widget.customer.phone != '-')
                                  Text(widget.customer.phone!, style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ...widget.orderItems.map((item) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accentGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _accentGold.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: _accentGold),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(child: Text('${item.product.name}', style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary))),
                            Text(currencyFormat.format(item.total), style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryDark)),
                          ],
                        ),
                      )).toList(),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL:', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary)),
                                Text(
                                  currencyFormat.format(_grandTotal),
                                  style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: _accentGold),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Dibayar:', style: GoogleFonts.montserrat(fontSize: 13, color: _textPrimary)),
                                Text(currencyFormat.format(_totalPaid),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _isPaymentComplete ? _successGreen : _accentGold,
                                    )),
                              ],
                            ),
                            if (_remainingBalance > 0) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Kurang:', style: GoogleFonts.montserrat(fontSize: 13, color: _accentCoral)),
                                  Text(currencyFormat.format(_remainingBalance),
                                      style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700, color: _accentCoral)),
                                ],
                              ),
                            ],
                            if (_change > 0) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Kembalian:', style: GoogleFonts.montserrat(fontSize: 13, color: _successGreen)),
                                  Text(currencyFormat.format(_change),
                                      style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700, color: _successGreen)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metode Pembayaran', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
                      SizedBox(height: 12),
                      if (_paymentItems.isNotEmpty) ...[
                        ..._paymentItems.map((payment) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(payment.icon, color: payment.color, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(payment.displayName,
                                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                                  ),
                                  Text(currencyFormat.format(payment.amount),
                                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: payment.color)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 12),
                      ],
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Column(
                          children: [
                            Text('Pilih Metode:', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                _buildPortraitPaymentTab(PaymentType.cash, 'CASH', Icons.money_rounded),
                                SizedBox(width: 8),
                                _buildPortraitPaymentTab(PaymentType.edc, 'EDC', Icons.credit_card_rounded),
                                SizedBox(width: 8),
                                _buildPortraitPaymentTab(PaymentType.dp, 'DP', Icons.account_balance_wallet_rounded),
                                SizedBox(width: 8),
                                _buildPortraitPaymentTab(PaymentType.piutang, 'PIUTANG', Icons.receipt_long_rounded),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildCurrentPaymentInput(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border(top: BorderSide(color: _borderColor)),
          ),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _isPaymentComplete ? _primaryDark : _borderColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isPaymentComplete ? _processPayment : null,
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: _isProcessing
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'PROSES PEMBAYARAN',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitPaymentTab(PaymentType type, String label, IconData icon) {
    final isSelected = _selectedPaymentType == type;
    final color = _getPaymentTypeColor(type);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedPaymentType = type),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : _bgLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? color : _borderColor),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: isSelected ? color : _textSecondary),
                  SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_isProcessing) return false;
    _onBackPressed();
    return false;
  }

  Future<void> _processPayment() async {
    if (!_isPaymentComplete) {
      _showSnackbar('Pembayaran belum lengkap', _accentGold);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final currentUser = SessionManager.getCurrentUser();

      final itemsForPrint = widget.orderItems.map((item) {
        return {
          'product_name': item.product.name,
          'quantity': item.quantity,
          'price': item.product.price,
          'total': item.total,
          'discount': item.discountAmount,
        };
      }).toList();

      final paymentMethodsForPrint = _paymentItems.map((payment) {
        return {
          'type': payment.type.toString().split('.').last,
          'subType': payment.subType,
          'amount': payment.amount,
          'reference': payment.reference,
        };
      }).toList();

      final change = _change;

      final order = Order(
        customer: widget.customer,
        items: widget.orderItems,
        paymentMethod: _determinePaymentMethod(),
        paidAmount: _totalPaid,
        userName: currentUser?.kduser ?? 'ADMIN',
        userId: currentUser?.id ?? '01',
        globalDiscount: _orderDiscount,
      );

      await _printReceipt(
        orderId: '${DateTime.now().millisecondsSinceEpoch}',
        items: itemsForPrint,
        paymentMethods: paymentMethodsForPrint,
        change: change,
        order: order,
      );

      final orderPayload = {
        'customer_id': widget.customer.id,
        'items': order.items.map((item) => item.toJson()).toList(),
        'payment_methods': paymentMethodsForPrint,
        'grand_total': _grandTotal,
        'created_at': order.createdAt.toIso8601String(),
        'user_name': order.userName,
        'user_id': order.userId,
        'global_discount': _orderDiscount,
        'promo_name': widget.promoName,
        'change': change,
        'paid_amount': _totalPaid,
      };

      final result = await ApiService.submitOrder(orderPayload);

      if (result['success']) {
        for (final payment in _paymentItems.where((p) => p.type == PaymentType.dp && p.reference != null)) {
          try {
            await UangMukaService.markAsRealisasi(payment.reference!);
          } catch (e) {
            print('Error marking DP as realisasi: $e');
          }
        }

        final orderId = result['order_id']?.toString() ?? '';
        _showSuccessDialog(order, orderId);
      } else {
        setState(() => _isProcessing = false);
        _showSnackbar(result['message'] ?? 'Gagal menyimpan order', _accentCoral);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackbar('Error: ${e.toString()}', _accentCoral);
    }
  }

  Future<void> _printReceipt({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> paymentMethods,
    required double change,
    required Order order,
  }) async {
    try {
      final success = await UniversalPrinterService().printReceipt(
        orderId: orderId,
        customerName: widget.customer.name,
        items: items,
        subtotal: _totalAfterItemDiscounts,
        orderDiscountAmount: _orderDiscountAmount,
        grandTotal: _grandTotal,
        paidAmount: order.paidAmount,
        change: change,
        cashierName: order.userName ?? 'ADMIN',
        createdAt: order.createdAt,
        paymentMethods: paymentMethods,
      );

      if (!success) {
        await ReceiptService.printReceipt(order, orderId, useThermal: false);
      }
    } catch (e) {
      print('Thermal print error: $e');
      await ReceiptService.printReceipt(order, orderId, useThermal: false);
    }
  }

  String _determinePaymentMethod() {
    if (_paymentItems.length == 1) {
      switch (_paymentItems.first.type) {
        case PaymentType.cash:
          return 'cash';
        case PaymentType.edc:
          return 'transfer';
        case PaymentType.dp:
          return 'dp';
        case PaymentType.piutang:
          return 'piutang';
      }
    }
    return 'mixed';
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog(Order order, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _successGreen.withOpacity(0.3)),
                ),
                child: Icon(Icons.check_rounded, color: _successGreen, size: 30),
              ),
              SizedBox(height: 16),
              Text(
                'TRANSAKSI BERHASIL',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Order: $orderId',
                style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary),
              ),
              SizedBox(height: 4),
              Text(
                'Customer: ${widget.customer.name}',
                style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary),
              ),
              SizedBox(height: 16),
              Text(
                currencyFormat.format(order.paidAmount),
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _accentGold,
                ),
              ),
              SizedBox(height: 12),
              if (_change > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _successGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Kembalian: ${currencyFormat.format(_change)}',
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: _successGreen),
                  ),
                ),
              SizedBox(height: 20),
              Container(
                width: 150,
                height: 40,
                decoration: BoxDecoration(
                  color: _primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop('completed');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Text(
                        'SELESAI',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDpSearchModal() async {
    final selected = await showDialog<UangMuka>(
      context: context,
      builder: (context) => DpSelectionDialog(),
    );

    if (selected != null) {
      _dpNumberController.text = selected.umNomor;

      final dpIndex = _paymentItems.indexWhere((p) => p.type == PaymentType.dp);
      if (dpIndex >= 0) {
        setState(() {
          _paymentItems[dpIndex] = PaymentItem(
            type: PaymentType.dp,
            subType: 'Uang Muka',
            amount: selected.umNilai,
            reference: selected.umNomor,
          );
        });
      } else {
        setState(() {
          _paymentItems.add(PaymentItem(
            type: PaymentType.dp,
            subType: 'Uang Muka',
            amount: selected.umNilai,
            reference: selected.umNomor,
          ));
        });
      }
    }
  }
}

class DpSelectionDialog extends StatefulWidget {
  @override
  State<DpSelectionDialog> createState() => _DpSelectionDialogState();
}

class _DpSelectionDialogState extends State<DpSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<UangMuka> _uangMukaList = [];
  List<UangMuka> _filteredList = [];
  bool _isLoading = false;

  final Color _primaryDark = Color(0xFF2C3E50);
  final Color _bgLight = Color(0xFFFAFAFA);
  final Color _bgCard = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1A202C);
  final Color _textSecondary = Color(0xFF718096);
  final Color _borderColor = Color(0xFFE2E8F0);
  final Color _accentPurple = Color(0xFF9D4EDD);

  @override
  void initState() {
    super.initState();
    _loadUangMuka();
  }

  Future<void> _loadUangMuka() async {
    setState(() => _isLoading = true);
    try {
      final response = await UangMukaService.getAvailableUangMuka();
      setState(() {
        _uangMukaList = response;
        _filteredList = response;
      });
    } catch (e) {
      print('Error loading uang muka: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterList(String query) {
    setState(() {
      _filteredList = _uangMukaList.where((um) {
        return um.umNomor.toLowerCase().contains(query.toLowerCase()) ||
            um.umCustomer.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _bgCard,
      child: Container(
        height: 500,
        width: 450,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, Color(0xFF34495E)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Uang Muka',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pilih uang muka yang akan digunakan',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor uang muka atau customer...',
                    prefixIcon: Icon(Icons.search_rounded, color: _textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _filterList,
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryDark))
                  : _filteredList.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment_outlined, size: 48, color: _borderColor),
                    SizedBox(height: 12),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada uang muka tersedia'
                          : 'Uang muka tidak ditemukan',
                      style: GoogleFonts.montserrat(fontSize: 14, color: _textSecondary),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final um = _filteredList[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, um),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [_accentPurple, Color(0xFF7B2CBF)]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      um.umNomor,
                                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                                    ),
                                    SizedBox(height: 4),
                                    Text(um.umCustomer, style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(um.umNilai),
                                    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: _accentPurple),
                                  ),
                                  SizedBox(height: 2),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: um.umJenisBayar == 'Cash' ? Color(0xFF06D6A0).withOpacity(0.1) : Color(0xFF4CC9F0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: um.umJenisBayar == 'Cash' ? Color(0xFF06D6A0).withOpacity(0.3) : Color(0xFF4CC9F0).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      um.umJenisBayar,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: um.umJenisBayar == 'Cash' ? Color(0xFF06D6A0) : Color(0xFF4CC9F0),
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
                },
              ),
            ),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _borderColor))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Tutup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12),
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
}