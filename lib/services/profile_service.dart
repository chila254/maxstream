import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile picture to Firebase Storage and save URL to RTDB
  static Future<String?> uploadProfilePicture(String imagePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final file = File(imagePath);
      if (!file.existsSync()) throw Exception('File does not exist');

      // Upload to Firebase Storage with user ID as path
      final storageRef = _storage.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );
      final uploadTask = storageRef.putFile(file);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL from the completed upload snapshot
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save URL to RTDB
      await _rtdb.ref('users/${user.uid}/profile').update({
        'profilePictureUrl': downloadUrl,
        'email': user.email,
        'displayName': user.displayName,
        'updatedAt': ServerValue.timestamp,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Fetch profile picture URL from RTDB
  static Future<String?> getProfilePictureUrl() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _rtdb.ref('users/${user.uid}/profile').get();
      if (!snapshot.exists || snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data['profilePictureUrl'] as String?;
    } catch (e) {
      print('Error fetching profile picture URL: $e');
      return null;
    }
  }

  /// Delete profile picture from Firebase
  static Future<void> deleteProfilePicture() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Delete from Storage (ignore if file doesn't exist)
      try {
        await _storage.ref().child('profile_pictures/${user.uid}.jpg').delete();
      } catch (e) {
        // Ignore not-found errors — file may never have been uploaded
      }

      // Remove from RTDB
      await _rtdb.ref('users/${user.uid}/profile/profilePictureUrl').remove();
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
