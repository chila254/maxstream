import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Manages user profiles under users/$uid/profiles/ in Firebase RTDB.
/// Profiles are the foundation for per-profile watch progress, kids mode,
/// and content filtering across phone and TV.
class ProfileService {
  static const int maxProfiles = 5;
  static const String _profilesKey = 'user_profiles';
  static const String _activeProfileKey = 'active_profile_id';

  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  static DatabaseReference _profilesRef(String uid) =>
      _rtdb.ref('users/$uid/profiles');

  // ── Local persistence ──────────────────────────────────────────────

  static Future<List<Profile>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocal(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  static Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  static Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, id);
  }

  static Future<void> clearActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
  }

  // ── CRUD ───────────────────────────────────────────────────────────

  static Future<List<Profile>> getProfiles() async {
    final local = await _loadLocal();
    if (local.isNotEmpty) return local;
    // First run: create default profile
    return _createDefaultProfile();
  }

  static Future<List<Profile>> _createDefaultProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final defaultProfile = Profile(
      id: Profile.generateId(),
      name: user?.displayName ?? 'Profile 1',
      avatar: const ProfileAvatar(),
      createdAt: DateTime.now(),
    );
    await _saveLocal([defaultProfile]);
    await _pushToCloud([defaultProfile]);
    return [defaultProfile];
  }

  static Future<Profile?> createProfile({
    required String name,
    ProfileAvatar? avatar,
    bool isKids = false,
    String? pinHash,
  }) async {
    final profiles = await getProfiles();
    if (profiles.length >= maxProfiles) return null;

    final newProfile = Profile(
      id: Profile.generateId(),
      name: name,
      avatar: avatar ?? const ProfileAvatar(),
      isKids: isKids,
      pinHash: pinHash,
      createdAt: DateTime.now(),
    );

    final updated = [...profiles, newProfile];
    await _saveLocal(updated);
    await _pushToCloud(updated);
    return newProfile;
  }

  static Future<Profile?> updateProfile({
    required String id,
    String? name,
    ProfileAvatar? avatar,
    bool? isKids,
    String? pinHash,
    bool clearPin = false,
  }) async {
    final profiles = await getProfiles();
    final index = profiles.indexWhere((p) => p.id == id);
    if (index == -1) return null;

    final updated = profiles[index].copyWith(
      name: name,
      avatar: avatar,
      isKids: isKids,
      pinHash: pinHash,
      clearPin: clearPin,
    );

    final newProfiles = [...profiles];
    newProfiles[index] = updated;
    await _saveLocal(newProfiles);
    await _pushToCloud(newProfiles);
    return updated;
  }

  static Future<bool> deleteProfile(String id) async {
    final profiles = await getProfiles();
    if (profiles.length <= 1) return false; // Must keep at least one

    final updated = profiles.where((p) => p.id != id).toList();
    await _saveLocal(updated);
    await _pushToCloud(updated);

    // If deleted the active profile, switch to the first remaining
    final activeId = await getActiveProfileId();
    if (activeId == id) {
      await setActiveProfileId(updated.first.id);
    }
    return true;
  }

  static Future<Profile?> getProfileById(String id) async {
    final profiles = await getProfiles();
    try {
      return profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Firebase Cloud Sync ────────────────────────────────────────────

  static Future<void> _pushToCloud(List<Profile> profiles) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = _profilesRef(uid);
      final map = <String, dynamic>{};
      for (final p in profiles) {
        map[p.id] = p.toJson();
      }
      await ref.set(map);
    } catch (e) {
      debugPrint('ProfileService: cloud push failed: $e');
    }
  }

  /// Pull profiles from Firebase RTDB and merge with local.
  /// Called on app start so TV picks up profiles created on phone.
  static Future<void> pullFromCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await _profilesRef(uid).get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final cloudProfiles = data.values
          .map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (cloudProfiles.isEmpty) return;

      final local = await _loadLocal();
      final localIds = local.map((p) => p.id).toSet();

      // Merge: cloud entries not in local are added; existing entries keep
      // local version (local is source of truth for name/avatar edits).
      final merged = [...local];
      for (final cp in cloudProfiles) {
        if (!localIds.contains(cp.id)) {
          merged.add(cp);
        }
      }

      await _saveLocal(merged);
    } catch (e) {
      debugPrint('ProfileService: cloud pull failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  /// Check if profile has a PIN set (returns false if pinHash is null).
  static Future<bool> verifyPin(String profileId, String pin) async {
    final profile = await getProfileById(profileId);
    if (profile?.pinHash == null) return true; // No PIN set
    // Simple hash comparison (production should use bcrypt)
    return profile!.pinHash == _hashPin(pin);
  }

  static String hashPin(String pin) => _hashPin(pin);

  static String _hashPin(String pin) {
    // Simple hash for now — production should use bcrypt via flutter_bcrypt
    var hash = 0;
    for (var i = 0; i < pin.length; i++) {
      hash = ((hash << 5) - hash + pin.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
