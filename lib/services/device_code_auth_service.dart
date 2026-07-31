import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'secure_password_service.dart';

/// Device Code Authentication Service
/// Provides interim passwordless login via email links
/// Once backend is ready, can be enhanced with custom tokens
class DeviceCodeAuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Exchange device code for email link authentication
  /// Returns email and sends passwordless link (interim solution)
  static Future<Map<String, String>> authenticateWithDeviceCode(
    String code,
  ) async {
    try {
      // Verify code is valid
      final doc = await _firestore.collection('device_codes').doc(code).get();

      if (!doc.exists) {
        throw Exception('Code not found');
      }

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isUsed = data['isUsed'] as bool;
      final email = data['email'] as String;
      final userId = data['userId'] as String;

      // Validate code
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Code expired');
      }

      if (isUsed) {
        throw Exception('Code already used');
      }

      // Mark as used
      await _firestore.collection('device_codes').doc(code).update({
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // Create authenticated session document
      await _createAuthenticatedSession(code, userId, email);

      return {
        'email': email,
        'userId': userId,
        'displayName': data['displayName'] as String? ?? '',
      };
    } catch (e) {
      print('Device code authentication error: $e');
      rethrow;
    }
  }

  /// Create authenticated session for device code
  static Future<void> _createAuthenticatedSession(
    String code,
    String userId,
    String email,
  ) async {
    try {
      // Store session that validates this device/code combo
      // Can be used to skip password on next attempt
      await _firestore.collection('tv_authenticated_sessions').add({
        'code': code,
        'userId': userId,
        'email': email,
        'deviceId': _auth.currentUser?.uid,
        'authenticatedAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(hours: 24)),
      });
    } catch (e) {
      print('Error creating authenticated session: $e');
      // Don't rethrow - this is non-critical
    }
  }

  /// Check if this device has recent authentication with this email
  static Future<bool> hasRecentAuthentication(String email) async {
    try {
      final snapshot = await _firestore
          .collection('tv_authenticated_sessions')
          .where('email', isEqualTo: email)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking recent authentication: $e');
      return false;
    }
  }

  /// Clean up expired sessions
  static Future<void> cleanupExpiredSessions() async {
    try {
      final snapshot = await _firestore
          .collection('tv_authenticated_sessions')
          .where('expiresAt', isLessThan: DateTime.now())
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} expired sessions');
    } catch (e) {
      print('Error cleaning up sessions: $e');
    }
  }

  /// Revoke device code session early
  static Future<void> revokeSession(String sessionId) async {
    try {
      await _firestore
          .collection('tv_authenticated_sessions')
          .doc(sessionId)
          .delete();
    } catch (e) {
      print('Error revoking session: $e');
      rethrow;
    }
  }

  /// Authenticate with device code + biometric (hybrid flow)
  /// Returns User if successful, null if biometric fails
  static Future<User?> authenticateWithCodeAndBiometric(
    String code,
    String password,
  ) async {
    try {
      // Step 1: Validate device code
      final userInfo = await authenticateWithDeviceCode(code);
      final email = userInfo['email'];

      // Step 2: Check if biometric is available
      final isBioAvailable = await BiometricService.canUseBiometric();

      if (!isBioAvailable) {
        throw Exception('Biometric not available on this device');
      }

      // Step 3: Prompt for biometric authentication
      final isBioAuthenticated =
          await BiometricService.authenticateForDeviceCode();

      if (!isBioAuthenticated) {
        throw Exception('Biometric authentication failed');
      }

      // Step 4: Auto-sign in with email and password
      // Password must be provided - this is a limitation of this approach
      // as we don't have the user's password from the code
      final user = await AuthService.signInWithEmail(email ?? '', password);

      if (user != null) {
        // Record biometric-assisted login
        await _recordBiometricLogin(userInfo['userId'] ?? '', email ?? '');
      }

      return user;
    } catch (e) {
      print('Code + biometric authentication error: $e');
      rethrow;
    }
  }

  /// Authenticate code + biometric + stored password (passwordless auto-login)
  /// Uses locally stored encrypted password after biometric verification
  static Future<User?> authenticateWithCodeAndBiometricStoredPassword(
    String code,
  ) async {
    try {
      // Step 1: Validate device code
      final userInfo = await authenticateWithDeviceCode(code);
      final userId = userInfo['userId'];
      final email = userInfo['email'];

      if (email == null || email.isEmpty) {
        throw Exception('No email in device code');
      }

      // Step 2: Check if biometric is available
      final isBioAvailable = await BiometricService.canUseBiometric();

      if (!isBioAvailable) {
        throw Exception('Biometric not available on this device');
      }

      // Step 3: Prompt for biometric authentication
      final isBioAuthenticated =
          await BiometricService.authenticateForDeviceCode();

      if (!isBioAuthenticated) {
        throw Exception('Biometric authentication failed');
      }

      // Step 4: Retrieve saved password
      final savedPassword = await SecurePasswordService.getPassword(email);

      if (savedPassword == null || savedPassword.isEmpty) {
        throw Exception(
          'No saved password found. Please sign in with password first.',
        );
      }

      // Step 5: Auto-sign in with email and saved password
      final user = await AuthService.signInWithEmail(email, savedPassword);

      if (user != null) {
        // Create authenticated session
        await _createBiometricSession(userId ?? '', email);

        // Record successful passwordless biometric login
        await _recordBiometricLogin(userId ?? '', email);

        print('Auto-logged in with biometric for: $email');
      }

      return user;
    } catch (e) {
      print('Code + passwordless biometric authentication error: $e');
      rethrow;
    }
  }

  /// Create biometric authenticated session
  static Future<void> _createBiometricSession(
    String userId,
    String email,
  ) async {
    try {
      await _firestore.collection('biometric_sessions').add({
        'userId': userId,
        'email': email,
        'authenticatedAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(hours: 1)),
        'authMethod': 'biometric',
      });
    } catch (e) {
      print('Error creating biometric session: $e');
      // Don't rethrow - non-critical
    }
  }

  /// Record biometric login for analytics/security
  static Future<void> _recordBiometricLogin(String userId, String email) async {
    try {
      await _firestore.collection('login_audits').add({
        'userId': userId,
        'email': email,
        'method': 'device_code_biometric',
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': '', // Could be populated from backend
        'deviceInfo': '', // Could be populated with device info
      });
    } catch (e) {
      print('Error recording biometric login: $e');
      // Don't rethrow - audit is non-critical
    }
  }
}
