import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/sidebar_manager.dart';
import '../services/session_manager.dart';
import '../models/user.dart';
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

  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _bgCard = Colors.white;
  final Color _borderColor = const Color(0xFFE2E8F0);

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
                    color: _bgCard,
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
    return ValueListenableBuilder<bool>(
      valueListenable: SidebarManager.sidebarVisible,
      builder: (context, isSidebarVisible, child) {
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border(
              bottom: BorderSide(
                color: _borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
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
              Expanded(
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    if (!widget.isFormScreen && user != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _accentGold.withOpacity(0.2)),
                        ),
                        child: Text(
                          '${_getGreeting()}, ${user.nmuser}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _accentGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      _currentTime,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 1, height: 12, color: Colors.grey.shade300),
                    const SizedBox(width: 6),
                    Text(
                      _currentDate,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
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
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgCard,
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
          color: _primaryDark,
        )
            : null,
        title: Text(
          widget.title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        actions: widget.actions,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: widget.child,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Pagi';
    if (hour < 17) return 'Siang';
    return 'Malam';
  }
}