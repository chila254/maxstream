import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'profile_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final ValueNotifier<String> avatar = ValueNotifier<String>('🐰');
  final ValueNotifier<String?> profilePictureUrl = ValueNotifier<String?>(null);

  Future<void> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    avatar.value = prefs.getString('user_avatar') ?? '🐰';
  }

  Future<void> loadProfilePicture() async {
    try {
      final path = await ProfileService.getProfilePicturePath();
      if (path != null) {
        profilePictureUrl.value = path;
        return;
      }
    } catch (e) {
      print('Error loading profile picture: $e');
    }

    // Fallback to local cache
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('user_profile_picture');
    if (savedPath != null && File(savedPath).existsSync()) {
      profilePictureUrl.value = savedPath;
    }
  }

  Future<void> updateAvatar(String newAvatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', newAvatar);
    avatar.value = newAvatar;
  }

  Future<void> updateProfilePicture(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    if (File(imagePath).existsSync()) {
      await prefs.setString('user_profile_picture', imagePath);
      profilePictureUrl.value = imagePath;
    }
  }

  Future<void> clearProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile_picture');
    profilePictureUrl.value = null;
  }

  String? getProfilePicturePath() {
    final path = profilePictureUrl.value;
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }
}
