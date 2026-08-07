import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/authentication/presentation/screens/splash_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/onboarding_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/login_screen.dart';
import 'package:claimsupport/features/authentication/presentation/screens/register_screen.dart';
import 'package:claimsupport/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_prescription_screen.dart';
import 'package:claimsupport/features/upload/presentation/screens/upload_policy_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/consent_screen.dart';
import 'package:claimsupport/features/analysis/presentation/screens/analysis_screen.dart';
import 'package:claimsupport/features/summary/presentation/screens/summary_screen.dart';
import 'package:claimsupport/features/analyses_reports/presentation/screens/analyses_reports_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/profile_screen.dart';
import 'package:claimsupport/features/policies/presentation/screens/policy_list_screen.dart';
import 'package:claimsupport/features/prescriptions/presentation/screens/prescription_list_screen.dart';
import 'package:claimsupport/features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart';

import 'package:claimsupport/features/logs/presentation/screens/logs_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/privacy_policy_screen.dart';
import 'package:claimsupport/features/profile/presentation/screens/settings_screen.dart';
import 'package:claimsupport/core/presentation/screens/placeholder_detail_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/logs/presentation/controllers/log_controller.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/splash',
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Dashboard with Bottom Navigation using ShellRoute
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: child,
                bottomNavigationBar: BottomAppBar(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: 'Home',
                        isSelected: _calculateSelectedIndex(state.uri.path) == 0,
                        isDark: isDark,
                        onTap: () => _onItemTapped(0, context, ref),
                      ),
                      _NavBarItem(
                        icon: Icons.description_outlined,
                        activeIcon: Icons.description,
                        label: 'Reports',
                        isSelected: _calculateSelectedIndex(state.uri.path) == 1,
                        isDark: isDark,
                        onTap: () => _onItemTapped(1, context, ref),
                      ),
                      _NavBarItem(
                        icon: Icons.history_outlined,
                        activeIcon: Icons.history,
                        label: 'Logs',
                        isSelected: _calculateSelectedIndex(state.uri.path) == 2,
                        isDark: isDark,
                        onTap: () => _onItemTapped(2, context, ref),
                      ),
                      _NavBarItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profile',
                        isSelected: _calculateSelectedIndex(state.uri.path) == 3,
                        isDark: isDark,
                        onTap: () => _onItemTapped(3, context, ref),
                      ),
                    ],
                  ),
                ),
              ); // Closes Scaffold
            },
          ); // Closes Consumer
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const AnalysesReportsScreen(),
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) => const UploadPrescriptionScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/consent',
            builder: (context, state) => const ConsentScreen(),
          ),
          GoRoute(
            path: '/upload-policy',
            builder: (context, state) => const UploadPolicyScreen(),
          ),
          GoRoute(
            path: '/analysis',
            builder: (context, state) => const AnalysisScreen(),
          ),
          GoRoute(
            path: '/summary',
            builder: (context, state) => const SummaryScreen(),
          ),
          GoRoute(
            path: '/summary/:id',
            builder: (context, state) => SummaryScreen(reportId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/policies',
            builder: (context, state) => const PolicyListScreen(),
          ),
          GoRoute(
            path: '/prescriptions',
            builder: (context, state) => const PrescriptionListScreen(),
          ),

          GoRoute(
            path: '/placeholder/:title',
            builder: (context, state) {
              final title = state.pathParameters['title'] ?? 'Detail';
              return PlaceholderDetailScreen(title: title);
            },
          ),
          GoRoute(
            path: '/activity-logs',
            builder: (context, state) => const LogsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/privacy-policy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: '/view-pdf/:fileId',
            builder: (context, state) {
              final fileId = state.pathParameters['fileId']!;
              final title = state.uri.queryParameters['title'] ?? 'Document';
              return PdfViewerScreen(fileId: fileId, title: title);
            },
          ),
        ],
      ),
      // Other top-level screens
    ],
  );

  static int _calculateSelectedIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/reports')) return 1;
    if (location.startsWith('/activity-logs') || location.startsWith('/logs')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  static void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        ref.invalidate(dashboardStatsProvider);
        context.go('/dashboard');
        break;
      case 1:
        ref.invalidate(analysisReportProvider);
        context.go('/reports');
        break;
      case 2:
        ref.invalidate(logProvider);
        context.go('/activity-logs');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected 
        ? const Color(0xFF2563EB) 
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
