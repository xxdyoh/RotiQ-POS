import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  bool _isLoading = false;
  bool _isError = false;

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

  Future<void> _login() async {
    if (_pin.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.login(_pin);

      if (result['success']) {
        await SessionManager.saveSession(
          result['token'],
          result['user'],
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
          });
          _showErrorSnackBar(result['message'] ?? 'PIN salah');
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBFF), // Soft white
              Color(0xFFF8F4FF), // Very light purple tint
              Color(0xFFFFF8F0), // Warm white
            ],
          ),
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section - Minimalist
                _buildLogoSection(isSmallScreen),
                SizedBox(height: isSmallScreen ? 32 : 40),

                // // Title Section
                _buildTitleSection(isSmallScreen),
                SizedBox(height: isSmallScreen ? 32 : 48),

                // PIN Display
                _buildPinDisplay(isSmallScreen),
                SizedBox(height: isSmallScreen ? 32 : 48),

                // Loading atau Numpad
                if (_isLoading)
                  _buildLoadingIndicator()
                else
                  _buildNumpad(isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isSmallScreen) {
    return Column(
      children: [
        // Logo Container dengan gradient subtle
        Container(
          width: isSmallScreen ? 100 : 120,
          height: isSmallScreen ? 100 : 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF6A918).withOpacity(0.1),
                Color(0xFFFFD54F).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color(0xFFF6A918).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: isSmallScreen ? 60 : 90,
                  height: isSmallScreen ? 60 : 90,
                  fit: BoxFit.contain,
                )
                // Container(
                //   width: isSmallScreen ? 40 : 50,
                //   height: isSmallScreen ? 40 : 50,
                //   decoration: BoxDecoration(
                //     color: Color(0xFFF6A918),
                //     borderRadius: BorderRadius.circular(12),
                //   ),
                //   child: Icon(
                //     Icons.cake_rounded,
                //     color: Colors.white,
                //     size: isSmallScreen ? 24 : 30,
                //   ),
                // ),
                // SizedBox(height: 8),
                // Text(
                //   'Rotivo',
                //   style: TextStyle(
                //     fontSize: isSmallScreen ? 12 : 14,
                //     fontWeight: FontWeight.bold,
                //     color: Color(0xFFF6A918),
                //   ),
                // ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),

        // Decorative line
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF6A918).withOpacity(0.3),
                Color(0xFFFFD54F).withOpacity(0.6),
                Color(0xFFF6A918).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(bool isSmallScreen) {
    return Column(
      children: [
        // Text(
        //   'ROTI-Q',
        //   style: TextStyle(
        //     fontSize: isSmallScreen ? 24 : 28,
        //     fontWeight: FontWeight.w700,
        //     color: Color(0xFF333333),
        //     letterSpacing: 0.5,
        //   ),
        // ),
        // SizedBox(height: 8),
        Text(
          'Masukkan PIN Anda',
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPinDisplay(bool isSmallScreen) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: isSmallScreen ? 70 : 80, // Minimum height guarantee
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _isError ? Colors.red.shade300 : Colors.grey.shade200,
            width: _isError ? 1.5 : 1,
          ),
        ),
        child: Center( // Use Center instead of Row with mainAxisAlignment
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Important: only take needed space
            children: List.generate(6, (index) {
              final hasDigit = index < _pin.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: isSmallScreen ? 14 : 16,
                height: isSmallScreen ? 14 : 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasDigit ? Color(0xFFF6A918) : Colors.transparent,
                  border: hasDigit ? null : Border.all(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6A918)),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Memverifikasi...',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad(bool isSmallScreen) {
    final buttonSize = isSmallScreen ? 72.0 : 80.0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            spreadRadius: 4,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3'], buttonSize),
          SizedBox(height: 12),
          _buildNumpadRow(['4', '5', '6'], buttonSize),
          SizedBox(height: 12),
          _buildNumpadRow(['7', '8', '9'], buttonSize),
          SizedBox(height: 12),
          _buildNumpadRow(['enter', '0', 'delete'], buttonSize),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits, double buttonSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[50],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w600,
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
            color: Colors.grey[50],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.backspace_outlined,
            size: size * 0.3,
            color: Colors.grey[600],
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
                Color(0xFFFFB74D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isEnabled ? null : Colors.grey[200],
            border: Border.all(
              color: isEnabled ? Color(0xFFF6A918).withOpacity(0.3) : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isEnabled
                ? [
              BoxShadow(
                color: Color(0xFFF6A918).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
                offset: Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Icon(
            Icons.arrow_forward,
            size: size * 0.35,
            color: isEnabled ? Colors.white : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}