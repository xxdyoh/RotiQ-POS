import 'package:flutter/material.dart';
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

class _LoginScreenState extends State<LoginScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadCabangList();

    _usernameController.addListener(() {
      if (_usernameController.text.isNotEmpty) {}
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

      // Jika cabang pusat, load daftar user
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
            color: Colors.white,
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
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: Color(0xFFF6A918)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // List users
              Expanded(
                child: _isLoadingUsers
                    ? Center(child: CircularProgressIndicator())
                    : _usersList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada user tersedia',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _usersList.length,
                  itemBuilder: (context, index) {
                    final user = _usersList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        Color(0xFFF6A918).withOpacity(0.1),
                        child:
                        Icon(Icons.person, color: Color(0xFFF6A918)),
                      ),
                      title: Text(user['nama'] ?? ''),
                      subtitle: Text('User: ${user['username'] ?? ''}'),
                      onTap: () {
                        setState(() {
                          _usernameController.text =
                              user['username'] ?? '';
                        });
                        Navigator.pop(context);
                      },
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
    });
  }

  void _deleteDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  void _toggleShowPin() {
    setState(() {
      _showPin = !_showPin;
    });
  }

  Future<void> _login() async {
    if (_selectedCabang == null) {
      _showErrorSnackBar('Pilih cabang terlebih dahulu');
      _vibrate();
      return;
    }

    final bool isPusat = _isPusatCabang();

    if (isPusat) {
      // Validasi untuk cabang pusat
      if (_usernameController.text.isEmpty) {
        _showErrorSnackBar('Masukkan username');
        _vibrate();
        return;
      }
      if (_passwordController.text.isEmpty) {
        _showErrorSnackBar('Masukkan password');
        _vibrate();
        return;
      }
    } else {
      if (_pin.isEmpty) {
        _showErrorSnackBar('Masukkan PIN');
        _vibrate();
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

      // Tambahkan parameter berdasarkan jenis cabang
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

        SessionManager.saveSession(token, user, _selectedCabang!);

        final bool isAdmin = (user.kduser ?? '').toLowerCase() == 'admin';

        if (mounted) {
          if (isAdmin) {
            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.pos);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
          });
          _showErrorSnackBar(result['message'] ?? 'Login gagal');
          _vibrate();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
        });
        _showErrorSnackBar('Error: ${e.toString()}');
        _vibrate();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFF0F0F0)),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memuat daftar cabang...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFF6A918)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap untuk memuat ulang cabang',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFF6A918),
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
      constraints: BoxConstraints(
        maxHeight: 200,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFF0F0F0)),
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
                Icon(Icons.store_rounded, size: 18, color: Color(0xFFF6A918)),
                SizedBox(width: 8),
                Text(
                  'Cabang',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),
                Text(
                  '${_cabangList.length} tersedia',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _showCabangSelectionModal();
              },
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
                            _getCabangColor(_selectedCabang!.jenis)
                                .withOpacity(0.8),
                          ]
                              : [
                            Color(0xFFF6A918).withOpacity(0.1),
                            Color(0xFFF6A918).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedCabang != null
                              ? _getCabangColor(_selectedCabang!.jenis)
                              .withOpacity(0.3)
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Center(
                        child: _selectedCabang != null
                            ? _getCabangIconWidget(_selectedCabang!.jenis)
                            : Icon(
                          Icons.store_outlined,
                          size: 20,
                          color: Colors.grey[400],
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedCabang != null
                                  ? Colors.grey[900]
                                  : Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              if (_selectedCabang != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getCabangColor(_selectedCabang!.jenis)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _selectedCabang!.kode,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getCabangColor(
                                          _selectedCabang!.jenis),
                                    ),
                                  ),
                                ),
                              if (_selectedCabang != null) SizedBox(width: 8),
                              Text(
                                _selectedCabang?.jenis.toUpperCase() ??
                                    'Tap untuk pilih',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedCabang != null
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
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
                      color: Color(0xFFF6A918),
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[100]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store_rounded, size: 24, color: Color(0xFFF6A918)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Cabang',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_cabangList.length} cabang tersedia',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, size: 24),
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
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
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
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFFF6A918).withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Color(0xFFF6A918).withOpacity(0.3)
                                  : Colors.grey[100]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
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
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[900],
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cabang.kode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                              fontFamily: 'Monospace',
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
                                            style: TextStyle(
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
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 24,
                                  color: Color(0xFFF6A918),
                                ),
                            ],
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
                  border: Border(
                    top: BorderSide(color: Colors.grey[100]!, width: 1),
                  ),
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
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
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
        return Color(0xFFF6A918);
      case 'tenant':
        return Color(0xFF2196F3);
      default:
        return Color(0xFF607D8B);
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
              Color(0xFFFFFBFF),
              Color(0xFFF8F4FF),
              Color(0xFFFFF8F0),
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

    return Container(
      width: double.infinity,
      height: screenHeight,
      child: Column(
        children: [
          // Flexible untuk bagian atas (bisa scroll kalau perlu)
          Flexible(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(), // Biarkan scrollable
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: isVerySmallPhone ? 16 : 20,
                ),
                child: Column(
                  children: [
                    // Logo & Branding
                    Container(
                      width: isVerySmallPhone ? 70 : 80,
                      height: isVerySmallPhone ? 70 : 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFFF6A918).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/logo.png',
                          width: isVerySmallPhone ? 45 : 55,
                          height: isVerySmallPhone ? 45 : 55,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    SizedBox(height: isVerySmallPhone ? 12 : 16),

                    Text(
                      'ROTI-Q',
                      style: TextStyle(
                        fontSize: isVerySmallPhone ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      'POS System',
                      style: TextStyle(
                        fontSize: isVerySmallPhone ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),

                    SizedBox(height: isVerySmallPhone ? 24 : 32),

                    // Cabang Dropdown
                    Container(
                      margin: EdgeInsets.only(bottom: isVerySmallPhone ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_rounded,
                                  size: 16,
                                  color: Color(0xFFF6A918),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Cabang',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCabangDropdown(),
                        ],
                      ),
                    ),

                    // Container(
                    //   margin: EdgeInsets.only(bottom: isVerySmallPhone ? 12 : 16),
                    //   child: Text(
                    //     isPusat ? 'Username & Password' : 'Masukkan PIN',
                    //     style: TextStyle(
                    //       fontSize: isVerySmallPhone ? 14 : 16,
                    //       fontWeight: FontWeight.w600,
                    //       color: Colors.grey[800],
                    //     ),
                    //   ),
                    // ),

                    // Login Input Section
                    if (!isPusat) ...[
                      _buildPinDisplaySectionForPortrait(isVerySmallPhone),
                      SizedBox(height: isVerySmallPhone ? 20 : 24),
                    ],

                    if (isPusat) ...[
                      _buildLoginInputSectionForPortrait(isVerySmallPhone),
                      SizedBox(height: isVerySmallPhone ? 20 : 24),
                    ],

                    // Loading Indicator (jika ada)
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
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Memproses...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Spacer untuk memastikan numpad/button terlihat
                    SizedBox(height: isVerySmallPhone ? 60 : 80),
                  ],
                ),
              ),
            ),
          ),

          // Fixed bagian bawah (numpad/button)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isVerySmallPhone ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
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
    );
  }

  Widget _buildPinDisplaySectionForPortrait(bool isVerySmallPhone) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isVerySmallPhone ? 12 : 14,
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? Colors.red.shade300 : Colors.grey.shade200,
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
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFF6A918).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Color(0xFFF6A918),
                    size: isVerySmallPhone ? 16 : 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinDigitsForPortrait(bool isVerySmallPhone) {
    final digitSize = isVerySmallPhone ? 28.0 : 32.0;
    final fontSize = isVerySmallPhone ? 16.0 : 18.0;
    final List<Widget> digitWidgets = [];

    for (int i = 0; i < _pin.length; i++) {
      digitWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: digitSize,
          height: digitSize + 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showPin ? _pin[i] : '•',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                  height: 1.0,
                ),
              ),
              SizedBox(height: 6),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF6A918),
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
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[400],
                  height: 1.0,
                ),
              ),
              SizedBox(height: 6),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
          // Username Field
          Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Pilih user',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: Icon(Icons.person_outline, size: 18, color: Color(0xFFF6A918)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFFF6A918)),
                      onPressed: _showUserSelectionModal,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFF6A918), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Masukkan password',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: Icon(Icons.lock_outline, size: 18, color: Color(0xFFF6A918)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: Color(0xFFF6A918),
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFF6A918), width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

    // Button size untuk portrait - cukup kecil tapi masih nyaman
    double buttonSize;
    if (isTablet) {
      buttonSize = 60.0;
    } else if (isVerySmallPhone) {
      buttonSize = 48.0; // Sangat kecil untuk phone kecil
    } else {
      buttonSize = 52.0; // Kecil untuk phone normal
    }

    final spacing = 8.0;
    final containerPadding = 12.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
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

// Update juga _buildPusatLoginButton agar lebih kecil untuk portrait
  Widget _buildPusatLoginButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFF6A918),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14), // Lebih kecil
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          shadowColor: Color(0xFFF6A918).withOpacity(0.3),
        ),
        child: Text(
          'LOGIN',
          style: TextStyle(
            fontSize: 15, // Lebih kecil
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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

    // Hitung ukuran berdasarkan tinggi layar
    final leftPanelWidth = screenWidth * 0.25; // 25% untuk branding
    final rightPanelWidth = screenWidth * 0.75; // 75% untuk form

    return Row(
      children: [
        // LEFT PANEL - Branding Minimalis
        Container(
          width: leftPanelWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFF9800),
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
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Brand Name
                Text(
                  'ROTI-Q',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                SizedBox(height: 8),

                // Tagline
                Text(
                  'POS System',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                Spacer(),

                // Footer
                Text(
                  ' Dibuat dengan ❤️ oleh IT BSM',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),

        // RIGHT PANEL - Login Form
        Expanded(
          child: Container(
            padding: EdgeInsets.all(30),
            child: SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF333333),
                            ),
                          ),
                          // SizedBox(height: 4),
                          // Text(
                          //   'Login ke sistem ROTI-Q',
                          //   style: TextStyle(
                          //     fontSize: 14,
                          //     color: Colors.grey[600],
                          //   ),
                          // ),
                        ],
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Container(
                          //   margin: EdgeInsets.only(bottom: 8),
                          //   child: Row(
                          //     children: [
                          //       Icon(
                          //         Icons.store_rounded,
                          //         size: 18,
                          //         color: Color(0xFFF6A918),
                          //       ),
                          //       SizedBox(width: 8),
                          //       Text(
                          //         'Pilih Cabang',
                          //         style: TextStyle(
                          //           fontSize: 16,
                          //           fontWeight: FontWeight.w600,
                          //           color: Color(0xFF333333),
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
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
                                  // Container(
                                  //   margin: EdgeInsets.only(bottom: 8),
                                  //   child: Row(
                                  //     children: [
                                  //       Icon(
                                  //         Icons.pin_rounded,
                                  //         size: 18,
                                  //         color: Color(0xFFF6A918),
                                  //       ),
                                  //       SizedBox(width: 8),
                                  //       Text(
                                  //         'Masukkan PIN',
                                  //         style: TextStyle(
                                  //           fontSize: 16,
                                  //           fontWeight: FontWeight.w600,
                                  //           color: Color(0xFF333333),
                                  //         ),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                  _buildPinDisplaySectionForLandscape(),
                                ],
                              ),
                            ),

                            // NUM PAD
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
                              child: _buildNumpadForLandscape(
                                screenHeight: screenHeight,
                                isVerySmallHeight: isVerySmallHeight,
                              ),
                            ),
                          ],

                          if (isPusat) ...[
                            // USERNAME & PASSWORD SECTION
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_rounded,
                                          size: 18,
                                          color: Color(0xFFF6A918),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Login Cabang Pusat',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildLoginInputSectionForLandscape(),
                                ],
                              ),
                            ),

                            // LOGIN BUTTON
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 16),
                              child: _buildPusatLoginButton(),
                            ),
                          ],

                          // LOADING INDICATOR
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Memproses login...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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
    );
  }

  Widget _buildPinDisplaySectionForLandscape() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? Colors.red.shade300 : Colors.grey.shade200,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFF6A918).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Color(0xFFF6A918),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinDigitsForLandscape() {
    final digitSize = 38.0;
    final fontSize = 22.0;
    final List<Widget> digitWidgets = [];

    for (int i = 0; i < _pin.length; i++) {
      digitWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: digitSize,
          height: digitSize + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showPin ? _pin[i] : '•',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                  height: 1.0,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF6A918),
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
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[400],
                  height: 1.0,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
        color: Colors.white,
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
          color: Colors.grey.shade100,
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
          // Username Field
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Pilih dari daftar user',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.person, color: Color(0xFFF6A918)),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.arrow_drop_down, color: Color(0xFFF6A918)),
                      onPressed: _showUserSelectionModal,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFF6A918), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          // Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Masukkan password',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.lock, color: Color(0xFFF6A918)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Color(0xFFF6A918),
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFF6A918), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildPusatLoginButton() {
  //   return Container(
  //     width: double.infinity,
  //     constraints: BoxConstraints(maxWidth: 400),
  //     child: ElevatedButton(
  //       onPressed: _login,
  //       style: ElevatedButton.styleFrom(
  //         backgroundColor: Color(0xFFF6A918),
  //         foregroundColor: Colors.white,
  //         padding: EdgeInsets.symmetric(vertical: 16),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         elevation: 3,
  //         shadowColor: Color(0xFFF6A918).withOpacity(0.3),
  //       ),
  //       child: Text(
  //         'LOGIN',
  //         style: TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //           letterSpacing: 0.5,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildLoginInputSection({
    required bool isLandscape,
    required bool isSmallPhone,
    required double screenWidth,
    bool isCompact = false,
  }) {
    final bool isPusat = _isPusatCabang();

    if (!isPusat) {
      return _buildPinDisplaySection(
        isLandscape: isLandscape,
        isSmallPhone: isSmallPhone,
        screenWidth: screenWidth,
        isCompact: isCompact,
      );
    }

    return Container(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username Field
          Container(
            margin: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
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
                    style: TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Pilih user',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: Icon(Icons.person_outline, size: 18, color: Color(0xFFF6A918)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.arrow_drop_down, color: Color(0xFFF6A918)),
                        onPressed: _showUserSelectionModal,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFFF6A918), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
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
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Masukkan password',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: Icon(Icons.lock_outline, size: 18, color: Color(0xFFF6A918)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: Color(0xFFF6A918),
                      ),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFF6A918), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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

  Widget _buildPinDisplaySection({
    required bool isLandscape,
    required bool isSmallPhone,
    required double screenWidth,
    bool isCompact = false,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 500),
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 12 : 16,
        horizontal: isCompact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? Colors.red.shade300 : Colors.grey.shade200,
          width: _isError ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 3),
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
                children: _buildPinDigits(
                  isLandscape: isLandscape,
                  isSmallPhone: isSmallPhone,
                  isCompact: isCompact,
                ),
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
                  width: isCompact ? 32 : 36,
                  height: isCompact ? 32 : 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFF6A918).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Color(0xFFF6A918),
                    size: isCompact ? 16 : 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinDigits({
    required bool isLandscape,
    required bool isSmallPhone,
    bool isCompact = false,
  }) {
    final digitSize = isCompact ? 28.0 : (isLandscape ? 36.0 : 32.0);
    final fontSize = isCompact ? 16.0 : (isLandscape ? 20.0 : 18.0);
    final List<Widget> digitWidgets = [];

    for (int i = 0; i < _pin.length; i++) {
      digitWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 3 : 6),
          width: digitSize,
          height: digitSize + (isCompact ? 10 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showPin ? _pin[i] : '•',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                  height: 1.0,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 8),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF6A918),
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
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 3 : 6),
          width: digitSize,
          height: digitSize + (isCompact ? 10 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '_',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[400],
                  height: 1.0,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 8),
              Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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

  Widget _buildNumpad({
    required bool isLandscape,
    required bool isSmallPhone,
    required double screenWidth,
  }) {
    // Jika landscape, pakai method khusus landscape
    if (isLandscape) {
      return _buildNumpadForLandscape(
        screenHeight: MediaQuery.of(context).size.height,
        isVerySmallHeight: isSmallPhone,
      );
    }

    // PORTRAIT ONLY - numpad yang lebih kecil
    final bool isTablet = screenWidth > 600;

    // Ukuran button untuk portrait (lebih kecil)
    double buttonSize;
    if (isTablet) {
      buttonSize = 62.0; // Tablet portrait
    } else if (isSmallPhone) {
      buttonSize = 52.0; // Phone kecil portrait
    } else {
      buttonSize = 58.0; // Phone normal portrait
    }

    final spacing = 9.0;
    final containerPadding = 14.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
        splashColor: Color(0xFFF6A918).withOpacity(0.3),
        highlightColor: Color(0xFFF6A918).withOpacity(0.1),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.grey.shade200,
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
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: size * 0.35, // Lebih besar
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.grey.shade300,
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
            color: Colors.grey[700],
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnabled
                ? LinearGradient(
              colors: [
                Color(0xFFF6A918),
                Color(0xFFFF9800),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade300,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isEnabled
                  ? Color(0xFFF6A918).withOpacity(0.4)
                  : Colors.grey.shade400,
              width: 2,
            ),
            boxShadow: isEnabled
                ? [
              BoxShadow(
                color: Color(0xFFF6A918).withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
                offset: Offset(0, 4),
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
            color: isEnabled ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}