import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:intl/intl.dart';

class PrescriptionListScreen extends ConsumerWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionState = ref.watch(prescriptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: prescriptionState.when(
              data: (pagination) {
                final prescriptions = pagination.docs;
                if (prescriptions.isEmpty) {
                  return const Center(
                    child: Text('No prescriptions found. Add one!'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(prescriptionProvider.notifier).fetchPrescriptions(isRefresh: true);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: prescriptions.length + (pagination.hasNextPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == prescriptions.length) {
                        ref.read(prescriptionProvider.notifier).loadNextPage();
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      
                      final prescription = prescriptions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: theme.cardTheme.color ?? theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.transparent),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text('Prescription ${prescription.sequenceNumber ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (prescription.createdAt != null)
                                Text('Uploaded: ${DateFormat("MMM d, yyyy • hh:mm a").format(prescription.createdAt!.toLocal())}'),
                            ],
                          ),
                          onTap: () {
                            if (prescription.gridFsFileId != null) {
                              context.push('/view-pdf/${prescription.gridFsFileId}?title=Prescription%20${prescription.sequenceNumber ?? ''}');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No PDF document attached to this prescription.')),
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
