import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/uangmuka_service.dart';
import '../models/uangmuka_model.dart';
import '../widgets/base_layout.dart';
import '../services/universal_printer_service.dart';

class UangMukaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? uangMuka;
  final VoidCallback onUangMukaSaved;

  const UangMukaFormScreen({
    super.key,
    this.uangMuka,
    required this.onUangMukaSaved,
  });

  @override
  State<UangMukaFormScreen> createState() => _UangMukaFormScreenState();
}

class _UangMukaFormScreenState extends State<UangMukaFormScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _nilaiController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedJenisBayar = 'Cash';
  bool _isSaving = false;

  String? _nomorUangMuka;

  final List<String> _jenisBayarOptions = ['Cash', 'Bank'];

  @override
  void initState() {
    super.initState();

    if (widget.uangMuka != null) {
      _nomorUangMuka = widget.uangMuka!['um_nomor'];
      _selectedDate = DateTime.parse(widget.uangMuka!['um_tanggal']);
      _customerController.text = widget.uangMuka!['um_customer'] ?? '';
      _nilaiController.text = _formatNumberForInput(widget.uangMuka!['um_nilai'] ?? 0);
      _selectedJenisBayar = widget.uangMuka!['um_jenisbayar'] ?? 'Cash';
      _keteranganController.text = widget.uangMuka!['um_keterangan'] ?? '';
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _nilaiController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  String _formatNumberForInput(dynamic value) {
    if (value == null) return '';
    final num = value is int ? value : (value is double ? value.toInt() : 0);
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(num);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFF6A918),
              onPrimary: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _saveUangMuka() async {
    if (_customerController.text.trim().isEmpty) {
      _showErrorSnackbar('Customer harus diisi!');
      return;
    }

    if (_nilaiController.text.isEmpty) {
      _showErrorSnackbar('Nilai harus diisi!');
      return;
    }

    final cleanValue = _nilaiController.text.replaceAll('.', '');
    final nilai = double.tryParse(cleanValue) ?? 0;
    if (nilai <= 0) {
      _showErrorSnackbar('Nilai harus lebih dari 0!');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final result = widget.uangMuka == null
          ? await UangMukaService.createUangMuka(
        tanggal: tanggalStr,
        customer: _customerController.text.trim(),
        nilai: nilai,
        jenisBayar: _selectedJenisBayar,
        keterangan: _keteranganController.text.trim(),
      )
          : await UangMukaService.updateUangMuka(
        nomor: _nomorUangMuka!,
        tanggal: tanggalStr,
        customer: _customerController.text.trim(),
        nilai: nilai,
        jenisBayar: _selectedJenisBayar,
        keterangan: _keteranganController.text.trim(),
      );

      if (result['success']) {
        _showSuccessSnackbar(result['message']);

        // AUTO PRINT setelah berhasil simpan (khusus untuk tambah baru)
        if (widget.uangMuka == null && result['data'] != null) {
          final nomorBaru = result['data']['nomor']?.toString() ?? '';
          await _autoPrintUangMuka(
            nomor: nomorBaru,
            tanggal: _selectedDate,
            customer: _customerController.text.trim(),
            nilai: nilai,
            jenisBayar: _selectedJenisBayar,
            keterangan: _keteranganController.text.trim(),
          );
        }

        widget.onUangMukaSaved();
        Navigator.pop(context);
      } else {
        _showErrorSnackbar(result['message']);
      }
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _autoPrintUangMuka({
    required String nomor,
    required DateTime tanggal,
    required String customer,
    required double nilai,
    required String jenisBayar,
    String? keterangan,
  }) async {
    try {
      await Future.delayed(Duration(milliseconds: 500)); // Tunggu sebentar

      await UniversalPrinterService().printUangMukaReceipt(
        nomor: nomor,
        tanggal: tanggal,
        customer: customer,
        nilai: nilai,
        jenisBayar: jenisBayar,
        keterangan: keterangan,
        isRealisasi: false,
      );

      print('✅ Auto-print uang muka berhasil: $nomor');
    } catch (e) {
      print('⚠️ Gagal auto-print uang muka: $e');
      // Jangan tampilkan error ke user, cukup log saja
    }
  }

  void _onNilaiChanged(String value) {
    if (value.isNotEmpty) {
      final cleanValue = value.replaceAll('.', '');
      final number = int.tryParse(cleanValue) ?? 0;
      if (number > 0) {
        final formatter = NumberFormat('#,###', 'id_ID');
        final formatted = formatter.format(number);

        _nilaiController.value = _nilaiController.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.uangMuka != null;

    return BaseLayout( // ← GUNAKAN BASELAYOUT
      title: isEdit ? 'Edit Uang Muka' : 'Tambah Uang Muka',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== COMPACT FORM ==========
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Form
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Nomor (readonly jika edit)
                          if (_nomorUangMuka != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.confirmation_number, size: 14, color: Colors.grey.shade600),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _nomorUangMuka!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                          ],

                          // Tanggal
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _selectDate(context),
                                  child: Container(
                                    height: 36,
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 14, color: Color(0xFFF6A918)),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd/MM/yy').format(_selectedDate),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Customer
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _customerController,
                                  style: GoogleFonts.montserrat(fontSize: 11),
                                  decoration: InputDecoration(
                                    hintText: 'Nama customer...',
                                    hintStyle: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Nilai
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nilai Uang Muka',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(
                                      'Rp ',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _nilaiController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.montserrat(fontSize: 11),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: _onNilaiChanged,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Jenis Bayar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jenis Bayar',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedJenisBayar,
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                    items: _jenisBayarOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedJenisBayar = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Keterangan
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keterangan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _keteranganController,
                                  style: GoogleFonts.montserrat(fontSize: 11),
                                  decoration: InputDecoration(
                                    hintText: 'Keterangan tambahan...',
                                    hintStyle: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  maxLines: 1,
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
            ),

            SizedBox(height: 12),

            // ========== COMPACT SAVE BUTTON ==========
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveUangMuka,
                icon: _isSaving
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  isEdit ? Icons.edit_rounded : Icons.save_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  isEdit ? 'UPDATE UANG MUKA' : 'SIMPAN UANG MUKA',
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
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}