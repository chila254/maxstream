import 'package:flutter/material.dart';

/// Reusable widget for TV content card with scale animation on focus
class TvContentFocusCard extends StatefulWidget {
  final Widget child;
  final bool isFocused;
  final VoidCallback onTap;
  final Duration animationDuration;
  final double scale;
  final bool showShadow;
  final Color shadowColor;

  const TvContentFocusCard({
    super.key,
    required this.child,
    required this.isFocused,
    required this.onTap,
    this.animationDuration = const Duration(milliseconds: 200),
    this.scale = 1.1,
    this.showShadow = true,
    this.shadowColor = const Color.fromARGB(100, 255, 255, 255),
  });

  @override
  State<TvContentFocusCard> createState() => _TvContentFocusCardState();
}

class _TvContentFocusCardState extends State<TvContentFocusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(TvContentFocusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: widget.isFocused
            ? BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
              )
            : null,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

/// Reusable widget for TV UI buttons/fields with white border focus
class TvFocusButton extends StatefulWidget {
  final Widget child;
  final bool isFocused;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double borderWidth;
  final EdgeInsets padding;
  final bool enabled;
  final Color enabledBorderColor;
  final Color disabledBorderColor;
  final Color focusedBorderColor;
  final Color pressedBgColor;

  const TvFocusButton({
    super.key,
    required this.child,
    required this.isFocused,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.borderWidth = 3,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
    this.enabledBorderColor = Colors.transparent,
    this.disabledBorderColor = const Color.fromARGB(255, 120, 120, 120),
    this.focusedBorderColor = Colors.white,
    this.pressedBgColor = const Color.fromARGB(50, 255, 255, 255),
  });

  @override
  State<TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<TvFocusButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = !widget.enabled
        ? widget.disabledBorderColor
        : widget.isFocused
            ? widget.focusedBorderColor
            : widget.enabledBorderColor;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: widget.borderWidth),
        borderRadius: widget.borderRadius,
        color: _isPressed ? widget.pressedBgColor : null,
      ),
      padding: widget.padding,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.6,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Reusable widget for TV menu items with white border focus and optional scale
class TvMenuItem extends StatefulWidget {
  final Widget child;
  final bool isFocused;
  final VoidCallback onTap;
  final bool useScale;
  final double scale;
  final bool showGlow;
  final Color glowColor;

  const TvMenuItem({
    super.key,
    required this.child,
    required this.isFocused,
    required this.onTap,
    this.useScale = false,
    this.scale = 1.05,
    this.showGlow = true,
    this.glowColor = const Color.fromARGB(100, 255, 255, 255),
  });

  @override
  State<TvMenuItem> createState() => _TvMenuItemState();
}

class _TvMenuItemState extends State<TvMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(TvMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: widget.isFocused
            ? Border.all(color: Colors.white, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: widget.isFocused && widget.showGlow
            ? [
                BoxShadow(
                  color: widget.glowColor,
                  blurRadius: 15,
                  spreadRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ]
            : null,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.useScale
            ? ScaleTransition(scale: _scaleAnimation, child: widget.child)
            : widget.child,
      ),
    );
  }
}
