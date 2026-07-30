import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(analysisReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyses Reports'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: reportState.when(
                  data: (pagination) {
                    final reports = pagination.docs;
                    if (reports.isEmpty) {
                      return const Center(
                        child: Text('No analysis reports found.'),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true);
                      },
                      child: ListView.builder(
                        itemCount: reports.length + (pagination.hasNextPage ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == reports.length) {
                            Future.microtask(() => ref.read(analysisReportProvider.notifier).loadNextPage());
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          
                          final report = reports[index];
                          final dateStr = report.createdAt != null 
                              ? DateFormat.yMMMd().format(report.createdAt!) 
                              : 'Unknown Date';
                          
                          // Format confidence
                          final confidence = report.confidenceScore != null 
                              ? '${report.confidenceScore}% Confidence' 
                              : '';
                          
                          // Combine status and confidence for subtitle
                          final subtitleText = '${report.overallStatus ?? "Pending"}${confidence.isNotEmpty ? ' - $confidence' : ''}\n$dateStr';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: const Icon(Icons.analytics, color: AppTheme.primaryColor),
                              ),
                              title: Text(report.reportNumber != null ? 'Analyze Report ${report.reportNumber}' : report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(subtitleText),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                context.push('/summary/${report.id}');
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
