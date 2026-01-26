import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../routes/app_routes.dart';
import '../services/session_manager.dart';

class SidebarWidget extends StatefulWidget {
  final String? currentRoute;
  final bool isLargeTablet;

  const SidebarWidget({
    super.key,
    required this.currentRoute,
    this.isLargeTablet = false,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  static final Map<String, bool> _expandedGroups = {
    'master': true,
    'transaction': true,
    'report': false,
    'utility': false,
  };

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    _currentUser = SessionManager.getCurrentUser();
  }

  void _toggleGroup(String groupName) {
    setState(() {
      _expandedGroups[groupName] = !_expandedGroups[groupName]!;
    });
  }

  void _navigateTo(String routeName) {
    Navigator.pushNamed(
      context,
      routeName,
    );
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isLargeTablet ? 240.0 : 200.0;
    final user = SessionManager.getCurrentUser();
    final isAdmin = user?.kduser?.toLowerCase() == 'admin';

    if (!isAdmin) {
      return Container(
        width: 200,
        color: Colors.white,
        child: Center(
          child: Text(
            'Hanya Admin\nBisa Akses Menu',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      width: width,
      color: Colors.white,
      child: Column(
        children: [
          // Store Info - KEMBALIKAN KE VERSI ASLI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6A918).withOpacity(0.05),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6A918).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: const Color(0xFFF6A918),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROTI-Q',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentUser?.kduser ?? 'Kasir',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Menu - KEMBALIKAN KE VERSI ASLI
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // DASHBOARD
                    _buildMenuItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      routeName: AppRoutes.dashboard,
                    ),

                    const SizedBox(height: 16),

                    // MASTER GROUP
                    _buildExpandableGroup(
                      groupName: 'master',
                      title: 'MASTER',
                      icon: Icons.layers_rounded,
                      children: _buildMasterChildren(),
                    ),

                    // TRANSACTION GROUP
                    _buildExpandableGroup(
                      groupName: 'transaction',
                      title: 'TRANSACTION',
                      icon: Icons.swap_horiz_rounded,
                      children: _buildTransactionChildren(),
                    ),

                    // REPORT GROUP
                    _buildExpandableGroup(
                      groupName: 'report',
                      title: 'REPORT',
                      icon: Icons.analytics_rounded,
                      children: _buildReportChildren(),
                    ),

                    // UTILITY GROUP
                    _buildExpandableGroup(
                      groupName: 'utility',
                      title: 'UTILITY',
                      icon: Icons.settings_rounded,
                      children: _buildUtilityChildren(),
                    ),

                    // LOGOUT
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _logout,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 16,
                                color: Colors.red.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Logout',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red.shade600,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String routeName,
    bool indent = false,
  }) {
    final isActive = widget.currentRoute == routeName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _navigateTo(routeName),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: indent ? 20 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isActive
                  ? const Color(0xFFF6A918).withOpacity(0.1)
                  : Colors.transparent,
              border: isActive
                  ? Border.all(
                color: const Color(0xFFF6A918).withOpacity(0.3),
                width: 1,
              )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? const Color(0xFFF6A918)
                      : Colors.grey.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? const Color(0xFFF6A918)
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableGroup({
    required String groupName,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedGroups[groupName] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleGroup(groupName),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isExpanded
                        ? const Color(0xFFF6A918)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isExpanded
                            ? const Color(0xFFF6A918)
                            : Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: isExpanded
                          ? const Color(0xFFF6A918)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Group Content
        if (isExpanded) ...[
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  List<Widget> _buildMasterChildren() {
    return [
      _buildMenuItem(
        icon: Icons.construction_rounded,
        label: 'Item St. Jadi',
        routeName: AppRoutes.setengahJadiList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.inventory_2_outlined,
        label: 'Item',
        routeName: AppRoutes.itemList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.category_outlined,
        label: 'Category',
        routeName: AppRoutes.categoryList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.discount_outlined,
        label: 'Discount',
        routeName: AppRoutes.discountList,
        indent: true,
      ),
    ];
  }

  List<Widget> _buildTransactionChildren() {
    return [
      _buildMenuItem(
        icon: Icons.shopping_basket_outlined,
        label: 'Point of Sale',
        routeName: AppRoutes.pos,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.receipt_long_outlined,
        label: 'Tutup Kasir',
        routeName: AppRoutes.tutupKasir,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.inventory_rounded,
        label: 'Stock In',
        routeName: AppRoutes.stockInList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.swap_horizontal_circle_outlined,
        label: 'Penerimaan St. Jadi',
        routeName: AppRoutes.penerimaanSetengahJadi,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.payment_rounded,
        label: 'Uang Muka',
        routeName: AppRoutes.uangMukaList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.assignment_return_outlined,
        label: 'Return Production',
        routeName: AppRoutes.returnProduction,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.receipt_long_rounded,
        label: 'Biaya Lain',
        routeName: AppRoutes.biayaLain,
        indent: true,
      ),
    ];
  }

  List<Widget> _buildReportChildren() {
    return [
      _buildMenuItem(
        icon: Icons.analytics_rounded,
        label: 'Sales by Item',
        routeName: AppRoutes.salesByItem,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.receipt_long_rounded,
        label: 'Sales by Invoice',
        routeName: AppRoutes.salesByInvoice,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.list_alt_rounded,
        label: 'List Sales Order',
        routeName: AppRoutes.salesOrderList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.assignment_return_rounded,
        label: 'Return Production',
        routeName: AppRoutes.returnProductionList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.block,
        label: 'List Void',
        routeName: AppRoutes.voidList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Setoran',
        routeName: AppRoutes.setoran,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.inventory_rounded,
        label: 'Lap Stock',
        routeName: AppRoutes.lapStock,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.construction_rounded,
        label: 'Stock St. Jadi',
        routeName: AppRoutes.stockSetengahJadi,
        indent: true,
      ),
    ];
  }

  List<Widget> _buildUtilityChildren() {
    return [
      _buildMenuItem(
        icon: Icons.print_rounded,
        label: 'Connect Printer',
        routeName: AppRoutes.connectPrinter,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.settings_rounded,
        label: 'Setting Printer',
        routeName: AppRoutes.settingPrinter,
        indent: true,
      ),
    ];
  }
}