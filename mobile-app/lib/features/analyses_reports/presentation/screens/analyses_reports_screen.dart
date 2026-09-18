import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/features/analysis_reports/presentation/controllers/analysis_report_controller.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report_group.dart';

/// Coverage Analysis Reports screen.
///
/// Groups policies analyzed against the same prescription under one clean,
/// expandable parent report card matching the reference design.
class AnalysesReportsScreen extends ConsumerStatefulWidget {
  const AnalysesReportsScreen({super.key});

  @override
  ConsumerState<AnalysesReportsScreen> createState() => _AnalysesReportsScreenState();
}

class _AnalysesReportsScreenState extends ConsumerState<AnalysesReportsScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);

  bool _isSelectionMode = false;
  final Set<String> _selectedGroupIds = {};
  final Set<String> _expandedGroupIds = {};

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

  void _toggleExpand(String groupId) {
    setState(() {
      if (_expandedGroupIds.contains(groupId)) {
        _expandedGroupIds.remove(groupId);
      } else {
        _expandedGroupIds.add(groupId);
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

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(analysisReportProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Every group starts collapsed: a card opens only when the user taps it.
    final currentGroups = reportState.value?.docs ?? [];

    final validIds = currentGroups.map((g) => g.groupId).toSet();
    final allSelected = validIds.isNotEmpty && _selectedGroupIds.containsAll(validIds);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  )
                : null),
        title: Text(
          _isSelectionMode ? '${_selectedGroupIds.length} Selected' : 'Coverage Analysis Reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
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
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _selectedGroupIds.isNotEmpty ? Colors.redAccent : Colors.redAccent.withAlpha(110),
                ),
                tooltip: 'Delete Selected',
                onPressed: _selectedGroupIds.isNotEmpty ? _confirmBatchDelete : null,
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Select / Manage',
                onPressed: () => _enterSelectionMode(),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: reportState.when(
            data: (pagination) {
              final groups = pagination.docs;
              if (groups.isEmpty) {
                return const Center(
                  child: Text(
                    'No analysis reports found.',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                );
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
    final isExpanded = _expandedGroupIds.contains(group.groupId);
    final statusLabel = group.statusLabel;

    final dateStr = group.createdAt != null
        ? DateFormat('dd-MM-yyyy  h:mm a').format(group.createdAt!.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E3A8A).withAlpha(40) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? _primaryBlue
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _enterSelectionMode(group.groupId),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(group.groupId);
            } else {
              _toggleExpand(group.groupId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Line 1: Header Icons & Status Row ───────────────────────
                Row(
                  children: [
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Checkbox(
                          value: isSelected,
                          activeColor: _primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) => _toggleSelection(group.groupId),
                        ),
                      ),

                    // File Icon Box
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description_outlined,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status Pill (e.g. Completed)
                    _buildStatusPill(statusLabel),

                    const Spacer(),

                    // Dropdown / Expand Icon
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _toggleExpand(group.groupId),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          size: 22,
                        ),
                      ),
                    ),

                    if (!_isSelectionMode) ...[
                      const SizedBox(width: 6),
                      // Delete Icon
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _confirmDeleteSingle(group),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // ── Line 2: Full Width Diagnosis Title ──────────────────────
                Text(
                  group.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Line 3+: Metadata Rows ──────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.patientName.isNotEmpty)
                      _buildMetaRow(
                        Icons.calendar_today_outlined,
                        'Patient Name',
                        group.patientName,
                        isDark,
                      ),
                    if (group.displayVisitDate.isNotEmpty)
                      _buildMetaRow(
                        Icons.calendar_today_outlined,
                        'Prescription Date',
                        group.displayVisitDate,
                        isDark,
                      )
                    else if (group.visitDate.isNotEmpty)
                      _buildMetaRow(
                        Icons.calendar_today_outlined,
                        'Prescription Date',
                        group.visitDate,
                        isDark,
                      ),
                    _buildMetaRow(
                      Icons.description_outlined,
                      'Policies Analyzed',
                      '${group.policyCount}',
                      isDark,
                    ),
                    if (dateStr.isNotEmpty)
                      _buildMetaRow(
                        Icons.access_time_rounded,
                        'Analyzed DateTime',
                        dateStr,
                        isDark,
                      ),
                    if (group.displayProcessingTime.isNotEmpty)
                      _buildMetaRow(
                        Icons.access_time_rounded,
                        'Proccessed time',
                        group.displayProcessingTime,
                        isDark,
                      ),
                  ],
                ),

                // ── Nested Policies (Visible when expanded) ──────────────────
                if (isExpanded && group.policyReports.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    thickness: 1,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  ...group.policyReports.map((p) => _buildNestedPolicyCard(p, isDark)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nested policy card matching user specification: Shield Icon, Coverage status, Right arrow on Line 1, Policy details on Line 2+, View Details > removed.
  Widget _buildNestedPolicyCard(PolicyReportRow policy, bool isDark) {
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D52) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (policy.hasReport) {
              context.push('/summary/${policy.reportId}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Line 1: Shield Icon  Coverage status  Right side arrow icon ──
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                          size: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPolicyStatusPill(policy.statusLabel),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Line 2+: Full Width Policy Name & Details ────────────────
                Text(
                  policy.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        policy.policyNumber.isNotEmpty
                            ? 'Policy No: ${policy.policyNumber}'
                            : (policy.insuranceCompany.isNotEmpty
                                ? policy.insuranceCompany
                                : 'Policy No: ---'),
                        style: TextStyle(fontSize: 12, color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (policy.displayPeriod.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: subColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Period: ${policy.displayPeriod}',
                          style: TextStyle(fontSize: 12, color: subColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                if (policy.isFailed && policy.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    policy.errorMessage,
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Status badge for parent analysis header (Completed, Analyzing, Failed, etc.).
  Widget _buildStatusPill(String label) {
    final lower = label.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;

    if (lower.contains('fail') || lower.contains('invalid')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else if (lower.contains('needs your input') ||
        lower.contains('partial') ||
        lower.contains('manual review') ||
        lower.contains('review')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.error_outline_rounded;
    } else if (lower.contains('not covered') || lower.contains('rejected')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else if (lower.contains('analyzing') || lower.contains('queued') || lower.contains('extracting')) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      icon = Icons.hourglass_empty_rounded;
    } else {
      bg = const Color(0xFFE8F8F0);
      fg = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Policy status pill (Covered, Not Covered, etc.) with icons matching reference UI.
  Widget _buildPolicyStatusPill(String label) {
    final lower = label.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;

    if (lower.contains('not covered') || lower.contains('fail') || lower.contains('rejected')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else if (lower.contains('needs your input') || lower.contains('manual review') || lower.contains('review')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.error_outline_rounded;
    } else if (lower.contains('analyzing') || lower.contains('queued')) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      icon = Icons.hourglass_empty_rounded;
    } else {
      bg = const Color(0xFFE8F8F0);
      fg = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  /// Clean metadata text row with leading icon matching Image 2 reference UI.
  Widget _buildMetaRow(IconData icon, String label, String value, bool isDark) {
    if (value.trim().isEmpty || value.trim() == '---' || value.trim() == 'N/A') {
      return const SizedBox.shrink();
    }
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final valueColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: labelColor),
          const SizedBox(width: 8),
          Text(
            '$label:  ',
            style: TextStyle(
              fontSize: 12.5,
              color: labelColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
