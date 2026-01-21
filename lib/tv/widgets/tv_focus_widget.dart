import 'package:flutter/material.dart';

/// Enhanced reusable widget for TV content card with smooth scale/zoom animations
/// and elevation/shadow effects on focus
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
    this.animationDuration = const Duration(milliseconds: 300),
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
  late Animation<double> _elevationAnimation;

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

    _elevationAnimation = Tween<double>(begin: 0.0, end: 20.0).animate(
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
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isFocused && widget.showShadow
                ? [
                    BoxShadow(
                      color: widget.shadowColor.withOpacity(0.6),
                      blurRadius: _elevationAnimation.value * 1.5,
                      spreadRadius: _elevationAnimation.value * 0.5,
                      offset: Offset(0, _elevationAnimation.value * 0.3),
                    ),
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.3),
                      blurRadius: _elevationAnimation.value,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Enhanced reusable widget for TV UI buttons/fields with smooth focus animations
/// Includes border color transition, background animation, and shadow effects
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

class _TvFocusButtonState extends State<TvFocusButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.isFocused) {
      _focusAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(TvFocusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _focusAnimationController.forward();
      } else {
        _focusAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _focusAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, _) {
        final borderColor = !widget.enabled
            ? widget.disabledBorderColor
            : Color.lerp(
                widget.enabledBorderColor,
                widget.focusedBorderColor,
                _focusAnimation.value,
              ) ??
                widget.enabledBorderColor;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: widget.borderWidth),
            borderRadius: widget.borderRadius,
            color: _isPressed
                ? widget.pressedBgColor
                : Colors.white.withOpacity(0.05 * _focusAnimation.value),
            boxShadow: widget.isFocused
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2 * _focusAnimation.value),
                      blurRadius: 10 * _focusAnimation.value,
                      spreadRadius: 2 * _focusAnimation.value,
                    ),
                  ]
                : null,
          ),
          padding: widget.padding,
          child: GestureDetector(
            onTapDown: widget.enabled
                ? (_) => setState(() => _isPressed = true)
                : null,
            onTapUp: widget.enabled
                ? (_) => setState(() => _isPressed = false)
                : null,
            onTapCancel:
                widget.enabled ? () => setState(() => _isPressed = false) : null,
            onTap: widget.enabled ? widget.onTap : null,
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.6,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Enhanced reusable widget for TV menu items with smooth focus animations
/// Includes scale, glow, and smooth state transitions
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
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isFocused
                ? Colors.white
                : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: widget.isFocused && widget.showGlow
              ? [
                  // Outer glow
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.5 * _glowAnimation.value),
                    blurRadius: 20,
                    spreadRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                  // Inner accent glow
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                ]
              : null,
        ),
        child: child,
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
