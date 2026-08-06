import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';

class AnalysesReportsScreen extends ConsumerStatefulWidget {
  const AnalysesReportsScreen({super.key});

  @override
  ConsumerState<AnalysesReportsScreen> createState() => _AnalysesReportsScreenState();
}

class _AnalysesReportsScreenState extends ConsumerState<AnalysesReportsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedReportIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedReportIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedReportIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedReportIds.contains(id)) {
        _selectedReportIds.remove(id);
        if (_selectedReportIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedReportIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<AnalysisReport> currentReports) {
    setState(() {
      final allIds = currentReports.map((r) => r.id).toSet();
      if (_selectedReportIds.containsAll(allIds)) {
        _selectedReportIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedReportIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedReportIds.isEmpty) return;
    final count = _selectedReportIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Selected Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete $count selected analysis report(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final idsToDelete = _selectedReportIds.toList();
        await ref.read(analysisReportProvider.notifier).deleteReports(idsToDelete);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count reports deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete reports: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteSingle(String id, String label) async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(analysisReportProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentReports = reportState.value?.docs ?? [];
    final validReportIds = currentReports.map((r) => r.id).toSet();
    final allSelected = validReportIds.isNotEmpty && _selectedReportIds.containsAll(validReportIds);

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedReportIds.length} Selected' : 'Coverage Analysis Reports',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(currentReports),
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _selectedReportIds.isNotEmpty ? Colors.redAccent : Colors.grey,
              ),
              tooltip: 'Delete Selected',
              onPressed: _selectedReportIds.isNotEmpty ? _confirmBatchDelete : null,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Select Multiple',
              onPressed: () => _enterSelectionMode(),
            ),
          ],
        ],
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
                          final reportId = report.id;
                          final isSelected = _selectedReportIds.contains(reportId);
                          final reportNumber = report.reportNumber != null ? 'CR-${report.reportNumber!.toString().padLeft(4, '0')}' : 'Unknown';
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

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A8A).withAlpha(40) : const Color(0xFFEFF6FF))
                                : (isDark ? const Color(0xFF1E2230) : Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onLongPress: () {
                                _enterSelectionMode(reportId);
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(reportId);
                                } else {
                                  context.push('/summary/${report.id}');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isSelectionMode) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(right: 12, top: 2),
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFF2563EB),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (_) {
                                            _toggleSelection(reportId);
                                          },
                                        ),
                                      ),
                                    ],
                                    Expanded(
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
                                                  color: statusColor.withAlpha(25),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: statusColor.withAlpha(128)),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              if (!_isSelectionMode) ...[
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _confirmDeleteSingle(reportId, reportNumber),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          _buildTextRow('Policy Name', policyName, isDark: isDark),
                                          _buildTextRow('Patient Name', patientName, isDark: isDark),
                                          _buildTextRow('Dominance score', dominance, isDark: isDark),
                                          _buildTextRow('Analyzed DateTime', dateStr, isDark: isDark),
                                          _buildTextRow('Analyzed time', analyzedTime, isDark: isDark),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _buildTextRow(String? label, String value, {Color? color, bool isDark = false}) {
    final defaultColor = isDark ? Colors.grey.shade300 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: label == null 
        ? Text(value, style: TextStyle(color: color ?? defaultColor, fontSize: 14, fontWeight: color != null ? FontWeight.bold : FontWeight.normal))
        : RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: defaultColor),
              children: [
                TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value, style: TextStyle(color: color ?? defaultColor)),
              ],
            ),
          ),
    );
  }
}
