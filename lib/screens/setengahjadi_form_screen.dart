import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/setengahjadi_service.dart';
import '../models/setengahjadi.dart';
import '../widgets/base_layout.dart';

class SetengahJadiFormScreen extends StatefulWidget {
  final SetengahJadi? setengahJadi;
  final VoidCallback onSetengahJadiSaved;

  const SetengahJadiFormScreen({
    super.key,
    this.setengahJadi,
    required this.onSetengahJadiSaved,
  });

  @override
  State<SetengahJadiFormScreen> createState() => _SetengahJadiFormScreenState();
}

class _SetengahJadiFormScreenState extends State<SetengahJadiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.setengahJadi != null) {
      _namaController.text = widget.setengahJadi!.stjNama;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
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

  Future<void> _saveSetengahJadi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nama = _namaController.text.trim();
      final result = widget.setengahJadi == null
          ? await SetengahJadiService.addSetengahJadi(nama: nama)
          : await SetengahJadiService.updateSetengahJadi(
        stjId: widget.setengahJadi!.stjId.toString(),
        nama: nama,
      );

      if (result['success']) {
        _showSnackbar(result['message'], Colors.green);
        widget.onSetengahJadiSaved();
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
    final isEdit = widget.setengahJadi != null;

    return BaseLayout(
      title: isEdit ? 'Edit Setengah Jadi' : 'Tambah Setengah Jadi',
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
              // ========== FORM CARD - COMPACT ==========
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
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
                    Text(
                      'Nama Item Setengah Jadi',
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
                        controller: _namaController,
                        autofocus: true,
                        style: GoogleFonts.montserrat(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama setengah jadi...',
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

                    // Info tambahan untuk edit mode
                    if (isEdit && widget.setengahJadi != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID: ${widget.setengahJadi!.stjId}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Stok saat ini: ${widget.setengahJadi!.stjStock}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: widget.setengahJadi!.stjStock <= 5
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // ========== SAVE BUTTON ==========
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveSetengahJadi,
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
                    isEdit ? 'UPDATE SETENGAH JADI' : 'TAMBAH SETENGAH JADI',
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