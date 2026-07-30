enum Environment {
  dev,
  prod,
}

class EnvConfig {
  static late Environment _environment;
  static late String _apiBaseUrl;

  static void initialize(Environment env) {
    _environment = env;
    switch (env) {
      case Environment.prod:
        // In production, force HTTPS and use the production domain.
        // We inject this securely via --dart-define during the build.
        _apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://claim-support-backend-production.up.railway.app/api');
        break;
      case Environment.dev:
      default:
        // In dev, we can use HTTP and local IPs.
        _apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.71.14.1:3000/api');
        break;
    }
  }

  static String get apiBaseUrl => _apiBaseUrl;
  static bool get isProd => _environment == Environment.prod;
}
