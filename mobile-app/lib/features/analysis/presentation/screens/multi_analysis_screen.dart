import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/features/analysis/data/models/multi_analysis_session.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/multi_analysis_controller.dart';
import 'package:claimsupport/features/analysis/presentation/widgets/clarification_dialog.dart';

/// Multi-policy analysis: one prescription, several policies, one row per policy.
class MultiAnalysisScreen extends ConsumerStatefulWidget {
  const MultiAnalysisScreen({super.key});

  @override
  ConsumerState<MultiAnalysisScreen> createState() => _MultiAnalysisScreenState();
}

class _MultiAnalysisScreenState extends ConsumerState<MultiAnalysisScreen> {
  static const Color _primaryBlue = Color(0xFF2563EB);

  bool _started = false;
  bool _dialogShowing = false;
  String? _answeringPolicyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    final prefs = SharedPrefs.instance;
    final prescriptionPath = prefs.getString('prescription_path');
    final rawIds = prefs.getString('policy_ids');

    List<String> policyIds = [];
    if (rawIds != null && rawIds.isNotEmpty) {
      try {
        policyIds = (jsonDecode(rawIds) as List).map((e) => e.toString()).toList();
      } catch (e) {
        developer.log('[MultiAnalysisScreen] Could not decode policy_ids: $e');
      }
    }

    if (prescriptionPath == null || policyIds.isEmpty) {
      developer.log('[MultiAnalysisScreen] Missing prescription or policy selection');
      return;
    }

    await ref.read(multiAnalysisJobProvider.notifier).startAnalysis(
          MultiAnalysisParams(prescriptionPath: prescriptionPath, policyIds: policyIds),
        );
  }

  void _maybeShowClarification(MultiAnalysisSession session) {
    if (_dialogShowing || !mounted) return;
    final pending = session.pendingClarification;
    if (pending == null) return;

    _dialogShowing = true;
    _answeringPolicyId = pending.policyId;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ClarificationDialog(
        clarificationData: {'questions': pending.questions},
        contextLabel: pending.displayName,
        onSubmit: (answers) {
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
          ref
              .read(multiAnalysisJobProvider.notifier)
              .submitPolicyAnswers(pending.policyId, answers);
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
          _dialogShowing = false;
          _answeringPolicyId = null;
        },
      ),
    ).then((_) => _dialogShowing = false);
  }

  Future<void> _openReport(String reportId) async {
    // Reuse the existing single-report summary screen.
    try {
      final response = await ApiClient().dio.get('/analysis/$reportId');
      if (!mounted) return;
      SharedPrefs.instance.setString('analysis_result', jsonEncode(response.data));
      if (mounted) context.push('/summary/$reportId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(multiAnalysisJobProvider);

    ref.listen(multiAnalysisJobProvider, (previous, next) {
      next.whenData((session) {
        if (_answeringPolicyId != null) {
          final answered = session.policyAnalyses
              .where((p) => p.policyId == _answeringPolicyId)
              .firstOrNull;
          if (answered != null && !answered.isWaitingForUser) {
            _answeringPolicyId = null;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowClarification(session);
        });
      });
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Policy Comparison'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: state.when(
        loading: () => _buildLoading(isDark),
        error: (error, _) => _buildError(isDark, error),
        data: (session) => _buildSession(isDark, session),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _primaryBlue),
          const SizedBox(height: 20),
          Text(
            'Analyzing your prescription against each policy…',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This can take a moment for several policies.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
            const SizedBox(height: 14),
            Text(
              'Analysis could not be completed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSession(bool isDark, MultiAnalysisSession session) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final diagnosis = session.prescription['diagnosis']?.toString() ?? '';
    final visitDate = session.prescription['visitDate']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Prescription header ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: _primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Prescription',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (diagnosis.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(diagnosis, style: TextStyle(fontSize: 15, color: textColor)),
              ],
              if (visitDate.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(visitDate, style: TextStyle(fontSize: 12, color: subColor)),
              ],
              const SizedBox(height: 10),
              Text(
                'Analyzed against ${session.policyCount} '
                '${session.policyCount == 1 ? 'policy' : 'policies'} · '
                '${session.completedCount}/${session.policyCount} finished',
                style: TextStyle(fontSize: 12, color: subColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Policies',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subColor),
        ),
        const SizedBox(height: 8),

        ...session.policyAnalyses.map(
          (policy) => _buildPolicyCard(isDark, session, policy),
        ),
      ],
    );
  }

  Widget _buildPolicyCard(
    bool isDark,
    MultiAnalysisSession session,
    PolicyAnalysisResult policy,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final isBest = session.bestPolicyId.isNotEmpty && session.bestPolicyId == policy.policyId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest
              ? _primaryBlue
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: isBest ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            policy.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBest) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 16, color: _primaryBlue),
                        ],
                      ],
                    ),
                    if (policy.insuranceCompany.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        policy.insuranceCompany,
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusChip(policy),
            ],
          ),

          if (policy.isFailed && policy.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              policy.errorMessage,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              if (policy.isRunning)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
                ),
              if (policy.isWaitingForUser)
                TextButton.icon(
                  onPressed: () => _maybeShowClarification(session),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Answer question'),
                  style: TextButton.styleFrom(foregroundColor: _primaryBlue),
                ),
              if (policy.isFailed)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(multiAnalysisJobProvider.notifier).retryPolicy(policy.policyId),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                ),
              const Spacer(),
              if (policy.hasReport)
                TextButton.icon(
                  onPressed: () => _openReport(policy.reportId),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View report'),
                  style: TextButton.styleFrom(foregroundColor: _primaryBlue),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PolicyAnalysisResult policy) {
    Color color;
    if (policy.isFailed) {
      color = Colors.redAccent;
    } else if (policy.isWaitingForUser) {
      color = Colors.orange;
    } else if (policy.status == 'manual_review_required') {
      color = Colors.amber.shade700;
    } else if (policy.status == 'completed') {
      final lower = policy.overallStatus.toLowerCase();
      if (lower.contains('not covered') || lower.contains('rejected')) {
        color = Colors.redAccent;
      } else if (lower.contains('partial')) {
        color = Colors.orange;
      } else {
        color = Colors.green;
      }
    } else {
      color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        policy.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
