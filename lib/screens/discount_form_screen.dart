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
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
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
        _showSnackbar(result['message'], Colors.green);
        widget.onDiscountSaved();
        Navigator.pop(context);
      } else {
        _showSnackbar(result['message'], Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.discount != null;

    return BaseLayout(
      title: isEdit ? 'Edit Discount' : 'Tambah Discount',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Discount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nama Discount',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: TextFormField(
                            controller: _nameController,
                            autofocus: true,
                            style: GoogleFonts.montserrat(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Contoh: PROMO DISC 30%, GRABFOOD, dll.',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama discount harus diisi';
                              }
                              return null;
                            },
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: TextFormField(
                            controller: _percentageController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.montserrat(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '0 - 100',
                              hintStyle: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              suffixText: '%',
                              suffixStyle: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
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
                      strokeWidth: 2.5,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6A918),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
}