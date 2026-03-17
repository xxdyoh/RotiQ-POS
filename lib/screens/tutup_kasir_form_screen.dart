import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _TutupKasirFormScreenState extends State<TutupKasirFormScreen> with SingleTickerProviderStateMixin {
  final _setoranController = TextEditingController();
  final _otorisasiController = TextEditingController();

  // Warna modern dari screen lainnya
  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgSoft = const Color(0xFFF8FAFC);
  final Color _surfaceWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A202C);
  final Color _textMedium = const Color(0xFF718096);
  final Color _textLight = const Color(0xFFA0AEC0);
  final Color _borderSoft = const Color(0xFFE2E8F0);
  final Color _shadowColor = const Color(0xFF2C3E50).withOpacity(0.1);

  // Soft versions
  final Color _primarySoft = const Color(0xFF2C3E50).withOpacity(0.1);
  final Color _accentGoldSoft = const Color(0xFFF6A918).withOpacity(0.1);
  final Color _accentMintSoft = const Color(0xFF06D6A0).withOpacity(0.1);
  final Color _accentCoralSoft = const Color(0xFFFF6B6B).withOpacity(0.1);
  final Color _accentSkySoft = const Color(0xFF4CC9F0).withOpacity(0.1);

  DateTime _selectedDate = DateTime.now();
  User? _currentUser;
  SummaryPenjualan? _summary;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _showOtorisasi = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _setoranController.dispose();
    _otorisasiController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final user = SessionManager.getCurrentUser();
      setState(() => _currentUser = user);
      // Tetap load summary untuk keperluan backend, tapi tidak ditampilkan ke UI
      await _loadSummary();
    } catch (e) {
      _showToast('Gagal memuat data: ${e.toString()}', type: ToastType.error);
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
      _showToast('Gagal memuat summary penjualan: ${e.toString()}', type: ToastType.error);
    }
  }

  // Modern Toast
  void _showToast(String message, {required ToastType type}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                type == ToastType.success ? Icons.check_circle_rounded :
                type == ToastType.error ? Icons.error_rounded :
                Icons.info_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: type == ToastType.success ? _accentMint :
        type == ToastType.error ? _accentCoral :
        _accentSky,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryDark,
              onPrimary: Colors.white,
              surface: _surfaceWhite,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: _surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadSummary();
    }
  }

  // Fungsi untuk mengambil nilai numerik dari text yang sudah diformat
  double _getNilaiSetoran() {
    if (_setoranController.text.isEmpty) return 0;
    // Hapus semua titik (separator ribuan) dan konversi ke double
    final cleanText = _setoranController.text.replaceAll('.', '');
    return double.tryParse(cleanText) ?? 0;
  }

  Future<void> _prosesTutupKasir() async {
    if (_currentUser == null) {
      _showToast('User tidak ditemukan!', type: ToastType.error);
      return;
    }

    if (_setoranController.text.isEmpty) {
      _showToast('Setoran harus diisi!', type: ToastType.error);
      return;
    }

    final setoran = _getNilaiSetoran();
    if (setoran <= 0) {
      _showToast('Setoran harus lebih dari 0!', type: ToastType.error);
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
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            actionsPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentGoldSoft,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _accentGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sudah Pernah Tutup Kasir',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sudah pernah dilakukan tutup kasir untuk tanggal ini. Lanjutkan?',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: _textMedium,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textMedium,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentGold, _accentGold.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _accentGold.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Lanjut',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (shouldContinue == true) {
          setState(() => _showOtorisasi = true);
          return;
        }
        return;
      }
    } catch (e) {
      _showToast('Gagal mengecek setoran: ${e.toString()}', type: ToastType.error);
      return;
    }

    if (_showOtorisasi && _otorisasiController.text.isEmpty) {
      _showToast('Kode otorisasi harus diisi!', type: ToastType.error);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await TutupKasirService.prosesTutupKasir(
        tanggal: _selectedDate,
        userKode: _currentUser!.kduser,
        setoran: setoran, // Mengirim nilai numerik tanpa separator
        kodeOtorisasi: _showOtorisasi ? _otorisasiController.text : null,
      );

      if (result['success']) {
        _showToast(result['message'], type: ToastType.success);
        await _printStrukTutupKasir();
        widget.onTutupKasirSuccess();
        Navigator.pop(context);
      } else {
        _showToast(result['message'], type: ToastType.error);
      }
    } catch (e) {
      _showToast('Error: ${e.toString()}', type: ToastType.error);
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

  Future<void> _printStrukTutupKasir() async {
    try {
      final result = await TutupKasirService.getStrukTutupKasir(
          _selectedDate,
          _currentUser!.kduser,
          _currentUser!.nmuser
      );

      if (result['success']) {
        final data = result['data'];
        final success = await UniversalPrinterService().printStrukTutupKasir(
          mainData: data['main'] as Map<String, dynamic>,
          payments: data['payments'] as List<dynamic>,
          biaya: data['biaya'] as List<dynamic>,
          pendapatan: data['pendapatan'] as List<dynamic>,
          uangMuka: data['uangMuka'] as List<dynamic>,
        );

        if (!success) {
          _showToast('Gagal print struk, tetapi tutup kasir berhasil', type: ToastType.info);
        }
      } else {
        _showToast('Gagal mengambil data struk: ${result['message']}', type: ToastType.info);
      }
    } catch (e) {
      _showToast('Error print struk: ${e.toString()}', type: ToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: 'Tutup Kasir',
      showBackButton: true,
      showSidebar: true,
      isFormScreen: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            color: _bgSoft,
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: _accentGold,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Memuat data...',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textMedium,
                    ),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ========== INFO USER & TANGGAL ==========
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _borderSoft),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 16,
                                  color: _primaryDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kasir',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        color: _textLight,
                                      ),
                                    ),
                                    Text(
                                      _currentUser?.nmuser ?? '-',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _accentGoldSoft,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _accentGold.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _currentUser?.kduser ?? '-',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tanggal
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _bgSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _borderSoft),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: _accentGold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tanggal',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            color: _textLight,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('EEEE, dd MMMM yyyy', 'id').format(_selectedDate),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: _textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down_rounded, size: 18, color: _textLight),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ========== INPUT SETORAN ==========
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _borderSoft),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _accentGoldSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.payments_rounded,
                                  size: 16,
                                  color: _accentGold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Setoran Kasir',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content - INPUT SETORAN dengan format separator
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _bgSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderSoft),
                            ),
                            child: Row(
                              children: [
                                // Prefix Rp
                                Container(
                                  width: 45,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Rp',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _accentGold,
                                    ),
                                  ),
                                ),

                                // Separator
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: _borderSoft,
                                ),

                                // Input field dengan format separator
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: _setoranController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        color: _textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        TextInputFormatter.withFunction((oldValue, newValue) {
                                          if (newValue.text.isEmpty) return newValue;

                                          // Hapus semua titik yang ada
                                          final cleanText = newValue.text.replaceAll('.', '');

                                          // Format dengan separator ribuan (titik)
                                          final buffer = StringBuffer();
                                          for (int i = 0; i < cleanText.length; i++) {
                                            if (i > 0 && (cleanText.length - i) % 3 == 0) {
                                              buffer.write('.');
                                            }
                                            buffer.write(cleanText[i]);
                                          }

                                          return TextEditingValue(
                                            text: buffer.toString(),
                                            selection: TextSelection.collapsed(offset: buffer.length),
                                          );
                                        }),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          color: _textLight,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ========== OTORISASI SECTION ==========
                  if (_showOtorisasi) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accentGold.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _accentGold.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _borderSoft),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accentGoldSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.security_rounded,
                                    size: 16,
                                    color: _accentGold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Otorisasi Diperlukan',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Karena sudah pernah dilakukan tutup kasir',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 9,
                                          color: _textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _bgSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _borderSoft),
                              ),
                              child: TextFormField(
                                controller: _otorisasiController,
                                obscureText: true,
                                textAlignVertical: TextAlignVertical.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: _textDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Masukkan kode otorisasi...',
                                  hintStyle: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: _textLight,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_rounded,
                                    size: 16,
                                    color: _accentGold,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ========== PROSES BUTTON ==========
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryDark, _primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryDark.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isProcessing ? null : _prosesTutupKasir,
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: _isProcessing
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_clock_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PROSES TUTUP KASIR',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Toast Type enum
enum ToastType { success, error, info }