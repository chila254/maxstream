import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Save profile picture as Base64 in Firebase RTDB (free, no Storage needed)
  static Future<String?> uploadProfilePicture(String imagePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final file = File(imagePath);
      if (!file.existsSync()) throw Exception('File does not exist');

      // Read and encode as base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Save to RTDB
      await _rtdb.ref('users/${user.uid}/profile').update({
        'profilePictureBase64': base64Image,
        'email': user.email,
        'displayName': user.displayName,
        'updatedAt': ServerValue.timestamp,
      });

      // Also cache locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_picture', imagePath);

      return imagePath;
    } catch (e) {
      print('Error saving profile picture: $e');
      rethrow;
    }
  }

  /// Fetch profile picture — tries local cache first, then RTDB base64
  static Future<String?> getProfilePicturePath() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check local cache first
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString('user_profile_picture');
      if (localPath != null && File(localPath).existsSync()) {
        return localPath;
      }

      // Fetch from RTDB and decode
      final snapshot = await _rtdb.ref('users/${user.uid}/profile').get();
      if (!snapshot.exists || snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final base64Image = data['profilePictureBase64'] as String?;
      if (base64Image == null || base64Image.isEmpty) return null;

      // Decode and save locally
      final bytes = base64Decode(base64Image);
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/profile_${user.uid}.jpg');
      await file.writeAsBytes(bytes);

      // Cache path
      await prefs.setString('user_profile_picture', file.path);
      return file.path;
    } catch (e) {
      print('Error loading profile picture: $e');
      return null;
    }
  }

  /// Delete profile picture from RTDB and local cache
  static Future<void> deleteProfilePicture() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Remove from RTDB
      await _rtdb
          .ref('users/${user.uid}/profile/profilePictureBase64')
          .remove();

      // Remove local cache
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString('user_profile_picture');
      if (localPath != null && File(localPath).existsSync()) {
        await File(localPath).delete();
      }
      await prefs.remove('user_profile_picture');
    } catch (e) {
      print('Error deleting profile picture: $e');
      rethrow;
    }
  }

  /// Fetch full user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _rtdb.ref('users/${user.uid}/profile').get();
      if (!snapshot.exists || snapshot.value == null) return null;

      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
