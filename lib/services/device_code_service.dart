import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:async';

class DeviceCodeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a 6-digit code and save to Firestore
  static Future<String> generateDeviceCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('Starting device code generation for user: ${user.uid}');

      // Generate random 6-digit code
      final code = (100000 + Random().nextInt(900000)).toString();
      print('Generated code: $code');
      
      // Save to Firestore with 15-minute expiry
      final expiresAt = DateTime.now().add(const Duration(minutes: 15));
      
      print('Writing to Firestore collection: device_codes');
      
      // Use exponential backoff retry logic
      int retryCount = 0;
      const maxRetries = 3;
      const baseDelay = Duration(milliseconds: 500);
      
      while (retryCount < maxRetries) {
        try {
          await _firestore.collection('device_codes').doc(code).set({
            'code': code,
            'userId': user.uid,
            'email': user.email,
            'displayName': user.displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expiresAt),
            'isUsed': false,
          }).timeout(
            const Duration(seconds: 30), // Increased from 10 to 30 seconds
            onTimeout: () {
              throw TimeoutException('Firestore write operation timed out after 30 seconds');
            },
          );
          
          print('Successfully saved device code: $code');
          return code;
        } on TimeoutException {
          retryCount++;
          if (retryCount < maxRetries) {
            final delay = baseDelay * (1 << (retryCount - 1)); // Exponential backoff
            print('Timeout on attempt $retryCount, retrying in ${delay.inMilliseconds}ms...');
            await Future.delayed(delay);
          } else {
            print('Max retries reached. Failed to save device code.');
            throw TimeoutException('Failed to generate pairing code after $maxRetries attempts. Please check your internet connection and try again.');
          }
        }
      }
      
      throw Exception('Failed to generate device code');
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      throw Exception(e.toString());
    } on FirebaseException catch (e) {
      print('Firebase error generating device code: ${e.code} - ${e.message}');
      throw Exception('Firebase error: ${e.message}');
    } catch (e) {
      print('Error generating device code: $e');
      rethrow;
    }
  }

  /// Validate code and return user email
  static Future<Map<String, String>> validateDeviceCode(String code) async {
    try {
      final doc = await _firestore.collection('device_codes').doc(code).get();
      
      if (!doc.exists) {
        throw Exception('Invalid code');
      }

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isUsed = data['isUsed'] as bool;

      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Code expired');
      }

      // Check if already used
      if (isUsed) {
        throw Exception('Code already used');
      }

      // Mark as used
      await _firestore.collection('device_codes').doc(code).update({
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return {
        'email': data['email'] as String,
        'userId': data['userId'] as String,
        'displayName': data['displayName'] as String? ?? '',
      };
    } catch (e) {
      print('Error validating device code: $e');
      rethrow;
    }
  }

  /// Get active codes for current user (to display)
  static Future<List<Map<String, dynamic>>> getActiveCodes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('device_codes')
          .where('userId', isEqualTo: user.uid)
          .where('isUsed', isEqualTo: false)
          .get();

      return snapshot.docs
          .map((doc) => {
            'code': doc['code'],
            'expiresAt': doc['expiresAt'],
          })
          .toList();
    } catch (e) {
      print('Error fetching codes: $e');
      return [];
    }
  }

  /// Revoke a code before it expires
  static Future<void> revokeCode(String code) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final doc = await _firestore.collection('device_codes').doc(code).get();
      if (!doc.exists) throw Exception('Code not found');

      final userId = doc['userId'];
      if (userId != user.uid) throw Exception('Unauthorized');

      await _firestore.collection('device_codes').doc(code).update({
        'isUsed': true,
        'revokedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error revoking code: $e');
      rethrow;
    }
  }
}
