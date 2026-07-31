import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Password Storage Service
/// Stores and retrieves user passwords encrypted on device
class SecurePasswordService {
  static const String _passwordKeyPrefix = 'tv_login_password_';
  static const String _emailKeyPrefix = 'tv_login_email_';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Save password securely for a user email
  /// Used after successful biometric + password login
  static Future<bool> savePassword(String email, String password) async {
    try {
      final emailKey = _emailKeyPrefix + email;
      final passwordKey = _passwordKeyPrefix + email;

      // Store both email and password
      await Future.wait([
        _storage.write(key: emailKey, value: email),
        _storage.write(key: passwordKey, value: password),
      ]);

      print('Password saved securely for: $email');
      return true;
    } catch (e) {
      print('Error saving password: $e');
      return false;
    }
  }

  /// Retrieve saved password for email
  static Future<String?> getPassword(String email) async {
    try {
      final passwordKey = _passwordKeyPrefix + email;
      final password = await _storage.read(key: passwordKey);

      if (password != null) {
        print('Retrieved saved password for: $email');
      }

      return password;
    } catch (e) {
      print('Error retrieving password: $e');
      return null;
    }
  }

  /// Check if password is saved for email
  static Future<bool> hasPasswordSaved(String email) async {
    try {
      final password = await getPassword(email);
      return password != null && password.isNotEmpty;
    } catch (e) {
      print('Error checking saved password: $e');
      return false;
    }
  }

  /// Delete saved password for email
  static Future<bool> deletePassword(String email) async {
    try {
      final emailKey = _emailKeyPrefix + email;
      final passwordKey = _passwordKeyPrefix + email;

      await Future.wait([
        _storage.delete(key: emailKey),
        _storage.delete(key: passwordKey),
      ]);

      print('Password deleted for: $email');
      return true;
    } catch (e) {
      print('Error deleting password: $e');
      return false;
    }
  }

  /// Get all saved emails with stored passwords
  static Future<List<String>> getSavedEmails() async {
    try {
      final allEntries = await _storage.readAll();
      final savedEmails = <String>[];

      for (var key in allEntries.keys) {
        if (key.startsWith(_emailKeyPrefix)) {
          final email = allEntries[key];
          if (email != null && email.isNotEmpty) {
            savedEmails.add(email);
          }
        }
      }

      return savedEmails;
    } catch (e) {
      print('Error getting saved emails: $e');
      return [];
    }
  }

  /// Clear all saved passwords
  static Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      print('All saved passwords cleared');
      return true;
    } catch (e) {
      print('Error clearing passwords: $e');
      return false;
    }
  }
}
