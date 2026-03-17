import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/discount_service.dart';
import '../widgets/base_layout.dart';

class DiscountFormScreen extends StatefulWidget {
  final Map<String, dynamic>? discount;
  final VoidCallback onDiscountSaved;

  const DiscountFormScreen({
    super.key,
    this.discount,
    required this.onDiscountSaved,
  });

  @override
  State<DiscountFormScreen> createState() => _DiscountFormScreenState();
}

class _DiscountFormScreenState extends State<DiscountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _percentageController = TextEditingController();

  // Warna konsisten dengan screen lainnya
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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.discount != null) {
      _nameController.text = widget.discount!['disc_nama']?.toString() ?? '';
      _percentageController.text = (widget.discount!['disc_persen']?.toString() ?? '0');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentageController.dispose();
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

  Future<void> _saveDiscount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final percentage = double.tryParse(_percentageController.text) ?? 0;

      final result = widget.discount == null
          ? await DiscountService.addDiscount(
        name: name,
        percentage: percentage,
      )
          : await DiscountService.updateDiscount(
        discountId: widget.discount!['disc_id'].toString(),
        name: name,
        percentage: percentage,
      );

      if (result['success']) {
        _showSnackbar(result['message'], _accentMint);
        widget.onDiscountSaved();
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.discount != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return BaseLayout(
      title: isEdit ? 'Edit Discount' : 'Tambah Discount',
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
                    isEdit ? 'Edit Discount' : 'Tambah Discount Baru',
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
                      // Card Informasi Discount
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
                                      color: _accentGold.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.discount_rounded,
                                      size: 14,
                                      color: _accentGold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Informasi Discount',
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
                                  // Nama Discount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nama Discount',
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
                                              hintText: 'Contoh: PROMO DISC 30%, GRABFOOD, dll.',
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
                                                return 'Nama discount harus diisi';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Persentase Discount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Persentase Discount (%)',
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
                                            controller: _percentageController,
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
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Persentase discount harus diisi';
                                              }
                                              final percentage = double.tryParse(value);
                                              if (percentage == null || percentage < 0 || percentage > 100) {
                                                return 'Persentase harus angka antara 0-100';
                                              }
                                              return null;
                                            },
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
                  onPressed: _isLoading ? null : _saveDiscount,
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
                    isEdit ? 'UPDATE DISCOUNT' : 'TAMBAH DISCOUNT',
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
}