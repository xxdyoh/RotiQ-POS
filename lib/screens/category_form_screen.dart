import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/category_service.dart';
import '../widgets/base_layout.dart';

class CategoryFormScreen extends StatefulWidget {
  final Map<String, dynamic>? category;
  final VoidCallback onCategorySaved;

  const CategoryFormScreen({
    super.key,
    this.category,
    required this.onCategorySaved,
  });

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _discountController = TextEditingController();
  final _discountRpController = TextEditingController();

  // Warna konsisten dengan ItemFormScreen
  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _bgCard = const Color(0xFFFFFFFF);
  final Color _textPrimary = const Color(0xFF1A202C);
  final Color _textSecondary = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  String _selectedPrinterName = 'DRINK';
  String _discountType = 'percent';
  bool _isPrint = false;
  bool _isLoading = false;

  // Warna untuk printer type
  final Color _drinkColor = const Color(0xFF00ACC1); // Cyan
  final Color _foodColor = const Color(0xFFFF7043); // Orange/Deep Orange

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['ct_nama']?.toString() ?? '';
      _discountController.text = (widget.category!['ct_disc']?.toString() ?? '0');
      _selectedPrinterName = widget.category!['ct_PrinterName']?.toString() ?? 'DRINK';
      _isPrint = widget.category!['ct_isprint'] == 1;

      final discountPercent = double.tryParse(widget.category!['ct_disc']?.toString() ?? '0') ?? 0;
      final discountRp = double.tryParse(widget.category!['ct_disc_rp']?.toString() ?? '0') ?? 0;

      if (discountRp > 0) {
        _discountType = 'rp';
        _discountRpController.text = discountRp.toString();
      } else {
        _discountType = 'percent';
        _discountController.text = discountPercent.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    _discountRpController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _accentMint ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: GoogleFonts.montserrat(fontSize: 12))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final discountPercent = _discountType == 'percent'
          ? double.tryParse(_discountController.text) ?? 0
          : 0;
      final discountRp = _discountType == 'rp'
          ? double.tryParse(_discountRpController.text) ?? 0
          : 0;

      final result = widget.category == null
          ? await CategoryService.addCategory(
        name: name,
        printerName: _selectedPrinterName,
        isPrint: _isPrint,
        discount: discountPercent.toDouble(),
        discountRp: discountRp.toDouble(),
        discountType: _discountType,
      )
          : await CategoryService.updateCategory(
        categoryId: widget.category!['ct_id'].toString(),
        name: name,
        printerName: _selectedPrinterName,
        isPrint: _isPrint,
        discount: discountPercent.toDouble(),
        discountRp: discountRp.toDouble(),
        discountType: _discountType,
      );

      if (result['success']) {
        _showSnackbar(result['message'], _accentMint);
        widget.onCategorySaved();
        Navigator.pop(context);
      } else {
        _showSnackbar(result['message'], _accentCoral);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', _accentCoral);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDiscountTypeRadio(String value, String label) {
    final isSelected = _discountType == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _discountType = value);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? _accentGold : _borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? _accentGold.withOpacity(0.1) : _bgCard,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _accentGold : _textSecondary.withOpacity(0.5),
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _accentGold : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BaseLayout(
      title: isEdit ? 'Edit Kategori' : 'Tambah Kategori',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Container(
        color: _bgLight,
        child: Column(
          children: [
            // Header dengan gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primaryLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note : Icons.add_box_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Kategori' : 'Tambah Kategori Baru',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Card Informasi Kategori
                      Container(
                        decoration: BoxDecoration(
                          color: _bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                border: Border(bottom: BorderSide(color: _borderColor)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _primaryDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.category,
                                      size: 14,
                                      color: _primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Informasi Kategori',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Nama Kategori
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nama Kategori',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _bgLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: Center(
                                          child: TextFormField(
                                            controller: _nameController,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: _textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Masukkan nama kategori',
                                              hintStyle: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                color: _textSecondary.withOpacity(0.5),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                              isDense: true,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Nama kategori harus diisi';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Jenis Printer
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jenis Printer',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildPrinterRadio(
                                              value: 'DRINK',
                                              label: 'MINUMAN',
                                              icon: Icons.local_drink_rounded,
                                              color: _drinkColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildPrinterRadio(
                                              value: 'FOOD',
                                              label: 'MAKANAN',
                                              icon: Icons.restaurant_rounded,
                                              color: _foodColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Aktifkan Print
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _bgLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setState(() => _isPrint = !_isPrint);
                                          },
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: _isPrint ? _accentGold : _bgCard,
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: _isPrint ? _accentGold : _borderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: _isPrint
                                                ? Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Aktifkan Print',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Centang jika kategori ini akan dicetak',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 9,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _isPrint ? _accentMint.withOpacity(0.1) : _bgLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: _isPrint ? _accentMint.withOpacity(0.5) : _borderColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _isPrint ? 'ON' : 'OFF',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: _isPrint ? _accentMint : _textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Jenis Diskon
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jenis Diskon',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildDiscountTypeRadio('percent', 'Persen (%)'),
                                          const SizedBox(width: 8),
                                          _buildDiscountTypeRadio('rp', 'Rupiah (Rp)'),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Input Diskon berdasarkan jenis
                                  if (_discountType == 'percent') ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Diskon (%)',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _bgLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _borderColor),
                                          ),
                                          child: Center(
                                            child: TextFormField(
                                              controller: _discountController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: _textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '0 - 100',
                                                hintStyle: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: _textSecondary.withOpacity(0.5),
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                                isDense: true,
                                                suffixText: '%',
                                                suffixStyle: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (_discountType == 'percent') {
                                                  if (value == null || value.trim().isEmpty) {
                                                    return 'Diskon harus diisi';
                                                  }
                                                  final discount = double.tryParse(value);
                                                  if (discount == null || discount < 0 || discount > 100) {
                                                    return 'Diskon harus antara 0-100';
                                                  }
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Diskon (Rupiah)',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _bgLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _borderColor),
                                          ),
                                          child: Center(
                                            child: TextFormField(
                                              controller: _discountRpController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: _textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                hintStyle: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: _textSecondary.withOpacity(0.5),
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                                isDense: true,
                                                prefixText: 'Rp ',
                                                prefixStyle: GoogleFonts.montserrat(
                                                  fontSize: 11,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (_discountType == 'rp') {
                                                  if (value == null || value.trim().isEmpty) {
                                                    return 'Diskon Rp harus diisi';
                                                  }
                                                  final rp = double.tryParse(value);
                                                  if (rp == null || rp < 0) {
                                                    return 'Tidak boleh minus';
                                                  }
                                                }
                                                return null;
                                              },
                                            ),
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
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgCard,
                border: Border(top: BorderSide(color: _borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveCategory,
                  icon: _isLoading
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    isEdit ? Icons.edit : Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isEdit ? 'UPDATE KATEGORI' : 'TAMBAH KATEGORI',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterRadio({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedPrinterName == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedPrinterName = value);
        },
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : _borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? color.withOpacity(0.08) : _bgCard,
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? color : _bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? color : _borderColor,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : _textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? color : _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value == 'DRINK' ? 'Untuk minuman' : 'Untuk makanan',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}