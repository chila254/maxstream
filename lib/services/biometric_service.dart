import 'package:local_auth/local_auth.dart';

/// Biometric Authentication Service
/// Supports fingerprint and face recognition
class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric is available on device
  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if device supports any form of biometric
  static Future<bool> canUseBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (e) {
      print('Error checking device biometric support: $e');
      return false;
    }
  }

  /// Authenticate using biometric
  /// Shows system biometric dialog (fingerprint, face, or PIN fallback)
  static Future<bool> authenticate({
    required String reason,
    bool stickyAuth = false,
    bool biometricOnly = true,
  }) async {
    try {
      final isAvailable = await canUseBiometric();
      if (!isAvailable) {
        throw Exception('Biometric not available on this device');
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      return isAuthenticated;
    } catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  /// Authenticate with fingerprint
  static Future<bool> authenticateWithFingerprint() async {
    return authenticate(
      reason: 'Authenticate using your fingerprint',
      biometricOnly: true,
    );
  }

  /// Authenticate with face
  static Future<bool> authenticateWithFace() async {
    return authenticate(
      reason: 'Authenticate using your face',
      biometricOnly: true,
    );
  }

  /// Generic biometric authentication (fingerprint or face, whatever is available)
  static Future<bool> authenticateForDeviceCode() async {
    try {
      final biometrics = await getAvailableBiometrics();

      String reason = 'Verify your identity to complete TV login';

      // Customize message based on available biometrics
      if (biometrics.contains(BiometricType.face)) {
        reason = 'Scan your face to complete TV login';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        reason = 'Scan your fingerprint to complete TV login';
      }

      return await authenticate(
        reason: reason,
        biometricOnly: false, // Allow PIN fallback if biometric fails
      );
    } catch (e) {
      print('Device code biometric authentication error: $e');
      return false;
    }
  }

  /// Check if biometric enrollment exists
  static Future<bool> hasBiometricEnrolled() async {
    try {
      final biometrics = await getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      print('Error checking biometric enrollment: $e');
      return false;
    }
  }

  /// Get biometric type string for display
  static Future<String> getBiometricTypeString() async {
    try {
      final biometrics = await getAvailableBiometrics();

      if (biometrics.contains(BiometricType.face)) {
        return 'Face Recognition';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris Scan';
      }

      return 'Biometric';
    } catch (e) {
      print('Error getting biometric type: $e');
      return 'Biometric';
    }
  }
}
