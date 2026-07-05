import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _refreshTokenKey = 'refresh_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Token Management
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      print('Error saving token: $e');
      rethrow;
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  static Future<bool> hasToken() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Error checking token: $e');
      return false;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      print('Error deleting token: $e');
      rethrow;
    }
  }

  // User Data Management
  static Future<void> saveUserData(String userJson) async {
    try {
      await _storage.write(key: _userKey, value: userJson);
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  static Future<String?> getUserData() async {
    try {
      return await _storage.read(key: _userKey);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  static Future<void> deleteUserData() async {
    try {
      await _storage.delete(key: _userKey);
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }

  // Refresh Token Management
  static Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (e) {
      print('Error saving refresh token: $e');
      rethrow;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      print('Error getting refresh token: $e');
      return null;
    }
  }

  static Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (e) {
      print('Error deleting refresh token: $e');
      rethrow;
    }
  }

  // Clear all stored data
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error clearing all secure storage: $e');
      rethrow;
    }
  }

  // Check if any auth data exists
  static Future<bool> hasAuthData() async {
    try {
      final token = await getToken();
      final userData = await getUserData();
      return (token != null && token.isNotEmpty) ||
          (userData != null && userData.isNotEmpty);
    } catch (e) {
      print('Error checking auth data: $e');
      return false;
    }
  }
}
