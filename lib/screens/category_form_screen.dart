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

  String _selectedPrinterName = 'DRINK';
  String _discountType = 'percent';
  bool _isPrint = false;
  bool _isLoading = false;

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
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(message, style: GoogleFonts.montserrat(fontSize: 12)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
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
        _showSnackbar(result['message'], Colors.green);
        widget.onCategorySaved();
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
              color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Color(0xFFF6A918).withOpacity(0.1) : Colors.white,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade400,
                    width: isSelected ? 5 : 1.5,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Color(0xFFF6A918) : Colors.grey.shade700,
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

    return BaseLayout(
      title: isEdit ? 'Edit Kategori' : 'Tambah Kategori',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      // autoManageSidebar: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
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
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama Kategori',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.centerLeft,
                                  child: TextFormField(
                                    controller: _nameController,
                                    autofocus: true,
                                    style: GoogleFonts.montserrat(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan nama kategori...',
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
                                        return 'Nama harus diisi';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jenis Printer',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPrinterRadio(
                                        value: 'DRINK',
                                        label: 'MINUMAN',
                                        icon: Icons.local_drink_rounded,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: _buildPrinterRadio(
                                        value: 'FOOD',
                                        label: 'MAKANAN',
                                        icon: Icons.restaurant_rounded,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _isPrint ? Color(0xFFF6A918) : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _isPrint ? Color(0xFFF6A918) : Colors.grey.shade400,
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
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Aktifkan Print',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Centang jika kategori ini akan dicetak',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _isPrint = !_isPrint);
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isPrint ? Colors.green.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _isPrint
                                              ? Colors.green.shade200
                                              : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _isPrint ? 'ON' : 'OFF',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: _isPrint
                                              ? Colors.green.shade700
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jenis Diskon',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildDiscountTypeRadio('percent', 'Persen (%)'),
                                    SizedBox(width: 8),
                                    _buildDiscountTypeRadio('rp', 'Rupiah (Rp)'),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            if (_discountType == 'percent') ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diskon (%)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.centerLeft,
                                    child: TextFormField(
                                      controller: _discountController,
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
                                ],
                              ),
                            ] else ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diskon (Rupiah)',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.centerLeft,
                                    child: TextFormField(
                                      controller: _discountRpController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.montserrat(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        prefixText: 'Rp ',
                                        prefixStyle: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
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
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    Spacer(),

                    Container(
                      margin: EdgeInsets.only(
                        top: 16,
                        bottom: MediaQuery.of(context).viewInsets.bottom > 0
                            ? MediaQuery.of(context).viewInsets.bottom + 8
                            : 8,
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF6A918),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
        },
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
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 1),
              )
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 2,
                offset: Offset(0, 1),
              )
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      value == 'DRINK' ? 'Untuk minuman' : 'Untuk makanan',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: Colors.grey.shade600,
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