import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile picture to Firebase Storage and save URL to Firestore
  static Future<String?> uploadProfilePicture(String imagePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final file = File(imagePath);
      if (!file.existsSync()) throw Exception('File does not exist');

      // Upload to Firebase Storage with user ID as path
      final storageRef = _storage.ref().child('profile_pictures/${user.uid}.jpg');
      final uploadTask = storageRef.putFile(file);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL from the completed upload snapshot
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save URL to Firestore
      await _firestore.collection('users').doc(user.uid).set(
        {
          'profilePictureUrl': downloadUrl,
          'email': user.email,
          'displayName': user.displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Fetch profile picture URL from Firestore
  static Future<String?> getProfilePictureUrl() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return doc.data()?['profilePictureUrl'] as String?;
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

      // Delete from Storage
      await _storage.ref().child('profile_pictures/${user.uid}.jpg').delete();

      // Remove from Firestore
      await _firestore.collection('users').doc(user.uid).set(
        {'profilePictureUrl': null},
        SetOptions(merge: true),
      );
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

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}
