import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  // Railway's generated domain changes whenever the service is renamed or
  // recreated, so keep it in one place: a stale copy here fails as an
  // "Application not found" page from Railway's edge, not an app error.
  static const _prodApiBaseUrl =
      'https://claim-support-backend-python-production-34d1.up.railway.app/api';
  static const _devApiBaseUrl = 'http://10.29.9.1:8000/api';

  static Environment _environment = kReleaseMode ? Environment.prod : Environment.dev;
  static String _apiBaseUrl = kReleaseMode
      ? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _prodApiBaseUrl,
        )
      : const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _devApiBaseUrl,
        );

  static void initialize(Environment env) {
    _environment = env;
    String? envFileUrl;
    try {
      envFileUrl = dotenv.env['API_BASE_URL'];
    } catch (_) {}

    switch (env) {
      case Environment.prod:
        _apiBaseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _prodApiBaseUrl,
        );
        break;
      case Environment.dev:
        _apiBaseUrl = (envFileUrl != null && envFileUrl.isNotEmpty)
            ? envFileUrl
            : const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: _devApiBaseUrl,
              );
        break;
    }
    debugPrint('[EnvConfig] Initialized in $env mode with Base URL: $_apiBaseUrl');
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
