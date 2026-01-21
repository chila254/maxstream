import 'package:flutter/material.dart';

/// Mixin for TV content screens to prevent freezing
/// Ensures content loads asynchronously without blocking UI
mixin TvContentScreenMixin<T extends StatefulWidget> on State<T> {
  /// Track if screen is mounted and active
  bool _isScreenActive = true;

  /// Load heavy data asynchronously (non-blocking)
  /// Use this instead of blocking operations in initState
  @protected
  Future<void> loadContentAsync() async {
    // Override in your screen
  }

  /// Safely update state only if screen is still mounted and active
  @protected
  void safeSetState(VoidCallback fn) {
    if (mounted && _isScreenActive) {
      setState(fn);
    }
  }

  /// Handle page visibility - pause heavy operations when not visible
  @override
  void deactivate() {
    _isScreenActive = false;
    super.deactivate();
  }

  @override
  void activate() {
    _isScreenActive = true;
    super.activate();
  }

  @override
  void dispose() {
    _isScreenActive = false;
    super.dispose();
  }

  /// Build error widget with retry
  Widget buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build loading widget
  Widget buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Colors.red),
      ),
    );
  }
}
