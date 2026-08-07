import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/core/routing/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart';
import 'package:claimsupport/core/config/env_config.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Prevent release mode black screen on unhandled Flutter widget build errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'An unexpected error occurred',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    if (!kReleaseMode) {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('No .env file found. Using default dev config.');
      }
    }

    EnvConfig.initialize(kReleaseMode ? Environment.prod : Environment.dev);
  } catch (e) {
    debugPrint('EnvConfig init error: $e');
  }

  try {
    await SharedPrefs.init();
  } catch (e) {
    debugPrint('SharedPrefs init error: $e');
  }

  try {
    await AuthStorage.migrateIfNeeded();
  } catch (e) {
    debugPrint('AuthStorage migration error: $e');
  }

  runApp(
    const ProviderScope(
      child: ClaimSupportApp(),
    ),
  );
}

class ClaimSupportApp extends ConsumerWidget {
  const ClaimSupportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Claim Support',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
