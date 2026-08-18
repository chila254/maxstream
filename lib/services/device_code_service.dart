import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';
import 'secure_password_service.dart';

class DeviceCodeService {
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate a 6-digit code and save to Realtime Database
  static Future<String> generateDeviceCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('Starting device code generation for user: ${user.uid}');

      // Generate random 6-digit code
      final code = (100000 + Random().nextInt(900000)).toString();
      print('Generated code: $code');

      // Save to RTDB with 15-minute expiry (epoch millis)
      final expiresAt = DateTime.now()
          .add(const Duration(minutes: 15))
          .millisecondsSinceEpoch;

      print('Writing to RTDB path: device_codes/$code');

      // Carry the user's password so the TV can sign in directly with the
      // code (interim solution until a custom-token backend exists).
      final savedPassword = await SecurePasswordService.getPassword(
        user.email ?? '',
      );

      if (savedPassword == null || savedPassword.isEmpty) {
        throw Exception(
          'NO_PASSWORD: Your password is not saved on this device. '
          'Please sign out and sign in again with your email and password '
          '(not Google sign-in) to enable TV pairing.',
        );
      }

      // Use exponential backoff retry logic
      int retryCount = 0;
      const maxRetries = 3;
      const baseDelay = Duration(milliseconds: 500);

      while (retryCount < maxRetries) {
        try {
          await _rtdb
              .ref('device_codes/$code')
              .set({
                'code': code,
                'userId': user.uid,
                'email': user.email,
                'displayName': user.displayName,
                'password': savedPassword,
                'createdAt': ServerValue.timestamp,
                'expiresAt': expiresAt,
                'isUsed': false,
              })
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw TimeoutException(
                    'RTDB write operation timed out after 30 seconds',
                  );
                },
              );

          print('Successfully saved device code: $code');
          return code;
        } on TimeoutException {
          retryCount++;
          if (retryCount < maxRetries) {
            final delay = baseDelay * (1 << (retryCount - 1));
            print(
              'Timeout on attempt $retryCount, retrying in ${delay.inMilliseconds}ms...',
            );
            await Future.delayed(delay);
          } else {
            print('Max retries reached. Failed to save device code.');
            throw TimeoutException(
              'Failed to generate pairing code after $maxRetries attempts. Please check your internet connection and try again.',
            );
          }
        }
      }

      throw Exception('Failed to generate device code');
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      throw Exception(e.toString());
    } catch (e) {
      print('Error generating device code: $e');
      rethrow;
    }
  }

  /// Validate code and return user email
  static Future<Map<String, String>> validateDeviceCode(String code) async {
    try {
      final snapshot = await _rtdb.ref('device_codes/$code').get();

      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Invalid code');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final expiresAt = data['expiresAt'] as int;
      final isUsed = data['isUsed'] as bool;

      // Check if expired
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        throw Exception('Code expired');
      }

      // Check if already used
      if (isUsed) {
        throw Exception('Code already used');
      }

      // Mark as used
      await _rtdb.ref('device_codes/$code').update({
        'isUsed': true,
        'usedAt': ServerValue.timestamp,
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

      // Query device_codes where userId matches and isUsed is false
      final snapshot = await _rtdb
          .ref('device_codes')
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final codes = <Map<String, dynamic>>[];
      final entries = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in entries.values) {
        final data = Map<String, dynamic>.from(entry as Map);
        if (data['isUsed'] == false) {
          codes.add({'code': data['code'], 'expiresAt': data['expiresAt']});
        }
      }
      return codes;
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

      final snapshot = await _rtdb.ref('device_codes/$code').get();
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Code not found');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final userId = data['userId'];
      if (userId != user.uid) throw Exception('Unauthorized');

      await _rtdb.ref('device_codes/$code').update({
        'isUsed': true,
        'revokedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error revoking code: $e');
      rethrow;
    }
  }
}
