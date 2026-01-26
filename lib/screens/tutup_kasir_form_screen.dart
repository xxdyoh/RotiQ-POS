import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/tutup_kasir_service.dart';
import '../services/session_manager.dart';
import '../models/tutup_kasir_model.dart';
import '../models/user.dart';
import '../services/receipt_service.dart';
import '../widgets/base_layout.dart';
import '../services/universal_printer_service.dart';

class TutupKasirFormScreen extends StatefulWidget {
  final VoidCallback onTutupKasirSuccess;

  const TutupKasirFormScreen({
    super.key,
    required this.onTutupKasirSuccess,
  });

  @override
  State<TutupKasirFormScreen> createState() => _TutupKasirFormScreenState();
}

class _TutupKasirFormScreenState extends State<TutupKasirFormScreen> {
  final _setoranController = TextEditingController();
  final _otorisasiController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  User? _currentUser;
  SummaryPenjualan? _summary;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _showOtorisasi = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = SessionManager.getCurrentUser();
      setState(() => _currentUser = user);
      await _loadSummary();
    } catch (e) {
      _showSnackbar('Gagal memuat data: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSummary() async {
    if (_currentUser == null) return;

    try {
      final summary = await TutupKasirService.getSummaryPenjualan(
        _selectedDate,
        _currentUser!.kduser,
      );
      setState(() => _summary = summary);
    } catch (e) {
      _showSnackbar('Gagal memuat summary penjualan: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _setoranController.dispose();
    _otorisasiController.dispose();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadSummary();
    }
  }

  Future<void> _prosesTutupKasir() async {
    if (_currentUser == null) {
      _showSnackbar('User tidak ditemukan!', Colors.red);
      return;
    }

    if (_setoranController.text.isEmpty) {
      _showSnackbar('Setoran harus diisi!', Colors.red);
      return;
    }

    final setoran = double.tryParse(_setoranController.text.replaceAll(',', '')) ?? 0;
    if (setoran <= 0) {
      _showSnackbar('Setoran harus lebih dari 0!', Colors.red);
      return;
    }

    try {
      final sudahAda = await TutupKasirService.cekSetoranAda(
        _selectedDate,
        _currentUser!.kduser,
      );

      if (sudahAda && !_showOtorisasi) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Sudah Pernah Tutup Kasir',
                    style: GoogleFonts.montserrat(fontSize: 14)),
              ],
            ),
            content: Text('Sudah pernah dilakukan tutup kasir untuk tanggal ini. Lanjutkan?',
                style: GoogleFonts.montserrat(fontSize: 12)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal',
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF6A918),
                ),
                child: Text('Lanjut',
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        if (shouldContinue == true) {
          setState(() => _showOtorisasi = true);
          return;
        }
        return;
      }
    } catch (e) {
      _showSnackbar('Gagal mengecek setoran: ${e.toString()}', Colors.red);
      return;
    }

    if (_showOtorisasi && _otorisasiController.text.isEmpty) {
      _showSnackbar('Kode otorisasi harus diisi!', Colors.red);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await TutupKasirService.prosesTutupKasir(
        tanggal: _selectedDate,
        userKode: _currentUser!.kduser,
        setoran: setoran,
        kodeOtorisasi: _showOtorisasi ? _otorisasiController.text : null,
      );

      if (result['success']) {
        _showSnackbar(result['message'], Colors.green);
        await _printStrukTutupKasir();
        widget.onTutupKasirSuccess();
        Navigator.pop(context);
      } else {
        _showSnackbar(result['message'], Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  double get _totalPenjualan {
    if (_summary == null) return 0;
    return _summary!.cash + _summary!.card + _summary!.other + _summary!.dp;
  }

  double get _selisih {
    if (_setoranController.text.isEmpty) return 0;
    final setoran = double.tryParse(_setoranController.text.replaceAll(',', '')) ?? 0;
    return setoran - (_summary?.cash ?? 0) - (_summary?.dp ?? 0);
  }

  Future<void> _printStrukTutupKasir() async {
    try {
      final result = await TutupKasirService.getStrukTutupKasir(
          _selectedDate,
          _currentUser!.kduser,
          _currentUser!.nmuser
      );

      if (result['success']) {
        // final success = await ReceiptService.printStrukTutupKasir(result['data']);
        final data = result['data'];
        final success = await UniversalPrinterService().printStrukTutupKasir(
          mainData: data['main'] as Map<String, dynamic>,
          payments: data['payments'] as List<dynamic>,
          biaya: data['biaya'] as List<dynamic>,
          pendapatan: data['pendapatan'] as List<dynamic>,
          uangMuka: data['uangMuka'] as List<dynamic>,
        );

        if (!success) {
          _showSnackbar('Gagal print struk, tetapi tutup kasir berhasil', Colors.orange);
        }
      } else {
        _showSnackbar('Gagal mengambil data struk: ${result['message']}', Colors.orange);
      }
    } catch (e) {
      _showSnackbar('Error print struk: ${e.toString()}', Colors.orange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Tutup Kasir',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF6A918)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ========== INFO USER & TANGGAL ==========
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
                children: [
                  // User Info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade100, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?.nmuser ?? '-',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              Text(
                                _currentUser?.kduser ?? '-',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tanggal
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate),
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // const SizedBox(height: 16),
            //
            // // ========== SUMMARY PENJUALAN ==========
            // Container(
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(10),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withOpacity(0.03),
            //         blurRadius: 3,
            //         offset: const Offset(0, 1),
            //       ),
            //     ],
            //   ),
            //   padding: const EdgeInsets.all(16),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         'Summary Penjualan',
            //         style: GoogleFonts.montserrat(
            //           fontSize: 13,
            //           fontWeight: FontWeight.w700,
            //           color: Colors.black87,
            //         ),
            //       ),
            //       const SizedBox(height: 12),
            //
            //       _buildSummaryItem('Cash', _summary?.cash ?? 0),
            //       _buildSummaryItem('Card', _summary?.card ?? 0),
            //       _buildSummaryItem('Other', _summary?.other ?? 0),
            //       _buildSummaryItem('DP', _summary?.dp ?? 0),
            //
            //       const Divider(height: 16, color: Colors.grey),
            //
            //       _buildSummaryItem(
            //         'TOTAL PENJUALAN',
            //         _totalPenjualan,
            //         isTotal: true,
            //         color: const Color(0xFFF6A918),
            //       ),
            //     ],
            //   ),
            // ),
            //
            // const SizedBox(height: 16),

            // ========== INPUT SETORAN ==========
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
                  Text(
                    'Setoran Kasir',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

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
                      controller: _setoranController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.montserrat(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Masukkan jumlah setoran...',
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
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info Selisih
                  // Container(
                  //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  //   decoration: BoxDecoration(
                  //     color: _selisih == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                  //     borderRadius: BorderRadius.circular(6),
                  //     border: Border.all(
                  //       color: _selisih == 0 ? Colors.green.shade200 : Colors.orange.shade200,
                  //       width: 1,
                  //     ),
                  //   ),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //     children: [
                  //       Text(
                  //         'SELISIH:',
                  //         style: GoogleFonts.montserrat(
                  //           fontSize: 10,
                  //           fontWeight: FontWeight.w600,
                  //           color: Colors.grey.shade700,
                  //         ),
                  //       ),
                  //       Text(
                  //         _formatCurrency(_selisih),
                  //         style: GoogleFonts.montserrat(
                  //           fontSize: 11,
                  //           fontWeight: FontWeight.w700,
                  //           color: _selisih == 0
                  //               ? Colors.green.shade700
                  //               : Colors.orange.shade700,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),

            // ========== OTORISASI SECTION ==========
            if (_showOtorisasi) ...[
              const SizedBox(height: 16),
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
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Otorisasi Diperlukan',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Karena sudah pernah dilakukan tutup kasir untuk tanggal ini, diperlukan kode otorisasi.',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        controller: _otorisasiController,
                        obscureText: true,
                        style: GoogleFonts.montserrat(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Masukkan kode otorisasi...',
                          hintStyle: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ========== PROSES BUTTON ==========
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _prosesTutupKasir,
                icon: _isProcessing
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Icon(Icons.lock_clock_rounded, size: 16, color: Colors.white),
                label: Text(
                  'PROSES TUTUP KASIR',
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, {bool isTotal = false, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 12 : 11,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Text(
            _formatCurrency(value),
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 13 : 11,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: color ?? const Color(0xFFF6A918),
            ),
          ),
        ],
      ),
    );
  }
}