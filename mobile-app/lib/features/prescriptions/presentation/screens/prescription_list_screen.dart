import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:intl/intl.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends ConsumerState<PrescriptionListScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPrescriptionIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _isSelectionMode = true;
      if (initialId != null) {
        _selectedPrescriptionIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPrescriptionIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPrescriptionIds.contains(id)) {
        _selectedPrescriptionIds.remove(id);
        if (_selectedPrescriptionIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPrescriptionIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Prescription> currentPrescriptions) {
    setState(() {
      final allIds = currentPrescriptions.map((p) => p.id).toSet();
      if (_selectedPrescriptionIds.containsAll(allIds)) {
        _selectedPrescriptionIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedPrescriptionIds.addAll(allIds);
      }
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedPrescriptionIds.isEmpty) return;
    final count = _selectedPrescriptionIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Selected Prescriptions', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete $count selected prescription(s)? This action cannot be undone.',
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
        final idsToDelete = _selectedPrescriptionIds.toList();
        await ref.read(prescriptionProvider.notifier).deletePrescriptions(idsToDelete);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count prescriptions deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _exitSelectionMode();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete prescriptions: $e'), backgroundColor: Colors.red),
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
        title: const Text('Delete Prescription', style: TextStyle(fontWeight: FontWeight.bold)),
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
        await ref.read(prescriptionProvider.notifier).deletePrescription(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prescription deleted successfully.'), backgroundColor: Colors.green),
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
    final prescriptionState = ref.watch(prescriptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentPrescriptions = prescriptionState.value?.docs ?? [];
    final allSelected = currentPrescriptions.isNotEmpty &&
        _selectedPrescriptionIds.containsAll(currentPrescriptions.map((p) => p.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedPrescriptionIds.length} Selected' : 'My Prescriptions',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: () => _toggleSelectAll(currentPrescriptions),
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
                color: _selectedPrescriptionIds.isNotEmpty ? Colors.redAccent : Colors.grey,
              ),
              tooltip: 'Delete Selected',
              onPressed: _selectedPrescriptionIds.isNotEmpty ? _confirmBatchDelete : null,
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
                      final label = prescription.displayId;
                      final isSelected = _selectedPrescriptionIds.contains(prescription.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: isDark ? 0 : 1,
                        color: isSelected
                            ? (isDark ? const Color(0xFF065F46).withAlpha(40) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF1E2230) : Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onLongPress: () => _enterSelectionMode(prescription.id),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(prescription.id);
                            } else {
                              if (prescription.gridFsFileId != null) {
                                context.push('/view-pdf/${prescription.gridFsFileId}?title=${prescription.displayId}');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No PDF document attached to this prescription.')),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Builder(
                              builder: (context) {
                                final hospitalDisplayName = prescription.hospitalName.trim().isNotEmpty
                                    ? prescription.hospitalName
                                    : (prescription.originalFileName ?? 'Prescription / Medical Bill');

                                final formattedVisitDate = prescription.visitDate != null
                                    ? DateFormat('dd-MM-yyyy').format(prescription.visitDate!.toLocal())
                                    : null;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isSelectionMode) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(right: 12, top: 2),
                                        child: Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (_) => _toggleSelection(prescription.id),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Header: PSCT ID + Delete Action
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF065F46).withAlpha(80) : const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFA7F3D0),
                                                  ),
                                                ),
                                                child: Text(
                                                  prescription.displayId,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                                  ),
                                                ),
                                              ),
                                              if (!_isSelectionMode) ...[
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                  tooltip: 'Delete',
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  onPressed: () => _confirmDeleteSingle(prescription.id, label),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Hospital / Clinic Name
                                          Text(
                                            hospitalDisplayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Patient Name
                                          if (prescription.patientName != null && prescription.patientName!.trim().isNotEmpty) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Patient: ${prescription.patientName}",
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

                                          // Doctor Name
                                          if (prescription.doctorName.trim().isNotEmpty) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.medical_services_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Doctor: ${prescription.doctorName}",
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

                                          // Prescription Number
                                          if (prescription.prescriptionNumber != null && prescription.prescriptionNumber!.trim().isNotEmpty) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.tag, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Prescription No: ${prescription.prescriptionNumber}",
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

                                          // Consult Date
                                          if (formattedVisitDate != null) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Consult Date: $formattedVisitDate",
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

                                          // Prescription File Name
                                          if (prescription.originalFileName != null && prescription.originalFileName!.trim().isNotEmpty) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.insert_drive_file_outlined, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "File: ${prescription.originalFileName}",
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

                                          // Prescription Uploaded Date with Time (12-hour AM/PM)
                                          if (prescription.createdAt != null) ...[
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Uploaded: ${DateFormat('dd-MM-yyyy hh:mm a').format(prescription.createdAt!.toLocal())}",
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
                                      ),
                                    ),
                                  ],
                                );
                              },
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
