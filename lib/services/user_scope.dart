import 'package:firebase_auth/firebase_auth.dart';

/// Resolves the local-data owner without requiring callers to know about auth.
class UserScope {
  static const String anonymousOwner = '__anonymous__';
  static const String legacyOwner = '__legacy__';

  static String Function()? ownerResolver;

  static String get currentOwner {
    final injected = ownerResolver;
    if (injected != null) return _normalize(injected());
    try {
      return _normalize(FirebaseAuth.instance.currentUser?.uid);
    } catch (_) {
      return anonymousOwner;
    }
  }

  static String _normalize(String? owner) {
    final value = owner?.trim() ?? '';
    return value.isEmpty ? anonymousOwner : value;
  }
}
