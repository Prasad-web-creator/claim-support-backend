import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claimsupport/core/theme/app_theme.dart';

class AuthStorage {
  static const _secureStorage = FlutterSecureStorage();
  
  // ONE-TIME MIGRATION: Move token from SharedPreferences to Secure Storage
  static Future<void> migrateIfNeeded() async {
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
  }

  static Future<void> saveToken(String token) async => 
      await _secureStorage.write(key: AppConstants.kAuthTokenKey, value: token);
      
  static Future<String?> getToken() async => 
      await _secureStorage.read(key: AppConstants.kAuthTokenKey);
      
  static Future<void> saveRefreshToken(String token) async => 
      await _secureStorage.write(key: AppConstants.kRefreshTokenKey, value: token);
      
  static Future<String?> getRefreshToken() async => 
      await _secureStorage.read(key: AppConstants.kRefreshTokenKey);
      
  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.kAuthTokenKey);
    await _secureStorage.delete(key: AppConstants.kRefreshTokenKey);
  }
}
