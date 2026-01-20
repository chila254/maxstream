import 'package:flutter/material.dart';
import 'dart:math';

class TvUtils {
  /// Get responsive size based on screen diagonal (inches)
  /// Assumes 24 DPI (dots per inch) on Android TV
  static double getScreenDiagonal(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate diagonal in pixels, then convert to inches
    final diagonalPixels =
        sqrt(size.width * size.width + size.height * size.height);
    final dpi = devicePixelRatio * 160; // Standard Android DPI
    final diagonalInches = diagonalPixels / dpi;

    return diagonalInches;
  }

  /// Get scale factor based on screen size
  /// 22" = 1.0x, scales up to 100" = 2.5x
  static double getScaleFactor(BuildContext context) {
    final diagonal = getScreenDiagonal(context);

    if (diagonal <= 22) return 1.0;
    if (diagonal <= 24) return 1.1;
    if (diagonal <= 28) return 1.2;
    if (diagonal <= 32) return 1.4;
    if (diagonal <= 40) return 1.6;
    if (diagonal <= 43) return 1.8;
    if (diagonal <= 50) return 2.0;
    if (diagonal <= 65) return 2.2;
    return 2.5; // 100"+
  }

  /// Responsive font size
  static double responsiveFontSize(
    double baseSize,
    BuildContext context, {
    double minSize = 8,
    double maxSize = 120,
  }) {
    final scale = getScaleFactor(context);
    final size = baseSize * scale;
    return size.clamp(minSize, maxSize);
  }

  /// Responsive padding
  static double responsivePadding(
    double basePadding,
    BuildContext context, {
    double maxPadding = 200,
  }) {
    final scale = getScaleFactor(context);
    return (basePadding * scale).clamp(0, maxPadding);
  }

  /// Responsive button height
  static double responsiveButtonHeight(BuildContext context) {
    final scale = getScaleFactor(context);
    return (64 * scale).clamp(48, 200);
  }

  /// Responsive width
  static double responsiveWidth(
    double baseWidth,
    BuildContext context, {
    double maxWidth = 500,
  }) {
    final scale = getScaleFactor(context);
    return (baseWidth * scale).clamp(0, maxWidth);
  }

  /// Responsive input height
  static double responsiveInputHeight(BuildContext context) {
    final scale = getScaleFactor(context);
    return (56 * scale).clamp(48, 150);
  }

  /// Check if TV is in landscape
  static bool isTvLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// Get optimal content width for TV
  static double getOptimalContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // For TV landscape: use 60-70% of screen width
    if (isTvLandscape(context)) {
      return (screenWidth * 0.65).clamp(400, 1200);
    }
    return screenWidth * 0.9;
  }
}

/// TV-optimized button style
class TvButtonStyle {
  static ButtonStyle getLargeButton(BuildContext context) {
    final buttonHeight = TvUtils.responsiveButtonHeight(context);

    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFE50914),
      padding: EdgeInsets.symmetric(vertical: buttonHeight / 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          TvUtils.responsivePadding(12, context),
        ),
      ),
    );
  }

  static ButtonStyle getTabButton(
    BuildContext context, {
    bool isSelected = false,
  }) {
    final padding = TvUtils.responsivePadding(16, context);

    return TextButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: padding * 2,
        vertical: padding,
      ),
    );
  }
}

/// TV-optimized input decoration
class TvInputDecoration {
  static InputDecoration getLargeInput(
    BuildContext context, {
    String hintText = '',
    Widget? suffixIcon,
  }) {
    final padding = TvUtils.responsivePadding(16, context);
    final borderRadius =
        TvUtils.responsivePadding(12, context);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey,
        fontSize: TvUtils.responsiveFontSize(18, context, maxSize: 36),
      ),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.all(padding),
      suffixIcon: suffixIcon,
    );
  }
}
