import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../models/user.dart';
import '../routes/app_routes.dart';
import '../models/cabang_model.dart';
import '../services/pengumuman_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isLoading = false;
  bool _isError = false;
  bool _showPin = false;
  bool _loadingCabang = false;

  List<Cabang> _cabangList = [];
  Cabang? _selectedCabang;

  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoadingUsers = false;
  List<Map<String, dynamic>> _usersList = [];

  List<Map<String, dynamic>> _pengumuman = [];
  bool _loadingPengumuman = true;

  // ✅ CERTIFICATE MODE
  bool _isCertMode = false;
  bool _isSuperAdmin = false;
  String? _certCabangKode;
  String? _certDeviceName;
  bool _isCheckingCert = true;

  static const Color _primary = Color(0xFF1E293B);
  static const Color _primaryLight = Color(0xFF334155);
  static const Color _accent = Color(0xFFF59E0B);
  static const Color _accentMint = Color(0xFF10B981);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadCabangList(), _loadPengumuman()]);
    await _checkCertificateMode();
  }

  // ========== CERTIFICATE CHECK ==========
  Future<void> _checkCertificateMode() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/cert-info'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final certData = data['data'];
          setState(() {
            _isCertMode = true;
            _certCabangKode = certData['cabang_kode'];
            _isSuperAdmin = certData['is_super'] == true;
            _certDeviceName = certData['device_name'];

            // Auto-select cabang dari certificate
            if (!_isSuperAdmin && _cabangList.isNotEmpty) {
              _selectedCabang = _cabangList.firstWhere(
                    (c) => c.kode == _certCabangKode,
                orElse: () => _cabangList.first,
              );
            }
          });
        }
      }
    } catch (e) {
      // No certificate → normal login
      if (mounted) setState(() => _isCertMode = false);
    } finally {
      if (mounted) setState(() => _isCheckingCert = false);
    }
  }

  Future<void> _loadCabangList() async {
    setState(() => _loadingCabang = true);
    try {
      final cabangList = await ApiService.getCabangList();
      if (mounted) {
        setState(() {
          _cabangList = cabangList;
          if (cabangList.isNotEmpty && !_isCertMode) {
            _selectedCabang = cabangList.first;
            _resetForm();
          }
        });
      }
    } catch (e) {
      _toast('Gagal memuat cabang', true);
    } finally {
      if (mounted) setState(() => _loadingCabang = false);
    }
  }

  Future<void> _loadPengumuman() async {
    try {
      final data = await PengumumanService.getActive();
      if (mounted) setState(() { _pengumuman = data; _loadingPengumuman = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingPengumuman = false);
    }
  }

  void _resetForm() {
    setState(() {
      _pin = ''; _usernameController.clear(); _passwordController.clear();
      _isError = false; _showPassword = false; _usersList.clear();
      if (_isPusat) _loadUsersList();
    });
  }

  bool get _isPusat => _selectedCabang != null && (_selectedCabang!.kode == '00' || _selectedCabang!.nama.toLowerCase().contains('pusat'));

  Future<void> _loadUsersList() async {
    if (_selectedCabang == null || !_isPusat) return;
    setState(() => _isLoadingUsers = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/users/list?cbg_kode=${_selectedCabang!.kode}'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() => _usersList = List<Map<String, dynamic>>.from(data['data']));
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<String?> _getToken() async => null;

  void _addDigit(String d) { setState(() { _pin += d; _isError = false; }); HapticFeedback.selectionClick(); }
  void _deleteDigit() { if (_pin.isNotEmpty) { setState(() => _pin = _pin.substring(0, _pin.length - 1)); HapticFeedback.lightImpact(); } }
  void _togglePin() => setState(() => _showPin = !_showPin);

  Future<void> _login() async {
    if (_selectedCabang == null) { _toast('Pilih cabang', true); return; }

    if (_isCertMode) {
      // Certificate mode: hanya perlu PIN
      if (_pin.isEmpty) { _toast('PIN harus diisi', true); return; }
    } else if (_isPusat) {
      if (_usernameController.text.isEmpty) { _toast('Username harus diisi', true); return; }
      if (_passwordController.text.isEmpty) { _toast('Password harus diisi', true); return; }
    } else {
      if (_pin.isEmpty) { _toast('PIN harus diisi', true); return; }
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{'cbg_kode': _selectedCabang!.kode};

      if (_isCertMode) {
        data['pin'] = _pin;
      } else if (_isPusat) {
        data['username'] = _usernameController.text;
        data['password'] = _passwordController.text;
      } else {
        data['pin'] = _pin;
      }

      // ✅ Gunakan endpoint berbeda untuk cert mode
      final url = _isCertMode ? '/auth/login' : '/login';
      final result = await ApiService.loginWithData(data);

      if (result['success']) {
        final user = result['user'] as User;
        SessionManager.saveSession(result['token'], user, _selectedCabang!, permissions: result['permissions']);
        if (mounted) Navigator.pushReplacementNamed(context, (user.nmuser ?? '').toUpperCase().contains('KASIR') ? AppRoutes.pos : AppRoutes.dashboard);
      } else {
        if (mounted) { _toast(result['message'] ?? 'Login gagal', true); setState(() { _isError = true; _isLoading = false; }); }
      }
    } catch (e) {
      if (mounted) { _toast('Error: $e', true); setState(() { _isError = true; _isLoading = false; }); }
    }
  }

  void _toast(String msg, bool err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
      backgroundColor: err ? _accentRed : _accentMint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  Color _cabangColor(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'outlet': return _accent;
      case 'tenant': return _accentBlue;
      default: return _primary;
    }
  }

  IconData _cabangIcon(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'outlet': return Icons.storefront_rounded;
      case 'tenant': return Icons.business_center_rounded;
      default: return Icons.store_rounded;
    }
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    if (_isCheckingCert) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
            const SizedBox(height: 16),
            Text('Memeriksa koneksi...', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          ]),
        ),
      );
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: isWide ? _buildWideLayout(size) : _buildNarrowLayout(size),
      ),
    );
  }

  // ========== WIDE LAYOUT ==========
  Widget _buildWideLayout(Size size) {
    return Row(
      children: [
        Container(
          width: size.width * 0.35,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primary, _primaryLight]),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  Row(
                    children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.point_of_sale_rounded, size: 22, color: Colors.white)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ROTI-Q', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                        Text('POS System', style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.7))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 36),
                  if (!_loadingPengumuman && _pengumuman.isNotEmpty) ...[
                    Row(children: [
                      Container(width: 3, height: 16, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text('Pengumuman', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                    ]),
                    const SizedBox(height: 12),
                    ...List.generate(_pengumuman.length > 3 ? 3 : _pengumuman.length, (i) {
                      final p = _pengumuman[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(_pengumumanIcon(p['tipe']), size: 14, color: _pengumumanColor(p['tipe'])),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['judul'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (p['isi'] != null && p['isi'].toString().isNotEmpty) Text(p['isi'], style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                        ]),
                      );
                    }),
                  ],
                  const Spacer(flex: 3),
                  Text('© 2024 ROTI-Q', style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: _bg,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Selamat Datang', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary)),
                      const SizedBox(height: 4),
                      Text(_isCertMode ? 'Login dengan certificate' : 'Silakan pilih cabang untuk masuk', style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
                      const SizedBox(height: 28),

                      // ✅ CERTIFICATE INFO BADGE
                      if (_isCertMode) ...[
                        _buildCertBadge(),
                        const SizedBox(height: 16),
                      ],

                      // Cabang Selector
                      _buildCabangSelector(),
                      const SizedBox(height: 20),

                      // Form
                      if (_isPusat && !_isCertMode) ...[
                        _buildInput('Username', _usernameController, Icons.person_rounded, onSuffix: _showUserModal, suffix: Icons.arrow_drop_down_rounded),
                        const SizedBox(height: 14),
                        _buildInput('Password', _passwordController, Icons.lock_rounded, obscure: !_showPassword, onSuffix: () => setState(() => _showPassword = !_showPassword), suffix: _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        const SizedBox(height: 24),
                        _buildLoginButton(),
                      ] else ...[
                        _buildPinDisplay(),
                        const SizedBox(height: 24),
                        _buildNumpad(),
                        const SizedBox(height: 16),
                      ],
                      if (_isLoading) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)))),
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

  // ========== NARROW LAYOUT ==========
  Widget _buildNarrowLayout(Size size) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.point_of_sale_rounded, size: 20, color: Colors.white)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ROTI-Q', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary)),
                      Text('POS System', style: GoogleFonts.inter(fontSize: 9, color: _textMuted)),
                    ]),
                    const Spacer(),
                    if (!_loadingPengumuman && _pengumuman.isNotEmpty)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('${_pengumuman.length} info', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: _accent))),
                  ]),
                  if (!_loadingPengumuman && _pengumuman.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(height: 80, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _pengumuman.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) {
                      final p = _pengumuman[i];
                      return Container(width: 240, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(_pengumumanIcon(p['tipe']), size: 14, color: _pengumumanColor(p['tipe'])),
                        const SizedBox(width: 6),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['judul'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (p['isi'] != null && p['isi'].toString().isNotEmpty) Text(p['isi'], style: GoogleFonts.inter(fontSize: 9, color: _textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ])),
                      ]));
                    })),
                  ],
                  const SizedBox(height: 24),
                  Text('Selamat Datang', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary)),
                  const SizedBox(height: 2),
                  Text(_isCertMode ? 'Login dengan certificate' : 'Silakan pilih cabang untuk masuk', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 20),

                  // ✅ CERTIFICATE INFO BADGE
                  if (_isCertMode) ...[
                    _buildCertBadge(),
                    const SizedBox(height: 16),
                  ],

                  _buildCabangSelector(),
                  const SizedBox(height: 18),
                  if (_isPusat && !_isCertMode) ...[
                    _buildInput('Username', _usernameController, Icons.person_rounded, onSuffix: _showUserModal, suffix: Icons.arrow_drop_down_rounded),
                    const SizedBox(height: 12),
                    _buildInput('Password', _passwordController, Icons.lock_rounded, obscure: !_showPassword, onSuffix: () => setState(() => _showPassword = !_showPassword), suffix: _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    const SizedBox(height: 20),
                    _buildLoginButton(),
                  ] else ...[
                    _buildPinDisplay(),
                    const SizedBox(height: 20),
                    _buildNumpad(),
                    const SizedBox(height: 12),
                  ],
                  if (_isLoading) const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)))),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== CERTIFICATE BADGE ==========
  Widget _buildCertBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentMint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentMint.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _accentMint.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user_rounded, size: 20, color: _accentMint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _certDeviceName ?? 'Device Terverifikasi',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _isSuperAdmin ? 'Super Admin — Bisa memilih semua cabang' : 'Cabang: ${_selectedCabang?.nama ?? _certCabangKode}',
                  style: GoogleFonts.inter(fontSize: 11, color: _accentMint),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, size: 20, color: _accentMint),
        ],
      ),
    );
  }

  // ========== CABANG SELECTOR ==========
  Widget _buildCabangSelector() {
    final isLocked = _isCertMode && !_isSuperAdmin; // ✅ LOCKED jika cert mode & bukan super admin

    return InkWell(
      onTap: isLocked ? null : _showCabangModal,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isLocked ? _accentMint : _border, width: isLocked ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _selectedCabang != null ? _cabangColor(_selectedCabang!.jenis).withOpacity(0.1) : _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_cabangIcon(_selectedCabang?.jenis ?? ''), size: 20, color: _selectedCabang != null ? _cabangColor(_selectedCabang!.jenis) : _textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedCabang?.nama ?? 'Pilih Cabang', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedCabang != null ? _textPrimary : _textMuted)),
              if (_selectedCabang != null) Text('${_selectedCabang!.kode} • ${_selectedCabang!.jenis.toUpperCase()}', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ]),
          ),
          if (isLocked)
            Icon(Icons.lock_rounded, color: _accentMint, size: 18)
          else
            Icon(Icons.keyboard_arrow_down_rounded, color: _accent, size: 22),
        ]),
      ),
    );
  }

  void _showCabangModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(color: _surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
              child: Row(children: [
                const Icon(Icons.store_rounded, size: 20, color: _primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary))),
                IconButton(icon: const Icon(Icons.close, size: 18, color: _textSecondary), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _cabangList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final c = _cabangList[i];
                  final sel = _selectedCabang?.kode == c.kode;
                  return Material(
                    color: sel ? _accent.withOpacity(0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedCabang = c);
                        _resetForm();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Container(width: 38, height: 38, decoration: BoxDecoration(color: _cabangColor(c.jenis).withOpacity(sel ? 1 : 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(_cabangIcon(c.jenis), size: 16, color: sel ? Colors.white : _cabangColor(c.jenis))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.nama, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                            Text('${c.kode} • ${c.jenis.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                          ])),
                          if (sel) Container(width: 20, height: 20, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle), child: const Icon(Icons.check, size: 12, color: Colors.white)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserModal() {
    if (_usersList.isEmpty) _loadUsersList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        decoration: const BoxDecoration(color: _surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))), child: Row(children: [
              const Icon(Icons.people_rounded, size: 20, color: _primary), const SizedBox(width: 8),
              Expanded(child: Text('Pilih User', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary))),
              IconButton(icon: const Icon(Icons.close, size: 18, color: _textSecondary), onPressed: () => Navigator.pop(context)),
            ])),
            Expanded(
              child: _isLoadingUsers ? const Center(child: CircularProgressIndicator()) : _usersList.isEmpty
                  ? Center(child: Text('Tidak ada user', style: GoogleFonts.inter(color: _textSecondary)))
                  : ListView.separated(
                padding: const EdgeInsets.all(12), itemCount: _usersList.length, separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final u = _usersList[i];
                  return ListTile(
                    leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, size: 16, color: _accent)),
                    title: Text(u['nama'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('User: ${u['username'] ?? ''}', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                    onTap: () { setState(() => _usernameController.text = u['username'] ?? ''); Navigator.pop(context); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _pengumumanColor(String? tipe) {
    switch (tipe) { case 'success': return _accentMint; case 'warning': return _accent; case 'danger': return _accentRed; default: return _accentBlue; }
  }

  IconData _pengumumanIcon(String? tipe) {
    switch (tipe) { case 'success': return Icons.check_circle_rounded; case 'warning': return Icons.warning_rounded; case 'danger': return Icons.error_rounded; default: return Icons.info_rounded; }
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool obscure = false, VoidCallback? onTap, VoidCallback? onSuffix, IconData? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _textSecondary)), const SizedBox(height: 4),
      TextField(controller: ctrl, obscureText: obscure, readOnly: false, onTap: onTap, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _accent),
          suffixIcon: suffix != null ? InkWell(onTap: onSuffix, child: Icon(suffix, size: 18, color: _textSecondary)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent, width: 1.5)),
          filled: true, fillColor: _surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }

  Widget _buildPinDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _isError ? _accentRed : _border, width: _isError ? 2 : 1)),
      child: Row(children: [
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          ...List.generate(_pin.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 26, height: 36, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_showPin ? _pin[i] : '•', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 2), Container(height: 2, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(1))),
          ]))),
          Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 26, height: 36, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('_', style: GoogleFonts.inter(fontSize: 18, color: _border)),
            const SizedBox(height: 2), Container(height: 2, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(1))),
          ])),
        ]))),
        InkWell(onTap: _togglePin, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(15)), child: Icon(_showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 14, color: _textSecondary))),
      ]),
    );
  }

  Widget _buildNumpad() {
    return Column(children: [
      _numpadRow(['1', '2', '3']), const SizedBox(height: 8),
      _numpadRow(['4', '5', '6']), const SizedBox(height: 8),
      _numpadRow(['7', '8', '9']), const SizedBox(height: 8),
      _numpadRow(['del', '0', 'go']),
    ]);
  }

  Widget _numpadRow(List<String> keys) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: keys.map((k) {
      if (k == 'del') return _numpadBtn(Icons.backspace_rounded, _deleteDigit);
      if (k == 'go') return _numpadBtn(Icons.arrow_forward_rounded, _login, bg: _pin.isNotEmpty ? _primary : _border, fg: Colors.white);
      return _numpadDigit(k);
    }).toList());
  }

  Widget _numpadDigit(String d) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 10), child: Material(color: Colors.transparent, child: InkWell(onTap: () => _addDigit(d), borderRadius: BorderRadius.circular(30), child: Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: _surface, border: Border.all(color: _border, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]), child: Center(child: Text(d, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)))))));
  }

  Widget _numpadBtn(IconData icon, VoidCallback onTap, {Color? bg, Color? fg}) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 10), child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(30), child: Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: bg ?? Colors.transparent, border: Border.all(color: bg ?? _border, width: 1.5)), child: Center(child: Icon(icon, size: 20, color: fg ?? _textSecondary))))));
  }

  Widget _buildLoginButton() {
    return SizedBox(height: 44, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_open_rounded, size: 15), const SizedBox(width: 8),
      Text('LOGIN', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ])));
  }
}