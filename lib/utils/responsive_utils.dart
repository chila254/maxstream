import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if device is mobile (width < 600)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if device is tablet (600 <= width < 900)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if device is desktop (width >= 900)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive value based on screen size
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  /// Get responsive columns count for grids
  static int getColumnsCount(
    BuildContext context, {
    int mobileColumns = 2,
    int tabletColumns = 3,
    int desktopColumns = 4,
  }) {
    return responsive(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );
  }

  /// Get responsive horizontal padding
  static double getHorizontalPadding(BuildContext context) {
    return responsive(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  /// Get responsive card width for movie items
  static double getCardWidth(BuildContext context) {
    return responsive(context, mobile: 120.0, tablet: 140.0, desktop: 160.0);
  }

  /// Get responsive card height for movie items
  static double getCardHeight(BuildContext context) {
    return responsive(context, mobile: 180.0, tablet: 210.0, desktop: 240.0);
  }

  /// Get responsive font size
  static double getFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsive(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.1,
      desktop: desktop ?? mobile * 1.2,
    );
  }

  /// Get responsive spacing
  static double getSpacing(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsive(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.2,
      desktop: desktop ?? mobile * 1.5,
    );
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get responsive hero banner height
  static double getHeroBannerHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return responsive(
      context,
      mobile: height * 0.45,
      tablet: height * 0.5,
      desktop: height * 0.6,
    );
  }

  /// Get responsive grid spacing
  static double getGridSpacing(BuildContext context) {
    return responsive(context, mobile: 8.0, tablet: 12.0, desktop: 16.0);
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    return responsive(context, mobile: 80.0, tablet: 90.0, desktop: 100.0);
  }

  /// Get responsive navigation bar height
  static double getNavBarHeight(BuildContext context) {
    return responsive(context, mobile: 70.0, tablet: 80.0, desktop: 90.0);
  }

  /// Get responsive bottom sheet max height
  static double getBottomSheetMaxHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return height * 0.9;
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return responsive(
      context,
      mobile: width * 0.9,
      tablet: width * 0.7,
      desktop: width * 0.5,
    );
  }
}

/// Widget for building responsive layouts
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveUtils.responsive(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

/// Layout breakpoint widget
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Size size) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, MediaQuery.of(context).size);
  }
}
