import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:intl/intl.dart';

class PolicyListScreen extends ConsumerWidget {
  const PolicyListScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Policy', style: TextStyle(fontWeight: FontWeight.bold)),
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
        await ref.read(policiesProvider.notifier).deletePolicy(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Policy deleted successfully.'), backgroundColor: Colors.green),
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
    final policyState = ref.watch(policiesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Policies'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: policyState.when(
              data: (pagination) {
                final policies = pagination.docs;
                if (policies.isEmpty) {
                  return const Center(
                    child: Text('No policies found. Add one!'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(policiesProvider.notifier).fetchPolicies(isRefresh: true);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: policies.length + (pagination.hasNextPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == policies.length) {
                        ref.read(policiesProvider.notifier).loadNextPage();
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final policy = policies[index];
                      final label = policy.displayId;
                      return Dismissible(
                        key: ValueKey(policy.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                              title: const Text('Delete Policy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              await ref.read(policiesProvider.notifier).deletePolicy(policy.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Policy deleted successfully.'), backgroundColor: Colors.green),
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
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: isDark ? 0 : 1,
                          color: isDark ? const Color(0xFF1E2230) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (policy.gridFsFileId != null) {
                                context.push('/view-pdf/${policy.gridFsFileId}?title=${policy.displayId}');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No PDF document attached to this policy.')),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Builder(
                                builder: (context) {
                                  final policyDisplayName = policy.policyName.trim().isNotEmpty && policy.policyName != 'Uploaded Policy'
                                      ? policy.policyName
                                      : (policy.insuranceCompany.trim().isNotEmpty
                                          ? (policy.policyType != null && policy.policyType!.isNotEmpty
                                              ? "${policy.insuranceCompany} - ${policy.policyType}"
                                              : policy.insuranceCompany)
                                          : (policy.originalFileName ?? 'Insurance Policy'));

                                  final formattedStart = policy.policyStartDate != null
                                      ? DateFormat('dd-MM-yyyy').format(policy.policyStartDate!.toLocal())
                                      : null;
                                  final formattedEnd = policy.policyEndDate != null
                                      ? DateFormat('dd-MM-yyyy').format(policy.policyEndDate!.toLocal())
                                      : null;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header: PCY ID + Status + Delete Action
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E3A8A).withAlpha(80) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF3B82F6).withAlpha(80) : const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: Text(
                                              policy.displayId,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: policy.status == 'Active'
                                                      ? (isDark ? Colors.green.shade900.withAlpha(80) : const Color(0xFFDCFCE7))
                                                      : (isDark ? Colors.red.shade900.withAlpha(80) : const Color(0xFFFEE2E2)),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  policy.status,
                                                  style: TextStyle(
                                                    color: policy.status == 'Active'
                                                        ? (isDark ? Colors.green.shade300 : const Color(0xFF15803D))
                                                        : (isDark ? Colors.red.shade300 : const Color(0xFFB91C1C)),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                tooltip: 'Delete',
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                onPressed: () => _confirmDelete(context, ref, policy.id, label),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Policy Name
                                      Text(
                                        policyDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Policy Holder Name
                                      if (policy.policyHolderName != null && policy.policyHolderName!.trim().isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Holder: ${policy.policyHolderName}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Policy Number
                                      if (policy.policyNumber.trim().isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.tag, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Policy No: ${policy.policyNumber}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Policy Start & End Date
                                      if (formattedStart != null && formattedEnd != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Validity: $formattedStart to $formattedEnd",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ] else if (formattedStart != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Start Date: $formattedStart",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ] else if (formattedEnd != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.event_busy_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Expiry: $formattedEnd",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Policy File Name
                                      if (policy.originalFileName != null && policy.originalFileName!.trim().isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.insert_drive_file_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "File: ${policy.originalFileName}",
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],

                                      // Policy Uploaded Date with Time (12-hour AM/PM)
                                      if (policy.createdAt != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Uploaded: ${DateFormat('dd-MM-yyyy hh:mm a').format(policy.createdAt!.toLocal())}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  );
                                },
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
    );
  }
}
