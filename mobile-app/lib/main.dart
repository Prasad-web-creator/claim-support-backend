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
  
  // Load local .env only in development mode if necessary, 
  // but EnvConfig will handle base URL natively for Prod.
  if (!kReleaseMode) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('No .env file found. Using default dev config.');
    }
  }

  // Initialize the correct environment
  EnvConfig.initialize(kReleaseMode ? Environment.prod : Environment.dev);

  await SharedPrefs.init();
  await AuthStorage.migrateIfNeeded();
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
