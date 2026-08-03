import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Report', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$label"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(analysisReportProvider.notifier).deleteReport(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

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
                          final label = report.reportNumber != null
                              ? 'Analyze Report ${report.reportNumber}'
                              : report.title;
                          final dateStr = report.createdAt != null
                              ? DateFormat.yMMMd().format(report.createdAt!)
                              : 'Unknown Date';

                          final dominance = report.dominanceScore != null
                              ? '${report.dominanceScore}% Dominance Score'
                              : '';
                          final subtitleText = '${report.overallStatus ?? "Pending"}${dominance.isNotEmpty ? ' - $dominance' : ''}\n$dateStr';

                          return Dismissible(
                            key: ValueKey(report.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.white, size: 26),
                                  SizedBox(height: 4),
                                  Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Delete Report', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: Text('Are you sure you want to delete "$label"? This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await ref.read(analysisReportProvider.notifier).deleteReport(report.id!);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Report deleted successfully.'), backgroundColor: Colors.green),
                                    );
                                  }
                                  return true;
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                  return false;
                                }
                              }
                              return false;
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: const Icon(Icons.analytics, color: AppTheme.primaryColor),
                                ),
                                title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(subtitleText),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _confirmDelete(context, ref, report.id!, label),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  context.push('/summary/${report.id}');
                                },
                              ),
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
