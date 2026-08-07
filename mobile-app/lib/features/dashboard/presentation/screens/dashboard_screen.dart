import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';
import 'package:claimsupport/features/dashboard/presentation/widgets/sliding_banner.dart';
import 'package:claimsupport/features/dashboard/presentation/widgets/floating_live_ad.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(dashboardStatsProvider.notifier).fetchStats();
              },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 100.0),
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer(
                  builder: (context, ref, child) {
                    final authState = ref.watch(authProvider);
                    return authState.when(
                      data: (user) => Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      loading: () => const Text('Loading...', style: TextStyle(fontSize: 28)),
                      error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 16, color: Colors.red)),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Main Blue Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withAlpha(60),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: 10,
                        child: Icon(
                          Icons.shield_outlined,
                          size: 140,
                          color: Colors.white.withAlpha(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Check Claim Eligibility',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Upload your policy and\nprescription to see what's covered\nbefore filing a claim.",
                              style: TextStyle(
                                color: Colors.white.withAlpha(220),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withAlpha(50),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => context.push('/consent'),
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'Start New Analysis',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sliding Offer & Promotion Banner
                const SlidingBanner(),

                const SizedBox(height: 28),

                // Quick Stats Header
                Text(
                  'Overview',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Dashboard Stats
                Consumer(
                  builder: (context, ref, child) {
                    final dashboardState = ref.watch(dashboardStatsProvider);
                    return dashboardState.when(
                      data: (stats) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    icon: Icons.description_outlined,
                                    iconColor: const Color(0xFF2563EB),
                                    iconBgColor: const Color(0xFFEFF6FF),
                                    count: stats.totalPolicies.toString(),
                                    label: 'POLICIES',
                                    onTap: () async {
                                      ref.invalidate(policiesProvider);
                                      await context.push('/policies');
                                      ref.invalidate(dashboardStatsProvider);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    icon: Icons.medication_outlined,
                                    iconColor: const Color(0xFF9333EA),
                                    iconBgColor: const Color(0xFFF3E8FF),
                                    count: stats.totalPrescriptions.toString(),
                                    label: 'PRESCRIPTIONS',
                                    onTap: () async {
                                      ref.invalidate(prescriptionProvider);
                                      await context.push('/prescriptions');
                                      ref.invalidate(dashboardStatsProvider);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Analyses',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/reports'),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (stats.recentAnalyses.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No recent analyses',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...stats.recentAnalyses.map((report) => _buildRecentAnalysisCard(context, ref, report)),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
          ),
        ),
      ),

          // Draggable Flipkart-style Floating Live Ad Widget
          const FloatingLiveAd(),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? iconBgColor.withAlpha(50) : iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRecentAnalysisCard(BuildContext context, WidgetRef ref, AnalysisReport report) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color statusColor;
    Color statusBgColor;

    final statusLower = (report.overallStatus ?? '').toLowerCase();
    if (statusLower == 'covered' || statusLower == 'approved' || statusLower == 'likely covered') {
      statusColor = const Color(0xFF059669);
      statusBgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
    } else if (statusLower == 'partially covered' || statusLower == 'partially approved') {
      statusColor = const Color(0xFFD97706);
      statusBgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    } else if (statusLower == 'not covered' || statusLower == 'rejected' || statusLower == 'likely not covered') {
      statusColor = const Color(0xFFDC2626);
      statusBgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    } else if (statusLower.startsWith('invalid')) {
      statusColor = const Color(0xFFD97706);
      statusBgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    } else {
      statusColor = isDark ? Colors.grey.shade300 : const Color(0xFF6B7280);
      statusBgColor = isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6);
    }

    return InkWell(
      onTap: () async {
        await context.push('/summary/${report.id}');
        ref.invalidate(dashboardStatsProvider);
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: theme.cardTheme.color ?? theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description_outlined, color: isDark ? Colors.grey.shade300 : const Color(0xFF6B7280)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.displayReportNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (report.createdAt != null)
                      Text(
                        DateFormat('dd-MM-yyyy  hh:mm a').format(report.createdAt!.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.overallStatus ?? 'Pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
