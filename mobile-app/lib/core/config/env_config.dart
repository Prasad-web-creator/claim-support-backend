import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  static Environment _environment = kReleaseMode ? Environment.prod : Environment.dev;
  static String _apiBaseUrl = kReleaseMode
      ? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://claim-support-backend-python-production.up.railway.app/api',
        )
      : const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.125.186.1:8000/api',
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
          defaultValue: 'https://claim-support-backend-python-production.up.railway.app/api',
        );
        break;
      case Environment.dev:
        _apiBaseUrl = (envFileUrl != null && envFileUrl.isNotEmpty)
            ? envFileUrl
            : const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.125.186.1:8000/api',
              );
        break;
    }
    debugPrint('[EnvConfig] Initialized in $env mode with Base URL: $_apiBaseUrl');
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
