import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/sidebar_manager.dart';
import '../services/session_manager.dart';
import '../models/user.dart';
import '../models/cabang_model.dart';
import '../routes/app_routes.dart';
import 'sidebar_widget.dart';
import '../services/fullscreen_service.dart';

class BaseLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final bool showBackButton;
  final bool showSidebar;
  final List<Widget>? actions;
  final bool isFormScreen;

  const BaseLayout({
    super.key,
    required this.child,
    required this.title,
    this.showBackButton = false,
    this.showSidebar = true,
    this.actions,
    this.isFormScreen = false,
  });

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;

  // Color Palette
  static const Color _primaryDark = Color(0xFF2C3E50);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _bgLight = Color(0xFFF7F9FC);
  static const Color _textPrimary = Color(0xFF1A202C);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _accentGold = Color(0xFFF6A918);
  static const Color _accentMint = Color(0xFF06D6A0);
  static const Color _accentSky = Color(0xFF4CC9F0);

  static const List<String> _mainScreens = [
    AppRoutes.dashboard,
    AppRoutes.setengahJadiList,
    AppRoutes.itemList,
    AppRoutes.categoryList,
    AppRoutes.discountList,
    AppRoutes.salesByItem,
    AppRoutes.salesByInvoice,
    AppRoutes.salesOrderList,
    AppRoutes.returnProductionList,
    AppRoutes.voidList,
    AppRoutes.setoran,
    AppRoutes.lapStock,
    AppRoutes.stockSetengahJadi,
  ];

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateDateTime();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FullScreenService.forceHideSystemUI();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(now);
      _currentDate = DateFormat('dd MMM yyyy').format(now);
    });
  }

  bool get _isMainScreen {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute != null && _mainScreens.contains(currentRoute);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.getCurrentUser();
    final bool isKasir = (user?.nmuser ?? '').toUpperCase().contains('KASIR');

    if (isKasir && widget.title.toLowerCase().contains('pos')) {
      return widget.child;
    }

    final isWideScreen = MediaQuery.of(context).size.width >= 768;

    if (isWideScreen && widget.showSidebar) {
      return _buildDesktopLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final user = SessionManager.getCurrentUser();

    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: SidebarManager.sidebarVisible,
              builder: (context, isSidebarVisible, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSidebarVisible ? 200 : 0,
                  decoration: BoxDecoration(
                    color: _surfaceWhite,
                    border: Border(
                      right: BorderSide(
                        color: _borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: isSidebarVisible
                      ? SidebarWidget(
                    currentRoute: ModalRoute.of(context)?.settings.name,
                    isLargeTablet: false,
                  )
                      : null,
                );
              },
            ),
            Expanded(
              child: Column(
                children: [
                  _buildDesktopHeader(context, user),
                  Expanded(
                    child: Container(
                      color: _bgLight,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, User? user) {
    final cabang = SessionManager.getCurrentCabang();

    return ValueListenableBuilder<bool>(
      valueListenable: SidebarManager.sidebarVisible,
      builder: (context, isSidebarVisible, child) {
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _surfaceWhite,
            border: Border(
              bottom: BorderSide(
                color: _borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Menu toggle button
              InkWell(
                onTap: SidebarManager.toggle,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Icon(
                    isSidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded,
                    size: 16,
                    color: _primaryDark,
                  ),
                ),
              ),

              // Back button
              if (widget.showBackButton && !_isMainScreen) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 12),

              // Title and info section
              Expanded(
                child: Row(
                  children: [
                    // Page title
                    Text(
                      widget.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),

                    // Dot separator
                    if (cabang != null) ...[
                      const SizedBox(width: 10),
                      _buildDot(),
                    ],

                    // Cabang badge
                    if (cabang != null) ...[
                      const SizedBox(width: 10),
                      _buildCabangBadge(cabang),
                    ],

                    // Dot separator
                    if (!widget.isFormScreen && user != null) ...[
                      const SizedBox(width: 10),
                      _buildDot(),
                    ],

                    // User badge
                    if (!widget.isFormScreen && user != null) ...[
                      const SizedBox(width: 10),
                      _buildUserBadge(user),
                    ],
                  ],
                ),
              ),

              // Time and date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: _textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _currentTime,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 1, height: 12, color: _borderColor),
                    const SizedBox(width: 6),
                    Text(
                      _currentDate,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Custom actions
              if (widget.actions != null) ...[
                const SizedBox(width: 8),
                ...widget.actions!,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final cabang = SessionManager.getCurrentCabang();

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _surfaceWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: widget.showBackButton
            ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          color: _primaryDark,
        )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            if (cabang != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    _getCabangIcon(cabang.jenis),
                    size: 10,
                    color: _getCabangColor(cabang.jenis),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${cabang.kode} - ${cabang.nama}',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getCabangColor(cabang.jenis),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: widget.actions,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: widget.child,
    );
  }

  // ========== BADGE WIDGETS ==========

  Widget _buildDot() {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: _borderColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCabangBadge(Cabang cabang) {
    final color = _getCabangColor(cabang.jenis);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${cabang.kode} - ${cabang.nama}',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBadge(User user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _accentGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 12,
            color: _accentGold,
          ),
          const SizedBox(width: 5),
          Text(
            user.nmuser,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ========== CABANG HELPERS ==========

  Color _getCabangColor(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'outlet':
        return _accentGold;
      case 'tenant':
        return _accentSky;
      case 'pusat':
        return _accentMint;
      default:
        return _primaryDark;
    }
  }

  IconData _getCabangIcon(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'outlet':
        return Icons.storefront_rounded;
      case 'tenant':
        return Icons.business_center_rounded;
      case 'pusat':
        return Icons.business_rounded;
      default:
        return Icons.store_rounded;
    }
  }
}