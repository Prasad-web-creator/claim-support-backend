import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';

/// Coverage Analysis Reports.
///
/// One card per analysis. When several policies were analysed against the same
/// prescription they appear inside a single card — one row per policy, each
/// keeping its own status, coverage result and report.
class AnalysesReportsScreen extends ConsumerStatefulWidget {
  const AnalysesReportsScreen({super.key});

  @override
  ConsumerState<AnalysesReportsScreen> createState() => _AnalysesReportsScreenState();
}

class _AnalysesReportsScreenState extends ConsumerState<AnalysesReportsScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);

  bool _isSelectionMode = false;
  final Set<String> _selectedGroupIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedGroupIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedGroupIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedGroupIds.contains(id)) {
        _selectedGroupIds.remove(id);
        if (_selectedGroupIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedGroupIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<AnalysisReportGroup> currentGroups) {
    setState(() {
      final allIds = currentGroups.map((g) => g.groupId).toSet();
      if (_selectedGroupIds.containsAll(allIds)) {
        _selectedGroupIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedGroupIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedGroupIds.isEmpty) return;
    final count = _selectedGroupIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Selected Analyses', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete $count selected analysis/analyses? '
          'All policy reports inside them will be removed. This action cannot be undone.',
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
        final idsToDelete = _selectedGroupIds.toList();
        await ref.read(analysisReportProvider.notifier).deleteReports(idsToDelete);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count analyses deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete analyses: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteSingle(AnalysisReportGroup group) async {
    final label = group.title;
    final extra = group.isMultiPolicy
        ? ' All ${group.policyCount} policy reports in this analysis will be removed.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$label"?$extra This action cannot be undone.'),
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
        await ref.read(analysisReportProvider.notifier).deleteReport(group.groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis deleted successfully.'), backgroundColor: Colors.green),
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

  Color _statusColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('fail') || lower.contains('invalid')) return Colors.redAccent;
    if (lower.contains('needs your input') || lower.contains('partial') ||
        lower.contains('manual review')) {
      return Colors.orange;
    }
    if (lower.contains('not covered') || lower.contains('rejected')) return Colors.red;
    if (lower.contains('analyzing')) return Colors.blueGrey;
    if (lower.contains('covered') || lower.contains('completed')) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(analysisReportProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentGroups = reportState.value?.docs ?? [];
    final validIds = currentGroups.map((g) => g.groupId).toSet();
    final allSelected = validIds.isNotEmpty && _selectedGroupIds.containsAll(validIds);

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
          _isSelectionMode ? '${_selectedGroupIds.length} Selected' : 'Coverage Analysis Reports',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(currentGroups),
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
                color: _selectedGroupIds.isNotEmpty ? Colors.redAccent : Colors.grey,
              ),
              tooltip: 'Delete Selected',
              onPressed: _selectedGroupIds.isNotEmpty ? _confirmBatchDelete : null,
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
          child: reportState.when(
            data: (pagination) {
              final groups = pagination.docs;
              if (groups.isEmpty) {
                return const Center(child: Text('No analysis reports found.'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(analysisReportProvider.notifier).fetchAnalysisReports(isRefresh: true);
                },
                child: ListView.builder(
                  itemCount: groups.length + (pagination.hasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == groups.length) {
                      Future.microtask(
                          () => ref.read(analysisReportProvider.notifier).loadNextPage());
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _buildGroupCard(groups[index], isDark);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(AnalysisReportGroup group, bool isDark) {
    final isSelected = _selectedGroupIds.contains(group.groupId);
    final statusLabel = group.statusLabel;
    final statusColor = _statusColor(statusLabel);

    final dateStr = group.createdAt != null
        ? DateFormat('dd-MM-yyyy h:mm a').format(group.createdAt!.toLocal())
        : null;

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
              ? _primaryBlue
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _enterSelectionMode(group.groupId),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(group.groupId);
            return;
          }
          // A single-policy analysis opens its report directly; a multi-policy
          // analysis is expanded in place, one row per policy.
          if (!group.isMultiPolicy && group.policyReports.isNotEmpty) {
            final reportId = group.policyReports.first.reportId;
            if (reportId.isNotEmpty) context.push('/summary/$reportId');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: _primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleSelection(group.groupId),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Group header ────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            group.isMultiPolicy
                                ? group.title
                                : (group.policyReports.isNotEmpty &&
                                        group.policyReports.first.reportLabel.isNotEmpty
                                    ? group.policyReports.first.reportLabel
                                    : group.title),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildChip(statusLabel, statusColor),
                        if (!_isSelectionMode) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteSingle(group),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (group.isMultiPolicy) ...[
                      if (group.patientName.isNotEmpty)
                        _buildTextRow('Patient Name', group.patientName, isDark: isDark),
                      if (group.visitDate.isNotEmpty)
                        _buildTextRow('Prescription Date', group.visitDate, isDark: isDark),
                      _buildTextRow('Policies Analyzed', '${group.policyCount}', isDark: isDark),
                      if (dateStr != null)
                        _buildTextRow('Analyzed DateTime', dateStr, isDark: isDark),
                      if (group.displayProcessingTime.isNotEmpty)
                        _buildTextRow('Analyzed time', group.displayProcessingTime, isDark: isDark),

                      const SizedBox(height: 6),
                      Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      const SizedBox(height: 2),

                      // ── One row per policy, each independent ──────────────
                      ...group.policyReports.map((p) => _buildPolicyRow(p, isDark)),
                    ] else ...[
                      // Single-policy analysis keeps its original layout
                      if (group.policyReports.isNotEmpty) ...[
                        if (group.policyReports.first.displayName.isNotEmpty &&
                            group.policyReports.first.displayName != 'Policy')
                          _buildTextRow('Policy Name', group.policyReports.first.displayName,
                              isDark: isDark),
                        if (group.patientName.isNotEmpty)
                          _buildTextRow('Patient Name', group.patientName, isDark: isDark),
                        _buildTextRow('Dominance score',
                            '${group.policyReports.first.dominanceScore}%', isDark: isDark),
                      ],
                      if (dateStr != null)
                        _buildTextRow('Analyzed DateTime', dateStr, isDark: isDark),
                      if (group.displayProcessingTime.isNotEmpty)
                        _buildTextRow('Analyzed time', group.displayProcessingTime, isDark: isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One policy inside a grouped analysis — its own status, coverage and report.
  Widget _buildPolicyRow(PolicyReportRow policy, bool isDark) {
    final statusColor = _statusColor(policy.statusLabel);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151A26) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      if (policy.policyNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Policy No: ${policy.policyNumber}',
                            style: TextStyle(fontSize: 11, color: subColor)),
                      ] else if (policy.insuranceCompany.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(policy.insuranceCompany,
                            style: TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildChip(policy.statusLabel, statusColor, small: true),
              ],
            ),

            if (policy.isFailed && policy.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                policy.errorMessage,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 6),
            Row(
              children: [
                if (policy.reportLabel.isNotEmpty)
                  Text(policy.reportLabel, style: TextStyle(fontSize: 11, color: subColor)),
                if (policy.reportLabel.isNotEmpty && policy.dominanceScore > 0)
                  Text('  ·  ', style: TextStyle(fontSize: 11, color: subColor)),
                if (policy.dominanceScore > 0)
                  Text('Dominance ${policy.dominanceScore}%',
                      style: TextStyle(fontSize: 11, color: subColor)),
                const Spacer(),
                if (policy.hasReport)
                  TextButton(
                    onPressed: () => context.push('/summary/${policy.reportId}'),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View Details', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: small ? 11 : 12),
      ),
    );
  }

  Widget _buildTextRow(String? label, String? value, {Color? color, bool isDark = false}) {
    if (value == null || value.trim().isEmpty || value.trim() == '---' || value.trim() == 'N/A') {
      return const SizedBox.shrink();
    }
    final defaultColor = isDark ? Colors.grey.shade300 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: label == null
          ? Text(value,
              style: TextStyle(
                  color: color ?? defaultColor,
                  fontSize: 14,
                  fontWeight: color != null ? FontWeight.bold : FontWeight.normal))
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
