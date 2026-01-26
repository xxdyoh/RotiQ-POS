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
import '../utils/responsive_helper.dart';

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

  static const List<String> _mainScreens = [
    AppRoutes.dashboard,
    AppRoutes.setengahJadiList,
    AppRoutes.itemList,
    AppRoutes.categoryList,
    AppRoutes.discountList,
    AppRoutes.salesByItem,
    AppRoutes.salesByInvoice,
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
    final isAdmin = user?.kduser?.toLowerCase() == 'admin';

    if (!isAdmin && widget.title.toLowerCase().contains('pos')) {
      return widget.child;
    }

    // Untuk web/desktop: selalu pakai sidebar jika lebar > 768
    // Untuk mobile: pakai AppBar saja
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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // SIDEBAR - Lebar tetap 200px
            ValueListenableBuilder<bool>(
              valueListenable: SidebarManager.sidebarVisible,
              builder: (context, isSidebarVisible, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSidebarVisible ? 200 : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: Colors.grey.shade200,
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
                      color: Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isSidebarVisible
                          ? Icons.menu_open_rounded
                          : Icons.menu_rounded,
                      size: 22,
                      color: Colors.grey.shade700,
                    ),
                    onPressed: SidebarManager.toggle,
                  ),
                  const SizedBox(width: 8),

                  if (widget.showBackButton && !_isMainScreen)
                    IconButton(
                      icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: Colors.grey.shade600
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),

                  if (widget.showBackButton && !_isMainScreen)
                    const SizedBox(width: 8),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (!widget.isFormScreen) const SizedBox(height: 2),
                      if (!widget.isFormScreen)
                        Text(
                          'Selamat ${_getGreeting()} ${user?.kduser ?? 'Kasir'}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // WAKTU REAL-TIME
                    Text(
                      _currentTime,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // TANGGAL
                    Text(
                      _currentDate,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _buildMobileAppBar(context),
      body: Container(
        color: Colors.white,
        child: widget.child,
      ),
    );
  }

  AppBar _buildMobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      leading: widget.showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back, size: 20),
        onPressed: () => Navigator.pop(context),
      )
          : null,
      title: Text(
        widget.title,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      actions: widget.actions,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Pagi';
    if (hour < 17) return 'Siang';
    return 'Malam';
  }
}