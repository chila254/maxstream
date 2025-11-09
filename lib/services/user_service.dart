import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final ValueNotifier<String> avatar = ValueNotifier<String>('🐰');

  Future<void> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    avatar.value = prefs.getString('user_avatar') ?? '🐰';
  }

  Future<void> updateAvatar(String newAvatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', newAvatar);
    avatar.value = newAvatar;
  }
}