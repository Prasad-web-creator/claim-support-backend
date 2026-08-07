import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';

class AuthStorage {
  static const _secureStorage = FlutterSecureStorage();
  
  // ONE-TIME MIGRATION: Move token from SharedPreferences to Secure Storage
  static Future<void> migrateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(AppConstants.kAuthTokenKey);
      final oldRefresh = prefs.getString(AppConstants.kRefreshTokenKey);
      
      if (oldToken != null) {
        await saveToken(oldToken);
        await prefs.remove(AppConstants.kAuthTokenKey);
      }
      if (oldRefresh != null) {
        await saveRefreshToken(oldRefresh);
        await prefs.remove(AppConstants.kRefreshTokenKey);
      }
    } catch (e) {
      debugPrint('AuthStorage migrateIfNeeded error: $e');
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.kAuthTokenKey, value: token);
    } catch (e) {
      debugPrint('AuthStorage saveToken error: $e');
    }
  }
      
  static Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.kAuthTokenKey);
    } catch (e) {
      debugPrint('AuthStorage getToken error: $e');
      return null;
    }
  }
      
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.kRefreshTokenKey, value: token);
    } catch (e) {
      debugPrint('AuthStorage saveRefreshToken error: $e');
    }
  }
      
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.kRefreshTokenKey);
    } catch (e) {
      debugPrint('AuthStorage getRefreshToken error: $e');
      return null;
    }
  }
      
  static Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: AppConstants.kAuthTokenKey);
      await _secureStorage.delete(key: AppConstants.kRefreshTokenKey);
    } catch (e) {
      debugPrint('AuthStorage clearTokens error: $e');
    }
  }
}
