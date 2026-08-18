import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'secure_password_service.dart';

/// Device Code Authentication Service
/// Provides interim passwordless login via email links
/// Once backend is ready, can be enhanced with custom tokens
class DeviceCodeAuthService {
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Exchange device code for email link authentication
  /// Returns email and sends passwordless link (interim solution)
  static Future<Map<String, String>> authenticateWithDeviceCode(
    String code,
  ) async {
    try {
      // Verify code is valid
      final snapshot = await _rtdb.ref('device_codes/$code').get();

      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Code not found');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final expiresAt = data['expiresAt'] as int;
      final isUsed = data['isUsed'] as bool;
      final email = data['email'] as String;
      final userId = data['userId'] as String;
      final password = data['password'] as String?;

      // Validate code
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        throw Exception('Code expired');
      }

      if (isUsed) {
        throw Exception('Code already used');
      }

      // Mark as used
      await _rtdb.ref('device_codes/$code').update({
        'isUsed': true,
        'usedAt': ServerValue.timestamp,
      });

      // Create authenticated session document
      await _createAuthenticatedSession(code, userId, email);

      return {
        'email': email,
        'userId': userId,
        'password': password ?? '',
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
      final sessionRef = _rtdb.ref('tv_authenticated_sessions').push();
      await sessionRef.set({
        'code': code,
        'userId': userId,
        'email': email,
        'deviceId': _auth.currentUser?.uid,
        'authenticatedAt': ServerValue.timestamp,
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error creating authenticated session: $e');
      // Don't rethrow - this is non-critical
    }
  }

  /// Check if this device has recent authentication with this email
  static Future<bool> hasRecentAuthentication(String email) async {
    try {
      final snapshot = await _rtdb
          .ref('tv_authenticated_sessions')
          .orderByChild('email')
          .equalTo(email)
          .get();

      if (!snapshot.exists || snapshot.value == null) return false;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      return data.values.any((entry) {
        final session = Map<String, dynamic>.from(entry as Map);
        final expiresAt = session['expiresAt'] as int? ?? 0;
        return expiresAt > now;
      });
    } catch (e) {
      print('Error checking recent authentication: $e');
      return false;
    }
  }

  /// Clean up expired sessions
  static Future<void> cleanupExpiredSessions() async {
    try {
      final snapshot = await _rtdb
          .ref('tv_authenticated_sessions')
          .orderByChild('expiresAt')
          .endBefore(DateTime.now().millisecondsSinceEpoch)
          .get();

      if (!snapshot.exists || snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final updates = <String, dynamic>{};
      for (final key in data.keys) {
        updates[key] = null;
      }
      await _rtdb.ref('tv_authenticated_sessions').update(updates);
      print('Cleaned up ${data.length} expired sessions');
    } catch (e) {
      print('Error cleaning up sessions: $e');
    }
  }

  /// Revoke device code session early
  static Future<void> revokeSession(String sessionId) async {
    try {
      await _rtdb.ref('tv_authenticated_sessions/$sessionId').remove();
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
      final sessionRef = _rtdb.ref('biometric_sessions').push();
      await sessionRef.set({
        'userId': userId,
        'email': email,
        'authenticatedAt': ServerValue.timestamp,
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
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
      final auditRef = _rtdb.ref('login_audits').push();
      await auditRef.set({
        'userId': userId,
        'email': email,
        'method': 'device_code_biometric',
        'timestamp': ServerValue.timestamp,
        'ipAddress': '',
        'deviceInfo': '',
      });
    } catch (e) {
      print('Error recording biometric login: $e');
      // Don't rethrow - audit is non-critical
    }
  }
}
