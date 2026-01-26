import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';
import '../widgets/base_layout.dart';
import '../routes/app_routes.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_patterns.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();


    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BaseLayout(
      title: 'Dashboard',
      showBackButton: false,
      showSidebar: true,
      isFormScreen: false,
      // HAPUS BARIS INI: showBottomNav: ResponsiveHelper.shouldShowBottomNav(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          final isLargeTablet = constraints.maxWidth >= 900;

          return FadeScaleTransition(
            animation: _fadeAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // _buildStoreInfoCard(context, colorScheme, isDarkMode),

                  // SizedBox(height: isTablet ? 28 : 20),
                  // _buildMenuGroups(context, isTablet, isLargeTablet, colorScheme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildStoreInfoCard(BuildContext context, ColorScheme colorScheme, bool isDarkMode) {
    return OpenContainer(
      closedBuilder: (context, action) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'store_icon',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROTI-Q',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Solo Square, Slamet Riyadi, Pajang, Laweyan, Surakarta City',
                        style: GoogleFonts.montserrat(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'ONLINE',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      openBuilder: (context, action) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Store Details'),
          ),
          body: Center(
            child: Text('Store Information Details'),
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 500),
      closedColor: Colors.transparent,
      closedElevation: 0,
    );
  }

  Widget _buildMenuGroups(BuildContext context, bool isTablet, bool isLargeTablet, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedGroupHeader('MASTER', colorScheme, 0),
        SizedBox(height: 12),
        _buildMasterGrid(context, isTablet, isLargeTablet, colorScheme),
        SizedBox(height: isTablet ? 28 : 20),

        // Transaction Group
        _buildAnimatedGroupHeader('TRANSACTION', colorScheme, 1),
        SizedBox(height: 12),
        _buildTransactionGrid(context, isTablet, isLargeTablet, colorScheme),
        SizedBox(height: isTablet ? 28 : 20),

        // Report Group
        _buildAnimatedGroupHeader('REPORT', colorScheme, 2),
        SizedBox(height: 12),
        _buildReportGrid(context, isTablet, isLargeTablet, colorScheme),
        SizedBox(height: isTablet ? 28 : 20),

        // Utility Group
        _buildAnimatedGroupHeader('UTILITY', colorScheme, 3),
        SizedBox(height: 12),
        _buildUtilityGrid(context, isTablet, isLargeTablet, colorScheme),
      ],
    );
  }

  Widget _buildGroupCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
  }) {
    return ResponsivePatterns.responsiveCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: ResponsiveHelper.responsiveFontSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Items Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: ResponsiveHelper.responsiveGridColumns(
              context,
              mobile: 2,
              tablet: 3,
              desktop: 4,
            ),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: items,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGroupHeader(String title, ColorScheme colorScheme, int index) {
    return FadeInSlide(
      duration: Duration(milliseconds: 500),
      offset: Offset(-20, 0),
      delay: Duration(milliseconds: 100 * index),
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withOpacity(0.8),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterGrid(BuildContext context, bool isTablet, bool isLargeTablet, ColorScheme colorScheme) {
    final menuItems = [
      DashboardMenuItem(
        title: 'Item \nSt. Jadi',
        icon: Icons.construction_rounded,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer,
        routeName: AppRoutes.setengahJadiList,
      ),
      DashboardMenuItem(
        title: 'Item',
        icon: Icons.inventory_2_outlined,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer,
        routeName: AppRoutes.itemList,
      ),
      DashboardMenuItem(
        title: 'Category',
        icon: Icons.category_outlined,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.categoryList,
      ),
      DashboardMenuItem(
        title: 'Discount',
        icon: Icons.discount_outlined,
        iconColor: colorScheme.error,
        backgroundColor: colorScheme.errorContainer,
        routeName: AppRoutes.discountList,
      ),
    ];

    return _buildAnimatedGridMenu(menuItems, isTablet, isLargeTablet, 0);
  }

  Widget _buildTransactionGrid(BuildContext context, bool isTablet, bool isLargeTablet, ColorScheme colorScheme) {
    final menuItems = [
      DashboardMenuItem(
        title: 'Point Of Sale',
        icon: Icons.point_of_sale_rounded,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.pos,
      ),
      DashboardMenuItem(
        title: 'Tutup Kasir',
        icon: Icons.lock_clock_rounded,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer,
        routeName: AppRoutes.tutupKasir,
      ),
      DashboardMenuItem(
        title: 'Stock In',
        icon: Icons.input_rounded,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer,
        routeName: AppRoutes.stockInList,
      ),
      DashboardMenuItem(
        title: 'Penerimaan\nSetengah Jadi',
        icon: Icons.swap_horiz_rounded,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.penerimaanSetengahJadi,
      ),
      DashboardMenuItem(
        title: 'Uang Muka',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer,
        routeName: AppRoutes.uangMukaList,
      ),
      DashboardMenuItem(
        title: 'Return\nProduction',
        icon: Icons.assignment_return_rounded,
        iconColor: colorScheme.error,
        backgroundColor: colorScheme.errorContainer,
        routeName: AppRoutes.returnProduction,
      ),
      DashboardMenuItem(
        title: 'Biaya Lain',
        icon: Icons.receipt_long_rounded,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer,
        routeName: AppRoutes.biayaLain,
      ),
    ];

    return _buildAnimatedGridMenu(menuItems, isTablet, isLargeTablet, 4);
  }

  Widget _buildReportGrid(BuildContext context, bool isTablet, bool isLargeTablet, ColorScheme colorScheme) {
    final menuItems = [
      DashboardMenuItem(
        title: 'Sales by Item',
        icon: Icons.analytics_rounded,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.salesByItem,
      ),
      DashboardMenuItem(
        title: 'Sales by Invoice',
        icon: Icons.receipt_long_rounded,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer,
        routeName: AppRoutes.salesByInvoice,
      ),
      DashboardMenuItem(
        title: 'List Sales Order',
        icon: Icons.list_alt_rounded,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer,
        routeName: AppRoutes.salesOrderList,
      ),
      DashboardMenuItem(
        title: 'Return\nProduction',
        icon: Icons.assignment_return_rounded,
        iconColor: colorScheme.error,
        backgroundColor: colorScheme.errorContainer,
        routeName: AppRoutes.returnProductionList,
      ),
      DashboardMenuItem(
        title: 'List Void',
        icon: Icons.block_rounded,
        iconColor: colorScheme.error,
        backgroundColor: colorScheme.errorContainer,
        routeName: AppRoutes.voidList,
      ),
      DashboardMenuItem(
        title: 'Setoran',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.setoran,
      ),
      DashboardMenuItem(
        title: 'Lap Stock',
        icon: Icons.inventory_2_rounded,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer,
        routeName: AppRoutes.lapStock,
      ),
      DashboardMenuItem(
        title: 'Stock\nSetengah Jadi',
        icon: Icons.construction_rounded,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer,
        routeName: AppRoutes.stockSetengahJadi,
      ),
    ];

    return _buildAnimatedGridMenu(menuItems, isTablet, isLargeTablet, 11);
  }

  Widget _buildUtilityGrid(BuildContext context, bool isTablet, bool isLargeTablet, ColorScheme colorScheme) {
    final menuItems = [
      DashboardMenuItem(
        title: 'Connect\nPrinter',
        icon: Icons.print_rounded,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer,
        routeName: AppRoutes.connectPrinter,
      ),
      DashboardMenuItem(
        title: 'Setting\nPrinter',
        icon: Icons.settings_rounded,
        iconColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceVariant,
        routeName: AppRoutes.settingPrinter,
      ),
    ];

    return _buildAnimatedGridMenu(menuItems, isTablet, isLargeTablet, 19);
  }

  Widget _buildAnimatedGridMenu(List<DashboardMenuItem> menuItems, bool isTablet, bool isLargeTablet, int startIndex) {
    int crossAxisCount = 3;
    if (isLargeTablet) {
      crossAxisCount = 5;
    } else if (isTablet) {
      crossAxisCount = 4;
    }

    double childAspectRatio = 0.85;
    if (isTablet) {
      childAspectRatio = 0.9;
    }
    if (isLargeTablet) {
      childAspectRatio = 1.0;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final animationDelay = Duration(milliseconds: 100 * (startIndex + index));

        return _buildAnimatedMenuCard(menuItems[index], animationDelay);
      },
    );
  }

  Widget _buildAnimatedMenuCard(DashboardMenuItem item, Duration delay) {
    return FadeInScale(
      duration: Duration(milliseconds: 500),
      delay: delay,
      child: OpenContainer(
        closedBuilder: (context, action) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: action,
              splashColor: item.iconColor.withOpacity(0.2),
              highlightColor: item.backgroundColor.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'menu_icon_${item.title}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.backgroundColor,
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              item.backgroundColor,
                              Color.alphaBlend(
                                item.iconColor.withOpacity(0.2),
                                item.backgroundColor,
                              ),
                            ],
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.iconColor,
                          size: 22,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        openBuilder: (context, action) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, item.routeName);
          });

          return Scaffold(
            appBar: AppBar(
              title: Text(item.title),
            ),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        transitionDuration: Duration(milliseconds: 600),
        closedColor: Colors.transparent,
        closedElevation: 0,
        openColor: Colors.transparent,
        openElevation: 0,
      ),
    );
  }
}

class DashboardMenuItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String routeName;

  DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.routeName,
  });
}

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 20),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _offsetAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.value = 1.0;
      } else if (status == AnimationStatus.dismissed) {
        _controller.value = 0.0;
      }
    });

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _opacityAnimation.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: _offsetAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class FadeInScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeInScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  @override
  State<FadeInScale> createState() => _FadeInScaleState();
}

class _FadeInScaleState extends State<FadeInScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );


    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.value = 1.0; // Pastikan value = 1.0
      } else if (status == AnimationStatus.dismissed) {
        _controller.value = 0.0; // Pastikan value = 0.0
      }
    });

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _opacityAnimation.value.clamp(0.0, 1.0);
        final scale = 0.9 + (0.1 * opacity);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class FadeScaleTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const FadeScaleTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * animation.value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}