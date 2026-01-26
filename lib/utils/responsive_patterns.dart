import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'responsive_helper.dart';

class ResponsivePatterns {
  // Responsive Container Card
  static Widget responsiveCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
    Color backgroundColor = Colors.white,
    double borderRadius = 12.0,
    bool withShadow = true,
    bool withBorder = false,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: withBorder
            ? Border.all(color: Colors.grey.shade200, width: 1)
            : null,
        boxShadow: withShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ]
            : null,
      ),
      padding: padding ?? EdgeInsets.all(isMobile ? 12 : 16),
      child: child,
    );
  }

  // Responsive Grid Layout - SIMPLE VERSION
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    double spacing = 12.0,
    double runSpacing = 12.0,
    bool shrinkWrap = false,
  }) {
    final columns = ResponsiveHelper.responsiveGridColumns(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? NeverScrollableScrollPhysics() : null,
      childAspectRatio: _getGridAspectRatio(columns),
      children: children,
    );
  }

  static double _getGridAspectRatio(int columns) {
    if (columns == 1) return 3.0; // Mobile portrait
    if (columns == 2) return 1.5; // Tablet
    return 1.2; // Desktop
  }

  // Responsive List Tile
  static Widget responsiveListTile({
    required BuildContext context,
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsets? contentPadding,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: contentPadding ?? EdgeInsets.symmetric(
            vertical: isMobile ? 10 : 12,
            horizontal: isMobile ? 12 : 16,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey.shade600,
                        ),
                        child: subtitle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}