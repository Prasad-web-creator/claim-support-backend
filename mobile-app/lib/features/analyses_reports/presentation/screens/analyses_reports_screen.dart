import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';

class AnalysesReportsScreen extends ConsumerWidget {
  const AnalysesReportsScreen({super.key});

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
                          final reportNumber = report.reportNumber != null ? 'AN${report.reportNumber!.toString().padLeft(4, '0')}' : 'Unknown';
                          final policyName = report.policyMetadata?['plan_name'] ?? report.policyMetadata?['policy_type'] ?? report.policyMetadata?['insurance_company'] ?? 'Unknown Policy';
                          final patientName = report.prescriptionMetadata?['patient_name'] ?? 'Unknown Patient';
                          final status = report.overallStatus ?? 'Pending';
                          
                          Color statusColor = Colors.grey;
                          if (status.toLowerCase().contains('partially')) {
                            statusColor = Colors.orange;
                          } else if (status.toLowerCase().contains('not')) {
                            statusColor = Colors.red;
                          } else if (status.toLowerCase().contains('covered')) {
                            statusColor = Colors.green;
                          }

                          final dominance = report.dominanceScore != null
                              ? '${report.dominanceScore}%'
                              : 'N/A';

                          final dateStr = report.createdAt != null
                              ? DateFormat('dd-MM-yyyy h:mm a').format(report.createdAt!.toLocal())
                              : 'Unknown Date';
                              
                          final analyzedTime = report.processingTimeMs != null 
                              ? '${(report.processingTimeMs! / 1000).toStringAsFixed(1)}s'
                              : 'N/A';

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
                                  content: Text('Are you sure you want to delete "Report $reportNumber"? This action cannot be undone.'),
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
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/summary/${report.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(reportNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _confirmDelete(context, ref, report.id!, reportNumber),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildTextRow('Policy Name', policyName),
                                    _buildTextRow('Patient Name', patientName),
                                    _buildTextRow('Dominance score', dominance),
                                    _buildTextRow('Analyzed DateTime', dateStr),
                                    _buildTextRow('Analyzed time', analyzedTime),
                                  ],
                                ),
                              ),
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

  Widget _buildTextRow(String? label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: label == null 
        ? Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: color != null ? FontWeight.bold : FontWeight.normal))
        : RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              children: [
                TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value, style: TextStyle(color: color)),
              ],
            ),
          ),
    );
  }
}
