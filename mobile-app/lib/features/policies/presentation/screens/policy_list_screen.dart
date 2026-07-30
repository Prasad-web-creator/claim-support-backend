import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:intl/intl.dart';

class PolicyListScreen extends ConsumerWidget {
  const PolicyListScreen({super.key});

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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: theme.cardTheme.color ?? theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.transparent),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text('Policy ${policy.sequenceNumber ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (policy.createdAt != null)
                                Text('Uploaded: ${DateFormat("MMM d, yyyy • hh:mm a").format(policy.createdAt!.toLocal())}'),
                            ],
                          ),
                          trailing: Container(
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
