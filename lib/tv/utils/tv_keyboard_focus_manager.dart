import 'package:flutter/material.dart';

/// Manages focus state between keyboard and content grid
/// Prevents D-Pad interference when keyboard is active
class TvKeyboardFocusManager extends ChangeNotifier {
  bool _isKeyboardActive = false;
  bool _isFocusedOnContent = false;

  bool get isKeyboardActive => _isKeyboardActive;
  bool get isFocusedOnContent => _isFocusedOnContent;

  /// Call when showing keyboard
  void activateKeyboard() {
    _isKeyboardActive = true;
    _isFocusedOnContent = false;
    notifyListeners();
  }

  /// Call when hiding keyboard
  void deactivateKeyboard() {
    _isKeyboardActive = false;
    notifyListeners();
  }

  /// Call when focusing on content grid
  void focusOnContent() {
    _isFocusedOnContent = true;
    _isKeyboardActive = false;
    notifyListeners();
  }

  /// Call when leaving content focus
  void unfocusContent() {
    _isFocusedOnContent = false;
    notifyListeners();
  }

  /// Toggle between keyboard and content
  void toggleFocus() {
    if (_isKeyboardActive) {
      focusOnContent();
    } else {
      activateKeyboard();
    }
  }

  /// Reset to initial state
  void reset() {
    _isKeyboardActive = false;
    _isFocusedOnContent = false;
    notifyListeners();
  }
}
