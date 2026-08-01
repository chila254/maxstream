import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Enhanced dark mode container with subtle patterns and textures
/// TV-optimized with responsive sizing and focus states
class DarkModePanelEnhanced extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool addPattern;
  final bool addGlow;
  final Color glowColor;
  final bool isFocused;
  final Duration animationDuration;
  final VoidCallback? onTap;

  const DarkModePanelEnhanced({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12.0,
    this.addPattern = true,
    this.addGlow = false,
    this.glowColor = const Color(0xFFE50914),
    this.isFocused = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.onTap,
  });

  @override
  State<DarkModePanelEnhanced> createState() => _DarkModePanelEnhancedState();
}

class _DarkModePanelEnhancedState extends State<DarkModePanelEnhanced>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: widget.isFocused ? 1.0 : 0.0)
        .animate(
          CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
        );
    if (widget.isFocused) {
      _focusController.forward();
    }
  }

  @override
  void didUpdateWidget(DarkModePanelEnhanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _focusController.forward();
      } else {
        _focusController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onTap,
          child: MouseRegion(
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            child: Container(
              padding: widget.margin ?? EdgeInsets.zero,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: widget.animationDuration,
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: Border.all(
                        color: widget.isFocused
                            ? widget.glowColor.withValues(
                                alpha: 0.5 + (_focusAnimation.value * 0.5),
                              )
                            : Colors.grey[900]!,
                        width: 1 + (_focusAnimation.value * 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 12 + (_focusAnimation.value * 8),
                          spreadRadius: 0,
                        ),
                        if (widget.addGlow)
                          BoxShadow(
                            color: widget.glowColor.withValues(
                              alpha: 0.1 + (_focusAnimation.value * 0.3),
                            ),
                            blurRadius: 16 + (_focusAnimation.value * 12),
                            spreadRadius: 2 + (_focusAnimation.value * 2),
                          ),
                      ],
                    ),
                    child: widget.child,
                  ),
                  // Subtle noise pattern overlay
                  if (widget.addPattern)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius,
                        ),
                        child: CustomPaint(
                          painter: NoisePatternPainter(
                            opacity: 0.02 + (_focusAnimation.value * 0.03),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for subtle noise pattern
class NoisePatternPainter extends CustomPainter {
  final double opacity;

  NoisePatternPainter({this.opacity = 0.02});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..blendMode = BlendMode.overlay;

    // Create subtle grain pattern
    for (int i = 0; i < 100; i++) {
      final x = (i * 7.5) % size.width;
      final y = (i * 13.7) % size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(NoisePatternPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// Status bar with dynamic color matching and TV responsiveness
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
    final horizontalPadding = TvUtils.responsivePadding(16, context);
    final verticalPadding = TvUtils.responsivePadding(12, context);
    final iconSize = TvUtils.responsiveFontSize(24, context);
    final fontSize = TvUtils.responsiveFontSize(20, context);

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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                children: [
                  if (showBackButton)
                    GestureDetector(
                      onTap: onBackPressed,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: EdgeInsets.all(
                            TvUtils.responsivePadding(8, context),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(
                              TvUtils.responsivePadding(8, context),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: accentColor,
                            size: iconSize,
                          ),
                        ),
                      ),
                    ),
                  if (showBackButton)
                    SizedBox(width: TvUtils.responsivePadding(16, context)),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...?actions,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark mode divider with enhanced styling and TV responsiveness
/// Supports section headers and animated states
class EnhancedDivider extends StatelessWidget {
  final double? height;
  final Color? color;
  final bool addGradient;
  final EdgeInsetsGeometry? margin;
  final String? label;
  final bool showIcon;
  final IconData? icon;
  final TextStyle? labelStyle;
  final Alignment labelAlignment;

  const EnhancedDivider({
    super.key,
    this.height,
    this.color,
    this.addGradient = true,
    this.margin,
    this.label,
    this.showIcon = false,
    this.icon,
    this.labelStyle,
    this.labelAlignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final dividerHeight = height ?? TvUtils.responsivePadding(1, context);
    final dividerMargin =
        margin ??
        EdgeInsets.symmetric(vertical: TvUtils.responsivePadding(12, context));

    // If label is provided, build section divider
    if (label != null && label!.isNotEmpty) {
      return _buildSectionDivider(context, dividerHeight, dividerMargin);
    }

    // Standard divider
    if (addGradient) {
      return Container(
        margin: dividerMargin,
        height: dividerHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.grey[800]!, Colors.transparent],
          ),
        ),
      );
    }

    return Padding(
      padding: dividerMargin,
      child: Divider(height: dividerHeight, color: color ?? Colors.grey[800]),
    );
  }

  Widget _buildSectionDivider(
    BuildContext context,
    double dividerHeight,
    EdgeInsetsGeometry margin,
  ) {
    final fontSize = TvUtils.responsiveFontSize(14, context);
    final iconSize = TvUtils.responsiveFontSize(18, context);
    final padding = TvUtils.responsivePadding(12, context);

    final textStyle =
        labelStyle ??
        TextStyle(
          color: Colors.grey[300],
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );

    return Container(
      margin: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider line before label
          Container(
            height: dividerHeight,
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
          // Label with icon
          Padding(
            padding: EdgeInsets.symmetric(vertical: padding),
            child: Row(
              mainAxisAlignment: _getMainAxisAlignment(labelAlignment),
              children: [
                if (showIcon && icon != null) ...[
                  Icon(icon, color: Colors.grey[400], size: iconSize),
                  SizedBox(width: TvUtils.responsivePadding(8, context)),
                ],
                Flexible(
                  child: Text(
                    label!,
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Divider line after label
          Container(
            height: dividerHeight,
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
        ],
      ),
    );
  }

  MainAxisAlignment _getMainAxisAlignment(Alignment alignment) {
    if (alignment == Alignment.centerLeft) return MainAxisAlignment.start;
    if (alignment == Alignment.center) return MainAxisAlignment.center;
    return MainAxisAlignment.end;
  }
}

/// TV-optimized section header divider with animated icon
class SectionDivider extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isExpandable;

  const SectionDivider({
    super.key,
    required this.title,
    this.icon,
    this.accentColor = const Color(0xFFE50914),
    this.onTap,
    this.isExpandable = false,
  });

  @override
  State<SectionDivider> createState() => _SectionDividerState();
}

class _SectionDividerState extends State<SectionDivider>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 1.0).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
    );
    if (_isExpanded) {
      _expandController.forward();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = TvUtils.responsiveFontSize(16, context);
    final iconSize = TvUtils.responsiveFontSize(20, context);
    final padding = TvUtils.responsivePadding(12, context);

    final content = Row(
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: widget.accentColor, size: iconSize),
          SizedBox(width: TvUtils.responsivePadding(8, context)),
        ],
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.isExpandable)
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _expandAnimation.value * (3.14159 / 2),
                child: Icon(
                  Icons.chevron_right,
                  color: widget.accentColor,
                  size: iconSize,
                ),
              );
            },
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top divider
          Container(
            height: 1,
            margin: EdgeInsets.only(bottom: padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  widget.accentColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Title with optional expand button
          if (widget.isExpandable)
            GestureDetector(
              onTap: () {
                _toggleExpand();
                widget.onTap?.call();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: content,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: content,
            ),
          // Bottom divider
          Container(
            height: 1,
            margin: EdgeInsets.only(top: padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  widget.accentColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark mode app bar with enhanced contrast and TV responsiveness
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
    final fontSize = TvUtils.responsiveFontSize(24, context);
    final iconSize = TvUtils.responsiveFontSize(28, context);

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      leading: onBackPressed != null
          ? IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: const Color(0xFFE50914),
                size: iconSize,
              ),
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

/// Enhanced background with subtle patterns for dark mode and TV optimization
class DarkModeBackground extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final bool addPattern;
  final bool addGradientOverlay;
  final Color? accentColor;

  const DarkModeBackground({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF0F0F0F),
    this.addPattern = true,
    this.addGradientOverlay = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        gradient: addGradientOverlay && accentColor != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor,
                  baseColor.withValues(alpha: 0.95),
                  accentColor!.withValues(alpha: 0.05),
                ],
                stops: const [0.0, 0.5, 1.0],
              )
            : null,
      ),
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
  static bool meetsWcagAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }

  // Check if colors meet WCAG AAA standard (7:1 for normal text)
  static bool meetsWcagAAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 7.0;
  }
}
