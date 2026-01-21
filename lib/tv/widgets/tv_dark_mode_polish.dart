import 'package:flutter/material.dart';

/// Enhanced dark mode container with subtle patterns and textures
class DarkModePanelEnhanced extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool addPattern;
  final bool addGlow;
  final Color glowColor;

  const DarkModePanelEnhanced({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12.0,
    this.addPattern = true,
    this.addGlow = false,
    this.glowColor = const Color(0xFFE50914),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: margin ?? EdgeInsets.zero,
      child: Stack(
        children: [
          Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.grey[900]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
                if (addGlow)
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: child,
          ),
          // Subtle noise pattern overlay
          if (addPattern)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CustomPaint(painter: NoisePatternPainter()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for subtle noise pattern
class NoisePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..blendMode = BlendMode.overlay;

    // Create subtle grain pattern
    for (int i = 0; i < 100; i++) {
      final x = (i * 7.5) % size.width;
      final y = (i * 13.7) % size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(NoisePatternPainter oldDelegate) => false;
}

/// Status bar with dynamic color matching
class EnhancedStatusBar extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const EnhancedStatusBar({
    super.key,
    required this.title,
    this.accentColor = const Color(0xFFE50914),
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Colors.grey[900]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Background gradient based on accent color
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.05),
                      accentColor.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (showBackButton)
                    GestureDetector(
                      onTap: onBackPressed,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  if (showBackButton) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark mode divider with enhanced styling
class EnhancedDivider extends StatelessWidget {
  final double height;
  final Color? color;
  final bool addGradient;

  const EnhancedDivider({
    super.key,
    this.height = 1,
    this.color,
    this.addGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    if (addGradient) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.grey[800]!, Colors.transparent],
          ),
        ),
      );
    }

    return Divider(height: height, color: color ?? Colors.grey[800]);
  }
}

/// Dark mode app bar with enhanced contrast
class DarkModeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final double elevation;

  const DarkModeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBackPressed,
    this.elevation = 4,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      leading: onBackPressed != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFE50914)),
              onPressed: onBackPressed,
            )
          : null,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.grey[800]!,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// Enhanced background with subtle patterns for dark mode
class DarkModeBackground extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final bool addPattern;

  const DarkModeBackground({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF0F0F0F),
    this.addPattern = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: baseColor,
      child: Stack(
        children: [
          // Base content
          child,
          // Subtle pattern overlay
          if (addPattern)
            Positioned.fill(
              child: CustomPaint(painter: SubtlePatternPainter()),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for subtle background pattern
class SubtlePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.01)
      ..strokeWidth = 0.5;

    // Draw subtle grid pattern
    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(SubtlePatternPainter oldDelegate) => false;
}

/// Contrast ratio checker - ensures text meets WCAG AA standards
class ContrastRatioHelper {
  // Calculate relative luminance
  static double _getLuminance(Color color) {
    final rgb = [color.red, color.green, color.blue].map((int value) {
      final v = value / 255.0;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * 1.055 * 1.055;
    }).toList();

    return (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2]);
  }

  // Calculate contrast ratio between two colors
  static double getContrastRatio(Color color1, Color color2) {
    final lum1 = _getLuminance(color1);
    final lum2 = _getLuminance(color2);

    final lighter = lum1 > lum2 ? lum1 : lum2;
    final darker = lum1 < lum2 ? lum1 : lum2;

    return (lighter + 0.05) / (darker + 0.05);
  }

  // Check if colors meet WCAG AA standard (4.5:1 for normal text)
  static bool meetsWCAG_AA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }

  // Check if colors meet WCAG AAA standard (7:1 for normal text)
  static bool meetsWCAG_AAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 7.0;
  }
}
