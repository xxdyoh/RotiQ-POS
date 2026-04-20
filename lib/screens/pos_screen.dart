import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/order_item.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'payment_screen.dart';
import '../services/printer_service.dart';
import 'printer_settings_screen.dart';
import '../services/category_service.dart';
import '../services/discount_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../services/bluetooth_service.dart';
import '../services/printer_config_service.dart';
import '../screens/tutup_kasir_form_screen.dart';
import '../routes/app_routes.dart';
import '../services/universal_printer_service.dart';
import '../screens/printer_configuration_screen.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final List<OrderItem> _cartItems = [];
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = ['Semua'];
  String _selectedCategory = 'Semua';
  Customer? _selectedCustomer;
  bool _isLoading = false;

  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final Map<String, double> _categoryDiscountPercent = {};
  final Map<String, double> _categoryDiscountRp = {};

  bool _loadingDiscounts = false;
  bool _isAdmin = false;

  bool _printerConnected = false;
  String? _connectedPrinterName;

  bool _showTutupKasirMenu = false;

  final List<Customer> _customers = [
    Customer(id: 'UMUM', name: 'UMUM', phone: '-'),
    Customer(id: 'ASA', name: 'ASA', phone: '-'),
    Customer(id: 'BSM KANTOR', name: 'BSM KANTOR', phone: '-'),
    Customer(id: 'BSM BU ENI / PAK TRI', name: 'BSM BU ENI / PAK TRI', phone: '-'),
    Customer(id: 'N3 PLESUNGAN', name: 'N3 PLESUNGAN', phone: '-'),
    Customer(id: 'N3 HF', name: 'N3 HF', phone: '-'),
    Customer(id: 'ROTIQ', name: 'ROTIQ', phone: '-'),
    Customer(id: 'ROSO TRESNO', name: 'ROSO TRESNO', phone: '-'),
    Customer(id: 'RESERVASI', name: 'RESERVASI', phone: '-'),
    Customer(id: 'SPI', name: 'SPI', phone: '-'),
  ];

  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
  double get _totalDiscount => _cartItems.fold(0, (sum, item) => sum + item.discountAmount);
  double get _grandTotal => _subtotal - _totalDiscount;
  int get _totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  int get _totalUniqueItems => _cartItems.length;

  Map<String, dynamic>? _selectedPromo;
  List<Map<String, dynamic>> _promos = [];
  bool _loadingPromos = false;

  String? _cabangJenis;

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    );
  }

  final UniversalPrinterService _printerService = UniversalPrinterService();
  StreamSubscription<String>? _barcodeSubscription;
  bool _isScannerEnabled = false;
  final TextEditingController _manualBarcodeController = TextEditingController();
  bool _showManualInput = false;
  final FocusNode _barcodeFocusNode = FocusNode();

  String _barcodeBuffer = '';
  Timer? _barcodeTimer;
  bool _scannerActive = true;

  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  bool get _isLargeScreen => MediaQuery.of(context).size.width > 1200;
  bool get _isMediumScreen => MediaQuery.of(context).size.width > 800;

  final Color _primaryDark = Color(0xFF2C3E50);
  final Color _primaryLight = Color(0xFF34495E);
  final Color _accentGold = Color(0xFFF6A918);
  final Color _accentMint = Color(0xFF06D6A0);
  final Color _accentCoral = Color(0xFFFF6B6B);
  final Color _accentSky = Color(0xFF4CC9F0);
  final Color _bgLight = Color(0xFFFAFAFA);
  final Color _bgCard = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1A202C);
  final Color _textSecondary = Color(0xFF718096);
  final Color _borderColor = Color(0xFFE2E8F0);

  double get _compactFontSmall => 10.0;
  double get _compactFontMedium => 11.0;
  double get _compactFontLarge => 12.0;
  double get _compactPaddingSmall => 6.0;
  double get _compactPaddingMedium => 8.0;
  double get _compactPaddingLarge => 12.0;

  @override
  void initState() {
    super.initState();
    _setDefaultCustomer();
    _loadData();
    _loadPromos();
    _searchController.addListener(_filterProducts);
    _checkUserRole();
    _checkCabangJenis();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDefaultPrinter();
      _setupBarcodeScanner();
    });

    _setupAutoScanner();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeSubscription?.cancel();
    _manualBarcodeController.dispose();
    _barcodeFocusNode.dispose();
    _searchFocusNode.dispose();
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    _barcodeTimer?.cancel();
    super.dispose();
  }

  void _setupAutoScanner() {
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
    _scannerActive = true;
  }

  void _handleRawKeyEvent(RawKeyEvent event) {
    if (!_scannerActive) return;
    if (event is! RawKeyDownEvent) return;

    final logicalKey = event.logicalKey;
    final keyLabel = logicalKey.keyLabel;

    if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.tab) {
      _processBarcode();
      return;
    }

    if (_isValidBarcodeCharacter(keyLabel)) {
      _barcodeBuffer += keyLabel;
      _resetBarcodeTimer();
    }
  }

  bool _isValidBarcodeCharacter(String char) {
    if (char.isEmpty || char.length > 1) return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '-' || char == '.' || char == '_' || char == '/' ||
        char == '\\' || char == ':' || char == ' ';
  }

  void _resetBarcodeTimer() {
    _barcodeTimer?.cancel();
    _barcodeTimer = Timer(Duration(milliseconds: 100), () {
      if (_barcodeBuffer.isNotEmpty && _barcodeBuffer.length >= 3) {
        _processBarcode();
      } else {
        _barcodeBuffer = '';
      }
    });
  }

  void _processBarcode() {
    if (_barcodeBuffer.isEmpty) return;
    final barcode = _barcodeBuffer.trim();
    _barcodeBuffer = '';
    _handleScannedBarcode(barcode);
  }

  void _handleScannedBarcode(String barcode) {
    Product? foundProduct;
    for (var product in _products) {
      if (product.id == barcode) {
        foundProduct = product;
        break;
      }
    }

    if (foundProduct != null) {
      _addToCart(foundProduct);
      _showScannerFeedback(foundProduct.name);
      SystemSound.play(SystemSoundType.click);
    } else {
      _showScannerError('Produk tidak ditemukan: $barcode');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _showScannerFeedback(String productName) {
    _showOverlayFeedback('✓ $productName', _accentMint);
  }

  void _showScannerError(String message) {
    _showOverlayFeedback(message, _accentCoral);
  }

  void _showOverlayFeedback(String text, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: MediaQuery.of(context).size.width / 2 - 90,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  color == _accentMint ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  text,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Timer(Duration(seconds: 2), () => overlayEntry.remove());
  }

  void _checkUserRole() {
    final user = SessionManager.getCurrentUser();
    _isAdmin = (user?.kduser ?? '').toLowerCase() == 'admin';
  }

  void _checkCabangJenis() {
    final cabang = SessionManager.getCurrentCabang();
    setState(() {
      _cabangJenis = cabang?.jenis;
    });
  }

  bool get _isOutlet => _cabangJenis?.toLowerCase() == 'outlet';
  bool get _isTenant => _cabangJenis?.toLowerCase() == 'tenant';

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isAdmin) {
          _showSnackbar('Kasir tidak bisa kembali ke menu', _accentGold);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _bgLight,
        body: SafeArea(
          child: SmartRefresher(
            controller: _refreshController,
            onRefresh: _onRefresh,
            header: ClassicHeader(
              height: 50,
              completeIcon: Icon(Icons.check, color: _accentMint, size: 16),
              failedIcon: Icon(Icons.error, color: _accentCoral, size: 16),
              idleIcon: Icon(Icons.arrow_downward, color: _textSecondary, size: 16),
              releaseIcon: Icon(Icons.refresh, color: _accentGold, size: 16),
              textStyle: GoogleFonts.montserrat(fontSize: 11),
            ),
            child: _buildMainLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildMainLayout() {
    final isLandscape = MediaQuery.of(context).size.width > 600;
    return isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout();
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeader(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border(bottom: BorderSide(color: _borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _buildCustomerSelector()),
              SizedBox(width: 8),
              Expanded(child: _buildPromoSelector()),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(12),
          color: _bgCard,
          child: Column(
            children: [
              _buildSearchBar(),
              SizedBox(height: 8),
              _buildCategoryChips(),
            ],
          ),
        ),
        Expanded(child: _buildProductGrid()),
        if (_cartItems.isNotEmpty) _buildCartBottomSheet(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildHeader(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _bgCard,
                  border: Border(bottom: BorderSide(color: _borderColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildCustomerSelector()),
                    SizedBox(width: 8),
                    Expanded(child: _buildPromoSelector()),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(12),
                color: _bgCard,
                child: Column(
                  children: [
                    _buildSearchBar(),
                    SizedBox(height: 8),
                    _buildCategoryChips(),
                  ],
                ),
              ),
              Expanded(child: _buildProductGrid()),
            ],
          ),
        ),
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border(left: BorderSide(color: _borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(-2, 0),
              ),
            ],
          ),
          child: _buildCartPanel(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primaryLight],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isAdmin)
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.all(4),
            ),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(Icons.point_of_sale_rounded, size: 18, color: Colors.white),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POS',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Tooltip(
                message: 'Uang Muka',
                child: GestureDetector(
                  onTap: _openUangMukaList,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.account_balance_wallet, size: 14, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(width: 6),
              Tooltip(
                message: 'Tutup Kasir',
                child: GestureDetector(
                  onTap: _openTutupKasirForm,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.lock_clock, size: 14, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(width: 6),
              _buildScannerToggle(),
              SizedBox(width: 6),
              _buildPrinterStatus(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerToggle() {
    return Tooltip(
      message: _scannerActive ? 'Scanner Aktif' : 'Scanner Nonaktif',
      child: GestureDetector(
        onTap: _toggleScanner,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _scannerActive ? _accentMint.withOpacity(0.15) : _textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _scannerActive ? _accentMint : _textSecondary,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 14,
                color: _scannerActive ? _accentMint : _textSecondary,
              ),
              SizedBox(width: 4),
              Text(
                _scannerActive ? 'ON' : 'OFF',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _scannerActive ? _accentMint : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterStatus() {
    return GestureDetector(
      onTap: _goToPrinterSettings,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _printerConnected ? _accentSky.withOpacity(0.15) : _accentCoral.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _printerConnected ? _accentSky : _accentCoral,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.print_rounded,
              size: 14,
              color: _printerConnected ? _accentSky : _accentCoral,
            ),
            SizedBox(width: 4),
            Text(
              _printerConnected ? 'OK' : 'NO',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _printerConnected ? _accentSky : _accentCoral,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.search_rounded, size: 16, color: _textSecondary),
          ),
          Expanded(
            child: Container(
              height: 36,
              child: Center(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.montserrat(fontSize: 12, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Container(
              height: 36,
              child: Center(
                child: IconButton(
                  icon: Icon(Icons.clear_rounded, size: 16, color: _textSecondary),
                  onPressed: () => _searchController.clear(),
                  padding: EdgeInsets.all(6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _selectCategory(category),
              child: Container(
                height: 34,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryDark : _bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _primaryDark : _borderColor,
                    width: 1.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: _primaryDark.withOpacity(0.2),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    category.length > 12 ? '${category.substring(0, 10)}..' : category,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : _textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return GestureDetector(
      onTap: _showCustomerSelector,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedCustomer?.name ?? 'Customer',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Tap untuk ubah',
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_drop_down_rounded, size: 16, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSelector() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentGold,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Icon(Icons.local_offer_rounded, size: 16, color: Colors.white),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _loadingPromos
                ? Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _primaryDark),
              ),
            )
                : DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedPromo,
                items: _promos.map((promo) {
                  final discount = double.tryParse(promo['disc_persen'].toString()) ?? 0;
                  return DropdownMenuItem(
                    value: promo,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            promo['disc_nama'] == 'NONE' ? Icons.close_rounded : Icons.local_offer_outlined,
                            size: 14,
                            color: promo['disc_nama'] == 'NONE' ? _textSecondary : _accentGold,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              promo['disc_nama'],
                              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (discount > 0 && promo['disc_nama'] != 'NONE')
                            Container(
                              margin: EdgeInsets.only(left: 4),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accentGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: _accentGold.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${discount}%',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _accentGold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (selected) {
                  if (selected != null) {
                    setState(() => _selectedPromo = selected);
                    _updateCartDiscounts();
                  }
                },
                isExpanded: true,
                icon: Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_drop_down_rounded, size: 16, color: _textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading || _loadingDiscounts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primaryDark),
            ),
            SizedBox(height: 8),
            Text(
              'Memuat produk...',
              style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 32, color: _borderColor),
            SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Produk "${_searchController.text}" tidak ditemukan'
                  : 'Tidak ada produk dalam kategori ini',
              style: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final crossAxisCount = MediaQuery.of(context).size.width > 1200 ? 5 :
    MediaQuery.of(context).size.width > 1000 ? 4 :
    MediaQuery.of(context).size.width > 800 ? 3 :
    MediaQuery.of(context).size.width > 600 ? 3 : 2;

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
    );
  }

  Widget _buildProductCard(Product product) {
    final bool isOutOfStock = _isOutlet && (product.stock ?? 0) == 0;
    final bool hasDiscount = _categoryDiscountPercent.containsKey(product.category) ||
        _categoryDiscountRp.containsKey(product.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // onTap: isOutOfStock ? null : () => _addToCart(product),
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 4),

                Row(
                  children: [
                    if (product.category != null && product.category!.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          // decoration: BoxDecoration(
                          //   color: _primaryDark.withOpacity(0.08),
                          //   borderRadius: BorderRadius.circular(4),
                          // ),
                          child: Text(
                            product.category!,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: _primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    SizedBox(width: 4),

                    if (hasDiscount && !isOutOfStock)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accentGold, Color(0xFFE69500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DISKON',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),

                Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(product.price),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),

                    if (_isOutlet)
                      Text(
                        (product.stock ?? 0) > 0
                            ? 'STOK: ${product.stock}'
                            : 'HABIS',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: (product.stock ?? 0) > 0 ? _accentMint : _accentCoral,
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
  }

  Widget _buildCartPanel() {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(left: BorderSide(color: _borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryLight],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.shopping_bag_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KERANJANG',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '$_totalItems produk',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_cartItems.isNotEmpty)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: _clearCart,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: _bgLight,
              child: _cartItems.isEmpty
                  ? _buildEmptyCart()
                  : ListView.separated(
                padding: EdgeInsets.all(8),
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => SizedBox(height: 6),
                itemBuilder: (context, index) => _buildCartItem(_cartItems[index], index),
              ),
            ),
          ),

          _buildCartSummary(),
        ],
      ),
    );
  }

  Widget _buildCartItem(OrderItem item, int index) {
    final product = item.product;
    final itemTotal = (product.price * item.quantity) - item.discountAmount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditQuantityDialog(index, item),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryDark, _primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: _accentCoral,
                      ),
                      onPressed: () => _removeFromCart(index),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    ),
                  ],
                ),

                SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currencyFormat.format(product.price),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      '${item.quantity}x',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primaryDark,
                      ),
                    ),

                    if (item.discountAmount > 0)
                      Text(
                        '-${currencyFormat.format(item.discountAmount)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _accentMint,
                        ),
                      ),

                    Text(
                      currencyFormat.format(itemTotal),
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
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
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 48,
            color: _borderColor,
          ),
          SizedBox(height: 12),
          Text(
            'Keranjang Kosong',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tambahkan produk untuk memulai',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(
          top: BorderSide(color: _borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bgLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  label: 'Subtotal',
                  value: _subtotal,
                  labelStyle: GoogleFonts.montserrat(fontSize: 11, color: _textPrimary),
                  valueStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: _textPrimary),
                ),
                SizedBox(height: 4),
                if (_totalDiscount > 0)
                  Column(
                    children: [
                      _buildSummaryRow(
                        label: 'Diskon',
                        value: _totalDiscount,
                        labelStyle: GoogleFonts.montserrat(fontSize: 11, color: _accentGold),
                        valueStyle: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w700, color: _accentGold),
                        isDiscount: true,
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                Container(
                  height: 1,
                  color: _borderColor,
                  margin: EdgeInsets.symmetric(vertical: 6),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _proceedToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                      elevation: 4,
                      shadowColor: _primaryDark.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BAYAR ',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_grandTotal),
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double value,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Row(
          children: [
            if (isDiscount) Text('-', style: valueStyle),
            Text(currencyFormat.format(value), style: valueStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildCartBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(top: BorderSide(color: _borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.shopping_cart_rounded, size: 20, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keranjang Aktif',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_totalItems item • ${currencyFormat.format(_grandTotal)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accentGold,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _accentGold.withOpacity(0.4),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.payment_rounded, size: 22, color: Colors.white),
                    onPressed: _proceedToPayment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQuantityDialog(int index, OrderItem item) {
    int tempQuantity = item.quantity;
    final TextEditingController _qtyController = TextEditingController(text: tempQuantity.toString());
    final FocusNode _qtyFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            titlePadding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            actionsPadding: EdgeInsets.all(8),
            title: Text(
              'Edit Quantity',
              style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),

                // Row dengan tombol - dan + serta TextField di tengah
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tombol Minus
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.remove, size: 18, color: _primaryDark),
                        onPressed: () {
                          if (tempQuantity > 1) {
                            setDialogState(() {
                              tempQuantity--;
                              _qtyController.text = tempQuantity.toString();
                            });
                          }
                        },
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),

                    SizedBox(width: 8),

                    // TextField untuk input manual
                    Container(
                      width: 80,
                      height: 45,
                      decoration: BoxDecoration(
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _qtyFocusNode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        onChanged: (value) {
                          // Validasi input angka
                          if (value.isEmpty) {
                            setDialogState(() {
                              tempQuantity = 0;
                            });
                          } else {
                            final newQty = int.tryParse(value);
                            if (newQty != null && newQty > 0) {
                              setDialogState(() {
                                tempQuantity = newQty;
                              });
                            }
                          }
                        },
                      ),
                    ),

                    SizedBox(width: 8),

                    // Tombol Plus
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, size: 18, color: _primaryDark),
                        onPressed: () {
                          setDialogState(() {
                            tempQuantity++;
                            _qtyController.text = tempQuantity.toString();
                          });
                        },
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                  ],
                ),

                // SizedBox(height: 8),
                //
                // // Tombol shortcut untuk quantity umum (opsional)
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     _buildQuickQtyButton('1', setDialogState, _qtyController),
                //     SizedBox(width: 6),
                //     _buildQuickQtyButton('2', setDialogState, _qtyController),
                //     SizedBox(width: 6),
                //     _buildQuickQtyButton('5', setDialogState, _qtyController),
                //     SizedBox(width: 6),
                //     _buildQuickQtyButton('10', setDialogState, _qtyController),
                //   ],
                // ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 11, color: _textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validasi final sebelum simpan
                  if (tempQuantity <= 0) {
                    _removeFromCart(index);
                  } else {
                    setState(() {
                      _cartItems[index].quantity = tempQuantity;
                    });
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Simpan', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

// Fungsi helper untuk tombol quick quantity
  Widget _buildQuickQtyButton(String qty, StateSetter setDialogState, TextEditingController controller) {
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          controller.text = qty;
          // Update tempQuantity juga (tapi tempQuantity ada di luar scope,
          // perlu di-handle di fungsi utama)
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _bgLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _borderColor),
        ),
        child: Text(
          qty,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ),
    );
  }

  void _toggleScanner() {
    setState(() {
      _scannerActive = !_scannerActive;
      if (!_scannerActive) _barcodeBuffer = '';
    });
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
    _filterProducts();
  }

  void _addToCart(Product product) {
    final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);

    double discountPercent = 0;
    double discountRp = 0;
    String discountType = 'none';

    if (product.category != null) {
      if (_categoryDiscountRp.containsKey(product.category!)) {
        discountRp = _categoryDiscountRp[product.category!]!;
        discountType = 'rp';
      } else if (_categoryDiscountPercent.containsKey(product.category!)) {
        discountPercent = _categoryDiscountPercent[product.category!]!;
        discountType = 'percent';
      }
    }

    if (_selectedPromo?['disc_nama'] != 'NONE' && _selectedPromo?['disc_persen'] != null) {
      discountPercent = double.parse(_selectedPromo!['disc_persen'].toString());
      discountType = 'percent';
      discountRp = 0;
    }

    if (existingIndex >= 0) {
      setState(() {
        _cartItems[existingIndex].quantity += 1;
        _cartItems[existingIndex].discount = discountPercent;
        _cartItems[existingIndex].discountRp = discountRp;
        _cartItems[existingIndex].discountType = discountType;
      });
    } else {
      setState(() {
        _cartItems.add(OrderItem(
          product: product,
          quantity: 1,
          discount: discountPercent,
          discountRp: discountRp,
          discountType: discountType,
          notes: '',
        ));
      });
    }

    _showSnackbar('${product.name} ditambahkan', _accentMint);
  }

  void _updateCartDiscounts() {
    if (_selectedPromo?['disc_nama'] == 'NONE') {
      setState(() {
        for (var item in _cartItems) {
          final product = item.product;
          double discountPercent = 0;
          double discountRp = 0;
          String discountType = 'none';

          if (product.category != null) {
            if (_categoryDiscountRp.containsKey(product.category!)) {
              discountRp = _categoryDiscountRp[product.category!]!;
              discountType = 'rp';
            } else if (_categoryDiscountPercent.containsKey(product.category!)) {
              discountPercent = _categoryDiscountPercent[product.category!]!;
              discountType = 'percent';
            }
          }

          item.discount = discountPercent;
          item.discountRp = discountRp;
          item.discountType = discountType;
        }
      });
    } else if (_selectedPromo?['disc_persen'] != null) {
      final promoDiscount = double.parse(_selectedPromo!['disc_persen'].toString());
      setState(() {
        for (var item in _cartItems) {
          item.discount = promoDiscount;
          item.discountRp = 0;
          item.discountType = 'percent';
        }
      });
    }
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }

    setState(() {
      _cartItems[index].quantity = newQuantity;
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      final removedItem = _cartItems.removeAt(index);
      _showSnackbar('${removedItem.product.name} dihapus', _accentGold);
    });
  }

  void _clearCart() {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kosongkan Keranjang?', style: GoogleFonts.montserrat(color: _textPrimary)),
        content: Text('Apakah Anda yakin ingin menghapus semua item di keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.montserrat(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _cartItems.clear());
              Navigator.pop(context);
              _showSnackbar('Keranjang dikosongkan', _accentMint);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accentCoral),
            child: Text('Hapus Semua', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _proceedToPayment() async {
    if (_selectedCustomer == null) {
      _showSnackbar('Pilih customer terlebih dahulu', _accentCoral);
      return;
    }

    if (_cartItems.isEmpty) {
      _showSnackbar('Keranjang kosong', _accentCoral);
      return;
    }

    final promoName = _selectedPromo?['disc_nama'] ?? 'NONE';

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          customer: _selectedCustomer!,
          orderItems: _cartItems,
          promoName: promoName,
        ),
      ),
    );

    if (result == 'completed') {
      setState(() => _cartItems.clear());
    }
  }

  void _showCustomerSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (context) => _buildCustomerSelectorSheet(),
    );
  }

  Widget _buildCustomerSelectorSheet() {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primaryLight],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 24, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pilih Customer',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
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
                decoration: InputDecoration(
                  hintText: 'Cari customer...',
                  prefixIcon: Icon(Icons.search, color: _textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 16),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                final isSelected = _selectedCustomer?.id == customer.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? _primaryDark : _borderColor,
                    child: Text(
                      customer.name.substring(0, 1),
                      style: GoogleFonts.montserrat(
                        color: isSelected ? Colors.white : _textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: GoogleFonts.montserrat(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _primaryDark : _textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: _primaryDark) : null,
                  onTap: () {
                    setState(() => _selectedCustomer = customer);
                    Navigator.pop(context);
                    _showSnackbar('Customer: ${customer.name}', _accentMint);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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

  Future<void> _onRefresh() async {
    try {
      await _loadData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.getProductsOptimized();
      await _loadCategoryDiscounts();

      final categorySet = <String>{'Semua'};
      for (var product in products) {
        if (product.category != null && product.category!.isNotEmpty) {
          categorySet.add(product.category!);
        }
      }

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = categorySet.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Gagal memuat data: $e', _accentCoral);
    }
  }

  Future<void> _loadCategoryDiscounts() async {
    try {
      final categories = await CategoryService.getCategories();
      _categoryDiscountPercent.clear();
      _categoryDiscountRp.clear();

      for (var category in categories) {
        final categoryName = category['ct_nama']?.toString();
        final discountPercent = double.tryParse(category['ct_disc']?.toString() ?? '0') ?? 0.0;
        final discountRp = double.tryParse(category['ct_disc_rp']?.toString() ?? '0') ?? 0.0;

        if (categoryName != null && categoryName.isNotEmpty) {
          if (discountRp > 0) {
            _categoryDiscountRp[categoryName] = discountRp;
          } else if (discountPercent > 0) {
            _categoryDiscountPercent[categoryName] = discountPercent;
          }
        }
      }
    } catch (e) {
      print('Error loading category discounts: $e');
    }
  }

  Future<void> _loadPromos() async {
    setState(() => _loadingPromos = true);
    try {
      final promos = await DiscountService.getPromos();
      setState(() {
        _promos = promos;
        _selectedPromo = promos.firstWhere(
                (p) => p['disc_nama'] == 'NONE',
            orElse: () => promos.isNotEmpty ? promos[0] : {'disc_id': 0, 'disc_nama': 'NONE', 'disc_persen': 0}
        );
      });
    } catch (e) {
      setState(() {
        _selectedPromo = {'disc_id': 0, 'disc_nama': 'NONE', 'disc_persen': 0};
        _promos = [_selectedPromo!];
      });
    } finally {
      setState(() => _loadingPromos = false);
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final matchesSearch = query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            (product.category?.toLowerCase().contains(query) ?? false);
        final matchesCategory = _selectedCategory == 'Semua' ||
            product.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _setDefaultCustomer() {
    setState(() {
      _selectedCustomer = _customers.firstWhere(
            (customer) => customer.name == 'UMUM',
        orElse: () => _customers.first,
      );
    });
  }

  void _goToPrinterSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrinterConfigurationScreen()),
    );
    if (result == true) _checkPrinterStatus();
  }

  Future<void> _setupDefaultPrinter() async {
    try {
      await PrinterConfigService.setDefault58mm();
      final configService = PrinterConfigService();
      configService.updateDefaultTo58mm();
    } catch (e) {
      print('Printer setup error: $e');
    }
  }

  Future<void> _checkPrinterStatus() async {
    try {
      final bluetoothService = BluetoothService();
      final connected = await bluetoothService.isDeviceConnected();
      setState(() => _printerConnected = connected);

      if (connected && bluetoothService.connectedDevice != null) {
        final device = bluetoothService.connectedDevice!;
        setState(() {
          _connectedPrinterName = device.platformName.isNotEmpty
              ? device.platformName
              : device.remoteId.toString();
        });
      }
    } catch (e) {
      print('Check printer error: $e');
    }
  }

  void _setupBarcodeScanner() async {
    try {
      _barcodeSubscription = _printerService.barcodeStream.listen(
            (barcode) => _handleBarcodeScan(barcode),
        onError: (error) => print('Barcode stream error: $error'),
      );

      if (_printerService.isConnected) {
        await _printerService.enableScanner();
        setState(() => _isScannerEnabled = true);
      }
    } catch (e) {
      print('Scanner setup error: $e');
    }
  }

  void _handleBarcodeScan(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    Product? foundProduct;
    for (var product in _products) {
      if (product.id == cleanBarcode) {
        foundProduct = product;
        break;
      }
    }

    if (foundProduct != null) {
      _addToCart(foundProduct);
      _showScanFeedback(foundProduct.name);
    } else {
      _showScanErrorFeedback('Produk tidak ditemukan');
    }
  }

  void _showScanFeedback(String productName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $productName ditambahkan'),
        backgroundColor: _accentMint,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showScanErrorFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentCoral,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openTutupKasirForm() async {
    // Cek apakah ada item di keranjang
    if (_cartItems.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Ada Item di Keranjang',
            style: GoogleFonts.montserrat(color: _textPrimary),
          ),
          content: Text(
            'Ada ${_cartItems.length} item di keranjang. Kosongkan dulu?',
            style: GoogleFonts.montserrat(color: _textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Batal',
                style: GoogleFonts.montserrat(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _cartItems.clear());
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
              ),
              child: Text(
                'Kosongkan & Lanjut',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) return; // User membatalkan
    }

    // ✅ BUKA HALAMAN TUTUP KASIR
    try {
      final result = await Navigator.pushNamed(
        context,
        AppRoutes.tutupKasir, // Pastikan route ini terdaftar di AppRoutes
      );

      if (result == true) {
        _showSnackbar('Tutup kasir berhasil', _accentMint);
      }
    } catch (e) {
      _showSnackbar('Gagal membuka form tutup kasir: $e', _accentCoral);
    }
  }

  void _openUangMukaList() async {
    try {
      await Navigator.pushNamed(context, AppRoutes.uangMukaList);
    } catch (e) {
      _showSnackbar('Gagal membuka menu Uang Muka', _accentCoral);
    }
  }

  void _showReprintModal() async {
    final selectedOrder = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReprintOrderDialog(),
    );

    if (selectedOrder != null) {
      await _printOrderReceipt(selectedOrder);
    }
  }

  Future<void> _printOrderReceipt(Map<String, dynamic> order) async {
    try {
      final orderId = order['nomor']?.toString() ?? '';
      final customerName = order['nama']?.toString() ?? order['jl_jeniscustomer']?.toString() ?? 'Umum';
      final createdAt = order['tim']?.toString() ?? DateTime.now().toIso8601String();
      final cashier = order['jl_userkasir']?.toString() ?? 'ADMIN';

      final itemsResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/${orderId}/items'),
        headers: await _getHeaders(),
      );

      List<Map<String, dynamic>> items = [];
      if (itemsResponse.statusCode == 200) {
        final itemsData = jsonDecode(itemsResponse.body);
        items = List<Map<String, dynamic>>.from(itemsData['data']);
      }

      final formattedItems = items.map((item) {
        return {
          'product_name': item['product_name'] ?? item['jld_item']?.toString() ?? 'Unknown',
          'quantity': int.tryParse(item['jld_qty']?.toString() ?? '1') ?? 1,
          'price': double.tryParse(item['jld_price']?.toString() ?? '0') ?? 0,
          'total': (double.tryParse(item['jld_price']?.toString() ?? '0') ?? 0) *
              (int.tryParse(item['jld_qty']?.toString() ?? '1') ?? 1),
          'discount': double.tryParse(item['jld_disc']?.toString() ?? '0') ?? 0,
        };
      }).toList();

      final subtotal = items.fold(0.0, (sum, item) {
        final price = double.tryParse(item['jld_price']?.toString() ?? '0') ?? 0;
        final qty = int.tryParse(item['jld_qty']?.toString() ?? '1') ?? 1;
        return sum + (price * qty);
      });

      final orderDiscount = double.tryParse(order['jl_discount']?.toString() ?? '0') ?? 0;
      final cashPayment = double.tryParse(order['jl_cash']?.toString() ?? '0') ?? 0;
      final cardPayment = double.tryParse(order['jl_card']?.toString() ?? '0') ?? 0;
      final dpPayment = double.tryParse(order['jl_dp']?.toString() ?? '0') ?? 0;
      final otherPayment = double.tryParse(order['jl_othervalue']?.toString() ?? '0') ?? 0;
      final grandTotal = cashPayment + cardPayment + dpPayment + otherPayment;
      final change = double.tryParse(order['jl_kembali']?.toString() ?? '0') ?? 0;

      final List<Map<String, dynamic>> paymentMethods = [];

      if (cashPayment > 0) paymentMethods.add({'type': 'cash', 'amount': cashPayment});
      if (cardPayment > 0) paymentMethods.add({'type': 'edc', 'subType': 'CARD', 'amount': cardPayment});
      if (dpPayment > 0) {
        final dpReference = order['jl_dp_nomor']?.toString() ?? '';
        paymentMethods.add({
          'type': 'dp',
          'amount': dpPayment,
          'reference': dpReference.isNotEmpty ? dpReference : 'DP',
        });
      }
      if (otherPayment > 0) {
        final piutangType = order['jl_other']?.toString() ?? 'PIUTANG';
        paymentMethods.add({'type': 'piutang', 'subType': piutangType, 'amount': otherPayment});
      }

      final success = await UniversalPrinterService().printReceipt(
        orderId: orderId,
        customerName: customerName,
        items: formattedItems,
        subtotal: subtotal,
        orderDiscountAmount: orderDiscount,
        grandTotal: grandTotal,
        paidAmount: grandTotal,
        change: change,
        cashierName: cashier,
        createdAt: DateTime.parse(createdAt),
        paymentMethods: paymentMethods,
      );

      if (success) {
        _showSnackbar('Struk berhasil dicetak ulang', _accentMint);
      } else {
        _showSnackbar('Gagal mencetak struk', _accentCoral);
      }
    } catch (e) {
      _showSnackbar('Error mencetak ulang: ${e.toString()}', _accentCoral);
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

class ReprintOrderDialog extends StatefulWidget {
  @override
  State<ReprintOrderDialog> createState() => _ReprintOrderDialogState();
}

class _ReprintOrderDialogState extends State<ReprintOrderDialog> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = false;

  final Color _primaryDark = Color(0xFF2C3E50);
  final Color _accentMint = Color(0xFF06D6A0);
  final Color _accentSky = Color(0xFF4CC9F0);
  final Color _bgLight = Color(0xFFFAFAFA);
  final Color _bgCard = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1A202C);
  final Color _textSecondary = Color(0xFF718096);
  final Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await SessionManager.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/reprint?date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data['data']);
          _filteredOrders = _orders;
        });
      } else {
        setState(() {
          _orders = [];
          _filteredOrders = [];
        });
      }
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _orders = [];
        _filteredOrders = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterOrders(String query) {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final nomor = order['nomor']?.toString().toLowerCase() ?? '';
        final nama = order['nama']?.toString().toLowerCase() ?? '';
        final customer = order['jl_jeniscustomer']?.toString().toLowerCase() ?? '';
        return nomor.contains(query.toLowerCase()) ||
            nama.contains(query.toLowerCase()) ||
            customer.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _bgCard,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _bgCard,
      child: Container(
        constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, Color(0xFF34495E)],
                ),
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
                    ),
                    child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cetak Ulang Struk',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pilih transaksi untuk dicetak ulang',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: _textSecondary),
                            SizedBox(width: 10),
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _primaryDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                      onPressed: _loadOrders,
                      tooltip: 'Refresh',
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nomor, nama, atau customer...',
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: _textSecondary),
                    prefixIcon: Icon(Icons.search, size: 18, color: _textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.montserrat(fontSize: 12),
                  onChanged: _filterOrders,
                ),
              ),
            ),

            SizedBox(height: 8),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Total: ',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                  Text(
                    '${_filteredOrders.length} transaksi',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryDark,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _primaryDark),
                    SizedBox(height: 12),
                    Text(
                      'Memuat transaksi...',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              )
                  : _filteredOrders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: _borderColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada transaksi\nuntuk tanggal ini'
                          : 'Transaksi tidak ditemukan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  final nomor = order['nomor']?.toString() ?? '-';
                  final customer = order['jl_jeniscustomer']?.toString() ?? 'Umum';
                  final cashier = order['jl_userkasir']?.toString() ?? 'ADMIN';

                  final cash = double.tryParse(order['jl_cash']?.toString() ?? '0') ?? 0;
                  final card = double.tryParse(order['jl_card']?.toString() ?? '0') ?? 0;
                  final dp = double.tryParse(order['jl_dp']?.toString() ?? '0') ?? 0;
                  final other = double.tryParse(order['jl_othervalue']?.toString() ?? '0') ?? 0;
                  final total = cash + card + dp + other;

                  String formattedTime = '';
                  try {
                    final dateTime = order['tim']?.toString() ?? '';
                    if (dateTime.isNotEmpty) {
                      final parsedDate = DateTime.parse(dateTime);
                      formattedTime = DateFormat('HH:mm').format(parsedDate);
                    }
                  } catch (e) {
                    formattedTime = '-';
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, order),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _primaryDark.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.receipt,
                                  size: 18,
                                  color: _primaryDark,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nomor,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _bgLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: _borderColor),
                                          ),
                                          child: Text(
                                            formattedTime,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      customer,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: _textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _bgLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cashier,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 9,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        if (cash > 0)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _accentMint.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: _accentMint.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              'CASH',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: _accentMint,
                                              ),
                                            ),
                                          ),
                                        if (card > 0)
                                          Container(
                                            margin: EdgeInsets.only(left: 4),
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _accentSky.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: _accentSky.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              'EDC',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: _accentSky,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(total),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryDark,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _primaryDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.print, size: 10, color: _primaryDark),
                                        SizedBox(width: 4),
                                        Text(
                                          'CETAK',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: _primaryDark,
                                          ),
                                        ),
                                      ],
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _borderColor)),
                color: _bgCard,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredOrders.length} transaksi ditemukan',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: BorderSide(color: _borderColor),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text('Tutup'),
                      ),
                      SizedBox(width: 8),
                      if (_filteredOrders.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            if (_filteredOrders.isNotEmpty) {
                              Navigator.pop(context, _filteredOrders.first);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryDark,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Cetak Teratas'),
                        ),
                    ],
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