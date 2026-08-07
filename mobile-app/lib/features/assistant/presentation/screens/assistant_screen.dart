import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/theme/theme_provider.dart';
import 'package:claimsupport/features/policies/presentation/controllers/policy_controller.dart';
import 'package:claimsupport/features/prescriptions/presentation/controllers/prescription_controller.dart';
import 'package:claimsupport/features/assistant/presentation/controllers/rag_controller.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  String? _selectedPolicyId;
  String? _selectedPrescriptionId;
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(policiesProvider.notifier).fetchPolicies(isRefresh: true);
      ref.read(prescriptionProvider.notifier).fetchPrescriptions(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _askQuestion() {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    if (_selectedPolicyId == null || _selectedPrescriptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a policy and a prescription first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    ref.read(ragControllerProvider.notifier).askQuestion(
      policyId: _selectedPolicyId!,
      prescriptionId: _selectedPrescriptionId!,
      question: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    
    final policiesState = ref.watch(policiesProvider);
    final prescriptionsState = ref.watch(prescriptionProvider);
    final ragState = ref.watch(ragControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Policy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            policiesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading policies: $err', style: const TextStyle(color: Colors.red)),
              data: (data) {
                if (data.docs.isEmpty) {
                  return const Text('No uploaded policies found.', style: TextStyle(fontStyle: FontStyle.italic));
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedPolicyId,
                  hint: const Text('Choose a policy...'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                  items: data.docs.map((policy) {
                    final name = policy.policyName.isNotEmpty ? policy.policyName : 'Unknown Policy';
                    final company = policy.insuranceCompany.isNotEmpty ? policy.insuranceCompany : 'Unknown Company';
                    return DropdownMenuItem(
                      value: policy.id,
                      child: Text('$name ($company)'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPolicyId = val),
                );
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Prescription',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            prescriptionsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading prescriptions: $err', style: const TextStyle(color: Colors.red)),
              data: (data) {
                if (data.docs.isEmpty) {
                  return const Text('No uploaded prescriptions found.', style: TextStyle(fontStyle: FontStyle.italic));
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedPrescriptionId,
                  hint: const Text('Choose a prescription...'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                  items: data.docs.map((rx) {
                    final hospital = rx.hospitalName.isNotEmpty ? rx.hospitalName : 'Unknown Hospital';
                    final doctor = rx.doctorName.isNotEmpty ? rx.doctorName : 'Unknown Doctor';
                    return DropdownMenuItem(
                      value: rx.id,
                      child: Text('$hospital - $doctor'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPrescriptionId = val),
                );
              },
            ),
            const SizedBox(height: 32),

            const Text(
              'Ask Question',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ask anything about your selected policy and prescription...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_selectedPolicyId != null && _selectedPrescriptionId != null && !ragState.isLoading)
                    ? _askQuestion
                    : null,
                icon: ragState.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(ragState.isLoading ? 'Asking Assistant...' : 'Ask Assistant'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ragState.when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (result) {
                if (result == null) return const SizedBox.shrink();

                final answer = result['answer'] as String? ?? 'No answer provided.';
                final sources = result['sources'] as List<dynamic>? ?? [];

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'System Response',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        answer,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                      if (sources.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Sources:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...sources.map((s) {
                          final type = s['documentType'] ?? 'Unknown';
                          final page = s['pageNumber'] ?? 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.description_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '${type.toString().toUpperCase()} - Page $page',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }),
                      ]
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
