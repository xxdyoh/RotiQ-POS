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
  final Map<String, bool> _expandedGroups = {
    'master': true,
    'transaction': true,
    'report': false,
    'utility': false,
  };

  // Warna dari POS Screen
  final Color _primaryDark = const Color(0xFF2C3E50);
  final Color _primaryLight = const Color(0xFF34495E);
  final Color _accentGold = const Color(0xFFF6A918);
  final Color _accentMint = const Color(0xFF06D6A0);
  final Color _accentCoral = const Color(0xFFFF6B6B);
  final Color _accentSky = const Color(0xFF4CC9F0);
  final Color _bgLight = const Color(0xFFFAFAFA);
  final Color _bgCard = const Color(0xFFFFFFFF);
  final Color _textPrimary = const Color(0xFF1A202C);
  final Color _textSecondary = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  void _toggleGroup(String groupName) {
    setState(() {
      _expandedGroups[groupName] = !_expandedGroups[groupName]!;
    });
  }

  void _navigateTo(String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentCoral.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded, size: 24, color: _accentCoral),
              ),
              const SizedBox(height: 12),
              Text(
                'Keluar Aplikasi?',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Anda akan keluar dari sistem',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text('Batal', style: GoogleFonts.montserrat(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentCoral,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text('Keluar', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.getCurrentUser();
    final isAdmin = user?.kduser?.toLowerCase() == 'admin';

    if (!isAdmin) {
      return Container(
        color: _bgCard,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 32, color: _textSecondary),
              const SizedBox(height: 8),
              Text(
                'Admin Only',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryDark, _primaryLight],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  color: _primaryDark,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ROTI-Q',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    routeName: AppRoutes.dashboard,
                  ),
                  const Divider(height: 16, thickness: 1, indent: 12, endIndent: 12, color: Color(0xFFE2E8F0)),
                  _buildExpandableGroup(
                    groupName: 'master',
                    title: 'MASTER',
                    children: _buildMasterChildren(),
                  ),
                  _buildExpandableGroup(
                    groupName: 'transaction',
                    title: 'TRANSAKSI',
                    children: _buildTransactionChildren(),
                  ),
                  _buildExpandableGroup(
                    groupName: 'report',
                    title: 'LAPORAN',
                    children: _buildReportChildren(),
                  ),
                  _buildExpandableGroup(
                    groupName: 'utility',
                    title: 'UTILITAS',
                    children: _buildUtilityChildren(),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _logout,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _borderColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.logout_rounded, size: 14, color: _accentCoral),
                              const SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _accentCoral,
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
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String routeName,
    bool indent = false,
  }) {
    final isActive = widget.currentRoute == routeName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _navigateTo(routeName),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 6,
              horizontal: indent ? 28 : 10,
            ),
            decoration: isActive
                ? BoxDecoration(  // Ganti dengan opsi yang dipilih
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryDark.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            )
                : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isActive ? Colors.white : _textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.white : _textSecondary,
                    ),
                  ),
                ),
                if (isActive && !indent)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
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
    required List<Widget> children,
  }) {
    final isExpanded = _expandedGroups[groupName] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleGroup(groupName),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isExpanded ? _primaryDark.withOpacity(0.04) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isExpanded ? _primaryDark : _textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: isExpanded ? _primaryDark : _textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  List<Widget> _buildMasterChildren() {
    return [
      _buildMenuItem(
        icon: Icons.precision_manufacturing_rounded,
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
        label: 'POS',
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
        icon: Icons.inbox_rounded,
        label: 'Permintaan Barang',
        routeName: AppRoutes.mintaList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.receipt_long_rounded,
        label: 'Biaya Lain',
        routeName: AppRoutes.biayaLain,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.inventory_rounded,
        label: 'Serah Terima BJ',
        routeName: AppRoutes.serahTerimaList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.assignment_rounded,
        label: 'SPK',
        routeName: AppRoutes.spkList,
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.local_shipping_rounded,
        label: 'Pengiriman (DO)',
        routeName: AppRoutes.doList,
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
        label: 'List SO',
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
        label: 'Void',
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
        icon: Icons.pie_chart_outline,
        label: 'Lap. Permintaan',
        routeName: '/minta-report',
        indent: true,
      ),
      _buildMenuItem(
        icon: Icons.precision_manufacturing_rounded,
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