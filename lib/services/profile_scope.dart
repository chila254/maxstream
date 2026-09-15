import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile.dart';
import 'profile_service.dart';

/// Manages the currently active profile across the app.
/// Provides the active profile ID for per-profile data isolation
/// (watch progress, Continue Watching, preferences).
class ProfileScope {
  static const String _defaultProfileSuffix = '__default__';

  static Profile? _activeProfile;
  static List<Profile> _profiles = [];
  static bool _initialized = false;

  /// ValueNotifier that screens can listen to for profile changes.
  static final ValueNotifier<Profile?> activeProfile =
      ValueNotifier<Profile?>(null);

  static final ValueNotifier<List<Profile>> profiles =
      ValueNotifier<List<Profile>>([]);

  /// The active profile ID used as key in SharedPreferences and RTDB.
  /// Falls back to the Firebase UID if no profile is selected (legacy mode).
  static String get currentProfileId {
    return _activeProfile?.id ?? _firebaseUid ?? _defaultProfileSuffix;
  }

  /// Whether the current profile is a kids profile.
  static bool get isKidsProfile => _activeProfile?.isKids ?? false;

  /// The active profile name for display.
  static String get currentProfileName =>
      _activeProfile?.name ?? 'Default Profile';

  static String? get _firebaseUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ── Initialization ─────────────────────────────────────────────────

  /// Call once at app start to restore the last-active profile.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Pull profiles from cloud first (TV picks up phone-created profiles)
    await ProfileService.pullFromCloud();

    _profiles = await ProfileService.getProfiles();
    profiles.value = _profiles;

    final savedId = await ProfileService.getActiveProfileId();
    if (savedId != null) {
      _activeProfile = _profiles.where((p) => p.id == savedId).firstOrNull;
    }

    // Auto-select if only one profile
    if (_activeProfile == null && _profiles.length == 1) {
      _activeProfile = _profiles.first;
      await ProfileService.setActiveProfileId(_activeProfile!.id);
    }

    activeProfile.value = _activeProfile;
  }

  // ── Profile Selection ──────────────────────────────────────────────

  static Future<void> selectProfile(String profileId) async {
    final match = _profiles.where((p) => p.id == profileId);
    if (match.isEmpty) return;

    _activeProfile = match.first;
    await ProfileService.setActiveProfileId(profileId);
    activeProfile.value = _activeProfile;
  }

  /// Refresh profiles from storage (after create/edit/delete).
  static Future<void> refresh() async {
    _profiles = await ProfileService.getProfiles();
    profiles.value = _profiles;

    final savedId = await ProfileService.getActiveProfileId();
    if (savedId != null) {
      _activeProfile = _profiles.where((p) => p.id == savedId).firstOrNull;
      activeProfile.value = _activeProfile;
    }
  }

  /// Clear active profile (on sign out).
  static Future<void> clear() async {
    _activeProfile = null;
    _profiles = [];
    _initialized = false;
    await ProfileService.clearActiveProfile();
    activeProfile.value = null;
    profiles.value = [];
  }

  /// Whether the user needs to select a profile (multiple profiles, none selected).
  static bool get needsProfileSelection {
    return _profiles.length > 1 && _activeProfile == null;
  }

  /// Whether the user has only the default single profile (can skip selection).
  static bool get hasSingleProfile => _profiles.length <= 1;
}
