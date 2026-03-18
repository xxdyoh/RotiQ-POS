import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../models/user.dart';
import '../routes/app_routes.dart';
import '../models/cabang_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  // Colors - Enhanced from POS screen
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
  final Color _successGreen = Color(0xFF06D6A0);

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _errorAnimation;

  // Shake animation for error
  bool _isShaking = false;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _errorAnimation = ColorTween(
      begin: _borderColor,
      end: _accentCoral,
    ).animate(_animationController);

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    _loadCabangList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerErrorAnimation() {
    _isShaking = true;
    Future.delayed(Duration(milliseconds: 300), () {
      setState(() {
        _isShaking = false;
      });
    });
  }

  bool _isPusatCabang() {
    if (_selectedCabang == null) return false;
    return _selectedCabang!.kode == '00' ||
        _selectedCabang!.nama.toLowerCase().contains('pusat');
  }

  Future<void> _loadCabangList() async {
    setState(() {
      _loadingCabang = true;
    });

    try {
      final cabangList = await ApiService.getCabangList();
      setState(() {
        _cabangList = cabangList;
        if (cabangList.isNotEmpty) {
          _selectedCabang = cabangList.first;
          _resetFormForCabang(_selectedCabang!);
        }
      });
    } catch (e) {
      _showErrorSnackBar('Gagal memuat data cabang');
    } finally {
      setState(() {
        _loadingCabang = false;
      });
    }
  }

  void _resetFormForCabang(Cabang cabang) {
    setState(() {
      _pin = '';
      _usernameController.clear();
      _passwordController.clear();
      _isError = false;
      _showPassword = false;
      _usersList.clear();
      _animationController.reset();
      _animationController.forward();

      if (_isPusatCabang()) {
        _loadUsersList();
      }
    });
  }

  Future<void> _loadUsersList() async {
    if (_selectedCabang == null ||
        _selectedCabang!.jenis.toLowerCase() != 'pusat') {
      return;
    }

    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/users/list?cbg_kode=${_selectedCabang!.kode}'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _usersList = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error loading users list: $e');
    } finally {
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<String?> _getToken() async {
    return null;
  }

  void _showUserSelectionModal() {
    if (_usersList.isEmpty) {
      _loadUsersList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryDark, _primaryLight],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih User',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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

              Expanded(
                child: _isLoadingUsers
                    ? Center(child: CircularProgressIndicator(color: _primaryDark))
                    : _usersList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: _borderColor),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada user tersedia',
                        style: GoogleFonts.montserrat(color: _textSecondary),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _usersList.length,
                  itemBuilder: (context, index) {
                    final user = _usersList[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _usernameController.text = user['username'] ?? '';
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: _borderColor)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _accentGold.withOpacity(0.3)),
                                ),
                                child: Icon(Icons.person, color: _accentGold, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['nama'] ?? '',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'User: ${user['username'] ?? ''}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: _textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addDigit(String digit) {
    setState(() {
      _pin += digit;
      _isError = false;
      _animationController.forward();
    });
    HapticFeedback.selectionClick();
  }

  void _deleteDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _toggleShowPin() {
    setState(() {
      _showPin = !_showPin;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _login() async {
    if (_selectedCabang == null) {
      _showErrorSnackBar('Pilih cabang terlebih dahulu');
      _vibrate();
      _triggerErrorAnimation();
      return;
    }

    final bool isPusat = _isPusatCabang();

    if (isPusat) {
      if (_usernameController.text.isEmpty) {
        _showErrorSnackBar('Masukkan username');
        _vibrate();
        _triggerErrorAnimation();
        return;
      }
      if (_passwordController.text.isEmpty) {
        _showErrorSnackBar('Masukkan password');
        _vibrate();
        _triggerErrorAnimation();
        return;
      }
    } else {
      if (_pin.isEmpty) {
        _showErrorSnackBar('Masukkan PIN');
        _vibrate();
        _triggerErrorAnimation();
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> loginData = {
        'cbg_kode': _selectedCabang!.kode,
      };

      if (isPusat) {
        loginData['username'] = _usernameController.text;
        loginData['password'] = _passwordController.text;
      } else {
        loginData['pin'] = _pin;
      }

      final result = await ApiService.loginWithData(loginData);

      if (result['success']) {
        final user = result['user'] as User;
        final token = result['token'] as String;
        final permissions = result['permissions'] as Map<String, dynamic>?;
        final menuMapping = result['menuMapping'] as Map<String, dynamic>?;

        print('Menu mapping dari API: ${result['menuMapping']}'); // Tambahkan ini

        SessionManager.saveSession(
          token,
          user,
          _selectedCabang!,
          permissions: permissions,
        );

        final bool isKasir = (user.nmuser ?? '').toUpperCase().contains('KASIR');

        if (mounted) {
          if (isKasir) {
            Navigator.pushReplacementNamed(context, AppRoutes.pos);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
            _isLoading = false;
          });
          _showErrorSnackBar(result['message'] ?? 'Login gagal');
          _vibrate();
          _triggerErrorAnimation();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _isLoading = false;
        });
        _showErrorSnackBar('Error: ${e.toString()}');
        _vibrate();
        _triggerErrorAnimation();
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.error_outline, color: Colors.white, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _accentCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _vibrate() {
    HapticFeedback.lightImpact();
  }

  Widget _buildCabangDropdown() {
    if (_loadingCabang) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accentGold,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memuat daftar cabang...',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_cabangList.isEmpty) {
      return GestureDetector(
        onTap: _loadCabangList,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentGold.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: _accentGold.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentGold.withOpacity(0.3)),
                ),
                child: Icon(Icons.refresh_rounded, size: 16, color: _accentGold),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap untuk memuat ulang cabang',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: _accentGold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _accentGold.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.store_rounded, size: 14, color: _accentGold),
                ),
                SizedBox(width: 8),
                Text(
                  'Cabang',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(
                    '${_cabangList.length} tersedia',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showCabangSelectionModal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedCabang != null
                              ? [
                            _getCabangColor(_selectedCabang!.jenis),
                            _getCabangColor(_selectedCabang!.jenis).withOpacity(0.8),
                          ]
                              : [
                            _accentGold.withOpacity(0.1),
                            _accentGold.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedCabang != null
                              ? _getCabangColor(_selectedCabang!.jenis).withOpacity(0.3)
                              : _borderColor,
                        ),
                      ),
                      child: Center(
                        child: _selectedCabang != null
                            ? _getCabangIconWidget(_selectedCabang!.jenis)
                            : Icon(
                          Icons.store_outlined,
                          size: 20,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCabang?.nama ?? 'Pilih Cabang',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedCabang != null
                                  ? _textPrimary
                                  : _textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              if (_selectedCabang != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getCabangColor(_selectedCabang!.jenis)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _selectedCabang!.kode,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getCabangColor(_selectedCabang!.jenis),
                                    ),
                                  ),
                                ),
                              if (_selectedCabang != null) SizedBox(width: 8),
                              Text(
                                _selectedCabang?.jenis.toUpperCase() ?? 'Tap untuk pilih',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: _selectedCabang != null
                                      ? _textSecondary
                                      : _borderColor,
                                  fontStyle: _selectedCabang == null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 24,
                      color: _accentGold,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCabangSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_primaryDark, _primaryLight]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.store_rounded, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Cabang',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_cabangList.length} cabang tersedia',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, size: 24, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: _cabangList.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cabang = _cabangList[index];
                    final isSelected = _selectedCabang?.kode == cabang.kode;
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _accentGold.withOpacity(0.08)
                            : _bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _accentGold.withOpacity(0.3)
                              : _borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: _accentGold.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ] : [
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
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final Cabang previousCabang =
                                _selectedCabang ?? _cabangList.first;
                            final bool wasPusat = previousCabang.kode == '00' ||
                                previousCabang.nama.toLowerCase().contains('pusat');
                            setState(() {
                              _selectedCabang = cabang;
                              if (wasPusat || _isPusatCabang()) {
                                _resetFormForCabang(cabang);
                              } else {
                                _pin = '';
                                _isError = false;
                              }
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getCabangColor(cabang.jenis)
                                        .withOpacity(isSelected ? 1 : 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getCabangColor(cabang.jenis)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: _getCabangIconWidget(cabang.jenis,
                                        color: isSelected
                                            ? Colors.white
                                            : _getCabangColor(cabang.jenis)),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cabang.nama,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _bgLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              cabang.kode,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _textSecondary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getCabangColor(cabang.jenis)
                                                  .withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              cabang.jenis.toUpperCase(),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _getCabangColor(cabang.jenis),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _accentGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
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
                  border: Border(top: BorderSide(color: _borderColor, width: 1)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Center(
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getCabangIconWidget(String jenis, {Color? color}) {
    final iconColor = color ?? Colors.white;
    switch (jenis.toLowerCase()) {
      case 'outlet':
        return Icon(Icons.storefront_rounded, size: 22, color: iconColor);
      case 'tenant':
        return Icon(Icons.business_center_rounded, size: 22, color: iconColor);
      default:
        return Icon(Icons.store_rounded, size: 22, color: iconColor);
    }
  }

  Color _getCabangColor(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'outlet':
        return _accentGold;
      case 'tenant':
        return _accentSky;
      default:
        return _primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              final isTablet = screenWidth > 600;
              final isSmallPhone = screenHeight < 600;
              final horizontalPadding = isTablet
                  ? screenWidth * 0.1
                  : isSmallPhone
                  ? 16.0
                  : 24.0;

              if (screenWidth > screenHeight && screenWidth > 700) {
                return _buildLandscapeLayout(
                    screenWidth, screenHeight, horizontalPadding);
              } else {
                return _buildPortraitLayout(
                    screenWidth, screenHeight, horizontalPadding, isSmallPhone);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
      double screenWidth, double screenHeight, double padding, bool isSmallPhone) {
    final bool isPusat = _isPusatCabang();
    final bool isVerySmallPhone = screenHeight < 600;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              width: double.infinity,
              height: screenHeight,
              child: Column(
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: padding,
                          vertical: isVerySmallPhone ? 16 : 20,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: isVerySmallPhone ? 70 : 80,
                              height: isVerySmallPhone ? 70 : 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [_primaryDark, _primaryLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryDark.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.point_of_sale_rounded,
                                  color: Colors.white,
                                  size: isVerySmallPhone ? 35 : 40,
                                ),
                              ),
                            ),

                            SizedBox(height: isVerySmallPhone ? 16 : 24),

                            Text(
                              'ROTI-Q',
                              style: GoogleFonts.montserrat(
                                fontSize: isVerySmallPhone ? 26 : 32,
                                fontWeight: FontWeight.w800,
                                color: _primaryDark,
                                letterSpacing: 1.0,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'Point of Sale System',
                              style: GoogleFonts.montserrat(
                                fontSize: isVerySmallPhone ? 12 : 14,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            SizedBox(height: isVerySmallPhone ? 24 : 32),

                            Container(
                              margin: EdgeInsets.only(bottom: isVerySmallPhone ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: _accentGold.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: _accentGold.withOpacity(0.3)),
                                          ),
                                          child: Icon(
                                            Icons.store_rounded,
                                            size: 12,
                                            color: _accentGold,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Cabang',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildCabangDropdown(),
                                ],
                              ),
                            ),

                            if (!isPusat) ...[
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                transform: Matrix4.translationValues(
                                  _isShaking ? 10.0 * (_isShaking ? 1 : 0) : 0.0,
                                  0,
                                  0,
                                ),
                                curve: Curves.easeInOut,
                                child: _buildPinDisplaySectionForPortrait(isVerySmallPhone),
                              ),
                              SizedBox(height: isVerySmallPhone ? 20 : 24),
                            ],

                            if (isPusat) ...[
                              _buildLoginInputSectionForPortrait(isVerySmallPhone),
                              SizedBox(height: isVerySmallPhone ? 20 : 24),
                            ],

                            if (_isLoading)
                              Container(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _accentGold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Memproses...',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            SizedBox(height: isVerySmallPhone ? 60 : 80),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: isVerySmallPhone ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      border: Border(
                        top: BorderSide(
                          color: _borderColor,
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!isPusat && !_isLoading)
                          _buildNumpadForPortrait(
                            isVerySmallPhone: isVerySmallPhone,
                            screenWidth: screenWidth,
                          ),

                        if (isPusat && !_isLoading)
                          _buildPusatLoginButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinDisplaySectionForPortrait(bool isVerySmallPhone) {
    return AnimatedBuilder(
      animation: _errorAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isVerySmallPhone ? 12 : 14,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _errorAnimation.value!,
              width: _isError ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: Row(
                    children: _buildPinDigitsForPortrait(isVerySmallPhone),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Tooltip(
                message: _showPin ? 'Sembunyikan PIN' : 'Tampilkan PIN',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleShowPin,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: isVerySmallPhone ? 32 : 36,
                      height: isVerySmallPhone ? 32 : 36,
                      decoration: BoxDecoration(
                        color: _bgLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentGold.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _accentGold,
                        size: isVerySmallPhone ? 16 : 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPinDigitsForPortrait(bool isVerySmallPhone) {
    final digitSize = isVerySmallPhone ? 28.0 : 32.0;
    final fontSize = isVerySmallPhone ? 16.0 : 18.0;
    final List<Widget> digitWidgets = [];

    for (int i = 0; i < _pin.length; i++) {
      digitWidgets.add(
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: digitSize,
          height: digitSize + 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: Text(
                  _showPin ? _pin[i] : '•',
                  key: ValueKey(_pin[i] + i.toString()),
                  style: GoogleFonts.montserrat(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentGold,
                      Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pin.length < 15) {
      digitWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: digitSize,
          height: digitSize + 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '_',
                style: GoogleFonts.montserrat(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: _borderColor,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 6),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return digitWidgets;
  }

  Widget _buildLoginInputSectionForPortrait(bool isVerySmallPhone) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Username',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _usernameController,
                    style: GoogleFonts.montserrat(fontSize: 14, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Pilih user',
                      hintStyle: GoogleFonts.montserrat(color: _textSecondary, fontSize: 13),
                      prefixIcon: Container(
                        width: 40,
                        height: 40,
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.person_outline, size: 18, color: _accentGold),
                      ),
                      suffixIcon: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showUserSelectionModal,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.arrow_drop_down, color: _accentGold),
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _accentGold, width: 1.5),
                      ),
                      filled: true,
                      fillColor: _bgCard,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Password',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: GoogleFonts.montserrat(fontSize: 14, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Masukkan password',
                    hintStyle: GoogleFonts.montserrat(color: _textSecondary, fontSize: 13),
                    prefixIcon: Container(
                      width: 40,
                      height: 40,
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.lock_outline, size: 18, color: _accentGold),
                    ),
                    suffixIcon: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: _accentGold,
                          ),
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _accentGold, width: 1.5),
                    ),
                    filled: true,
                    fillColor: _bgCard,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadForPortrait({
    required bool isVerySmallPhone,
    required double screenWidth,
  }) {
    final bool isTablet = screenWidth > 600;

    double buttonSize;
    if (isTablet) {
      buttonSize = 60.0;
    } else if (isVerySmallPhone) {
      buttonSize = 48.0;
    } else {
      buttonSize = 52.0;
    }

    final spacing = 8.0;
    final containerPadding = 12.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 2,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3'], buttonSize, spacing),
          SizedBox(height: spacing),
          _buildNumpadRow(['4', '5', '6'], buttonSize, spacing),
          SizedBox(height: spacing),
          _buildNumpadRow(['7', '8', '9'], buttonSize, spacing),
          SizedBox(height: spacing),
          _buildNumpadRow(['enter', '0', 'delete'], buttonSize, spacing),
        ],
      ),
    );
  }

  Widget _buildPusatLoginButton() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _login,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'LOGIN',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
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

  Widget _buildLandscapeLayout(
      double screenWidth, double screenHeight, double padding) {
    final bool isPusat = _isPusatCabang();
    final bool isVerySmallHeight = screenHeight < 450;
    final bool isMediumHeight = screenHeight < 600;

    final leftPanelWidth = screenWidth * 0.25;
    final rightPanelWidth = screenWidth * 0.75;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Row(
              children: [
                Container(
                  width: leftPanelWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _primaryDark,
                        _primaryLight,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.point_of_sale_rounded,
                              color: _primaryDark,
                              size: 60,
                            ),
                          ),
                        ),

                        SizedBox(height: 24),

                        Text(
                          'ROTI-Q',
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                        ),

                        SizedBox(height: 8),

                        Text(
                          'Point of Sale System',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),

                        Spacer(),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Dibuat dengan ❤️ oleh IT BSM',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(30),
                    child: SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LOGIN',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Masuk ke sistem POS',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              margin: EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCabangDropdown(),
                                ],
                              ),
                            ),

                            Container(
                              width: double.infinity,
                              child: Column(
                                children: [
                                  if (!isPusat) ...[
                                    Container(
                                      margin: EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildPinDisplaySectionForLandscape(),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      margin: EdgeInsets.only(bottom: 24),
                                      child: _buildNumpadForLandscape(
                                        screenHeight: screenHeight,
                                        isVerySmallHeight: isVerySmallHeight,
                                      ),
                                    ),
                                  ],

                                  if (isPusat) ...[
                                    Container(
                                      margin: EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: EdgeInsets.only(bottom: 16),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: _accentGold.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: _accentGold.withOpacity(0.3)),
                                                  ),
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    size: 18,
                                                    color: _accentGold,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Login Cabang Pusat',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildLoginInputSectionForLandscape(),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      width: double.infinity,
                                      margin: EdgeInsets.only(bottom: 16),
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 300),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _primaryDark.withOpacity(0.4),
                                              blurRadius: 12,
                                              offset: Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _login,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [_primaryDark, _primaryLight],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.lock_open_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'LOGIN',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  if (_isLoading)
                                    Container(
                                      padding: EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: _accentGold,
                                            ),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Memproses login...',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              color: _textSecondary,
                                            ),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinDisplaySectionForLandscape() {
    return AnimatedBuilder(
      animation: _errorAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _errorAnimation.value!,
              width: _isError ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: Row(
                    children: _buildPinDigitsForLandscape(),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Tooltip(
                message: _showPin ? 'Sembunyikan PIN' : 'Tampilkan PIN',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleShowPin,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _bgLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentGold.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _accentGold,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPinDigitsForLandscape() {
    final digitSize = 38.0;
    final fontSize = 22.0;
    final List<Widget> digitWidgets = [];

    for (int i = 0; i < _pin.length; i++) {
      digitWidgets.add(
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: digitSize,
          height: digitSize + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: Text(
                  _showPin ? _pin[i] : '•',
                  key: ValueKey(_pin[i] + i.toString()),
                  style: GoogleFonts.montserrat(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentGold,
                      Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pin.length < 15) {
      digitWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: digitSize,
          height: digitSize + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '_',
                style: GoogleFonts.montserrat(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: _borderColor,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return digitWidgets;
  }

  Widget _buildNumpadForLandscape({
    required double screenHeight,
    required bool isVerySmallHeight,
  }) {
    final buttonSize = isVerySmallHeight ? 55.0 : 65.0;
    final spacing = isVerySmallHeight ? 8.0 : 10.0;
    final containerPadding = isVerySmallHeight ? 16.0 : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 3,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Column(
            children: [
              _buildNumpadRow(['1', '2', '3'], buttonSize, spacing),
              SizedBox(height: spacing),
              _buildNumpadRow(['4', '5', '6'], buttonSize, spacing),
              SizedBox(height: spacing),
              _buildNumpadRow(['7', '8', '9'], buttonSize, spacing),
              SizedBox(height: spacing),
              _buildNumpadRow(['enter', '0', 'delete'], buttonSize, spacing),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginInputSectionForLandscape() {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Username',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _usernameController,
                    style: GoogleFonts.montserrat(fontSize: 15, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Pilih dari daftar user',
                      hintStyle: GoogleFonts.montserrat(color: _textSecondary),
                      prefixIcon: Container(
                        width: 48,
                        height: 48,
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.person, color: _accentGold),
                      ),
                      suffixIcon: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showUserSelectionModal,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 48,
                            height: 48,
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.arrow_drop_down, color: _accentGold),
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _accentGold, width: 2),
                      ),
                      filled: true,
                      fillColor: _bgLight,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Password',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: GoogleFonts.montserrat(fontSize: 15, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Masukkan password',
                    hintStyle: GoogleFonts.montserrat(color: _textSecondary),
                    prefixIcon: Container(
                      width: 48,
                      height: 48,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.lock, color: _accentGold),
                    ),
                    suffixIcon: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: _accentGold,
                          ),
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _accentGold, width: 2),
                    ),
                    filled: true,
                    fillColor: _bgLight,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits, double buttonSize, double spacing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: digit == 'enter'
              ? _buildEnterButton(buttonSize)
              : digit == 'delete'
              ? _buildDeleteButton(buttonSize)
              : _buildNumberButton(digit, buttonSize),
        );
      }).toList(),
    );
  }

  Widget _buildNumberButton(String number, double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _vibrate();
          _addDigit(number);
        },
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: _accentGold.withOpacity(0.3),
        highlightColor: _accentGold.withOpacity(0.1),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _bgCard,
                _bgLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _borderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.white,
                blurRadius: 3,
                offset: Offset(-2, -2),
                // inset: true,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.montserrat(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _vibrate();
          _deleteDigit();
        },
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _bgLight,
                _borderColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _borderColor,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.backspace_rounded,
            size: size * 0.35,
            color: _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEnterButton(double size) {
    final isEnabled = _pin.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? _login : null,
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? LinearGradient(
              colors: [
                _primaryDark,
                _primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [
                _borderColor,
                _textSecondary.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isEnabled
                  ? _primaryDark.withOpacity(0.4)
                  : _borderColor,
              width: 2,
            ),
            boxShadow: isEnabled
                ? [
              BoxShadow(
                color: _primaryDark.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 3,
                offset: Offset(-2, -2),
                // inset: true,
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: size * 0.4,
            color: isEnabled ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }
}