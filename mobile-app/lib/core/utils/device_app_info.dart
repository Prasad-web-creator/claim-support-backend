import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

class DeviceAppInfo {
  static String? _cachedVersion;
  static String? _cachedPlatform;

  /// Get current OS platform dynamically
  static String get platform {
    if (_cachedPlatform != null) return _cachedPlatform!;
    if (kIsWeb) {
      _cachedPlatform = 'Web';
    } else if (Platform.isAndroid) {
      _cachedPlatform = 'Android';
    } else if (Platform.isIOS) {
      _cachedPlatform = 'iOS';
    } else if (Platform.isWindows) {
      _cachedPlatform = 'Windows';
    } else if (Platform.isMacOS) {
      _cachedPlatform = 'macOS';
    } else if (Platform.isLinux) {
      _cachedPlatform = 'Linux';
    } else {
      _cachedPlatform = 'Unknown';
    }
    return _cachedPlatform!;
  }

  /// Get App Version from pubspec.yaml dynamically
  static Future<String> getAppVersion() async {
    if (_cachedVersion != null && _cachedVersion!.isNotEmpty) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version;
    } catch (_) {
      _cachedVersion = '1.0.0';
    }
    return _cachedVersion ?? '1.0.0';
  }

  /// Helper to build agreement subdocument dynamically
  static Future<Map<String, dynamic>> buildAgreementData({
    bool termsAccepted = true,
    String termsVersion = '1.0',
  }) async {
    final version = await getAppVersion();
    return {
      'termsAccepted': termsAccepted,
      'termsVersion': termsVersion,
      'appVersion': version,
      'platform': platform,
      'accepted': true,
      'acceptedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
