import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  dev,
  prod,
}

class EnvConfig {
  static late Environment _environment;
  static late String _apiBaseUrl;

  static void initialize(Environment env) {
    _environment = env;
    final envFileUrl = dotenv.env['API_BASE_URL'];

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
                defaultValue: 'http://10.71.14.1:8000/api',
              );
        break;
    }
    debugPrint('[EnvConfig] Initialized in $env mode with Base URL: $_apiBaseUrl');
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
