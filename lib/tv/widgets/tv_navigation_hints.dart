import 'package:flutter/material.dart';

/// Visual indicator showing which navigation zone is currently focused
/// Helps users understand focus position in complex TV navigation
class TvFocusIndicator extends StatelessWidget {
  final String focusZone; // e.g., 'Keyboard', 'Search Results', 'Sidebar'
  final bool isVisible;
  final Duration animationDuration;

  const TvFocusIndicator({
    super.key,
    required this.focusZone,
    this.isVisible = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: animationDuration,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE50914).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, color: Colors.white, size: 8),
            const SizedBox(width: 8),
            Text(
              'Focus: $focusZone',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating focus indicator for quick reference
class FloatingFocusIndicator extends StatelessWidget {
  final String focusZone;
  final bool isVisible;
  final Alignment alignment;

  const FloatingFocusIndicator({
    super.key,
    required this.focusZone,
    this.isVisible = true,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TvFocusIndicator(focusZone: focusZone, isVisible: isVisible),
      ),
    );
  }
}

/// D-Pad hint overlay showing available navigation options
class DPadNavigationHint extends StatelessWidget {
  final bool showUp;
  final bool showDown;
  final bool showLeft;
  final bool showRight;
  final String? upLabel;
  final String? downLabel;
  final String? leftLabel;
  final String? rightLabel;
  final bool isVisible;

  const DPadNavigationHint({
    super.key,
    this.showUp = true,
    this.showDown = true,
    this.showLeft = true,
    this.showRight = true,
    this.upLabel,
    this.downLabel,
    this.leftLabel,
    this.rightLabel,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showUp) _buildHintBadge(upLabel ?? 'Up', Icons.arrow_upward),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLeft)
              _buildHintBadge(leftLabel ?? 'Left', Icons.arrow_back),
            const SizedBox(width: 8),
            if (showRight)
              _buildHintBadge(rightLabel ?? 'Right', Icons.arrow_forward),
          ],
        ),
        const SizedBox(height: 8),
        if (showDown)
          _buildHintBadge(downLabel ?? 'Down', Icons.arrow_downward),
      ],
    );
  }

  Widget _buildHintBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        border: Border.all(color: const Color(0xFFE50914), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE50914), size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keyboard help overlay for search screen
class KeyboardHelpOverlay extends StatelessWidget {
  final bool isVisible;
  final VoidCallback? onDismiss;

  const KeyboardHelpOverlay({super.key, this.isVisible = true, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE50914).withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Keyboard Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpRow('↑↓←→', 'Navigate keyboard'),
          _buildHelpRow('SELECT', 'Choose letter'),
          _buildHelpRow('BACKSPACE', 'Delete character'),
          _buildHelpRow('SPACE', 'Add space'),
          _buildHelpRow('DONE', 'Start search'),
        ],
      ),
    );
  }

  Widget _buildHelpRow(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withOpacity(0.2),
              border: Border.all(color: const Color(0xFFE50914), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFFE50914),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            description,
            style: TextStyle(color: Colors.grey[300], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
