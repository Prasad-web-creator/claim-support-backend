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
                      final label = 'Policy ${policy.sequenceNumber ?? ''}'.trim();
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
                              await ref.read(policiesProvider.notifier).deletePolicy(policy.id!);
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
                          color: theme.cardTheme.color ?? theme.cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.transparent),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (policy.createdAt != null)
                                  Text('Uploaded: ${DateFormat("MMM d, yyyy • hh:mm a").format(policy.createdAt!.toLocal())}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: policy.status == 'Active' ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    policy.status,
                                    style: TextStyle(
                                      color: policy.status == 'Active' ? Colors.green : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDelete(context, ref, policy.id!, label),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (policy.gridFsFileId != null) {
                                context.push('/view-pdf/${policy.gridFsFileId}?title=Policy%20${policy.sequenceNumber ?? ''}');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No PDF document attached to this policy.')),
                                );
                              }
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
    );
  }
}
