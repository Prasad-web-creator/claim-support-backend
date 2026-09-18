/// Client-side view of a multi-policy analysis session.
///
/// Mirrors the payload returned by `/analysis/start-multi` and
/// `/analysis/multi/{sessionId}`: one prescription, N independent policy results.
class PolicyAnalysisResult {
  final String policyId;
  final String policyName;
  final String insuranceCompany;
  final String status;
  final String overallStatus;
  final String decisionType;
  final double dominanceScore;
  final String reportId;
  final String sessionId;
  final List<dynamic> questions;
  final String errorMessage;
  final String failedAtStage;

  /// Real progress for this policy, as reported by the backend: the step it has
  /// actually reached and how many of its steps are genuinely finished.
  final String stage;
  final String stageLabel;
  final int completedSteps;
  final int totalSteps;

  const PolicyAnalysisResult({
    required this.policyId,
    required this.policyName,
    required this.insuranceCompany,
    required this.status,
    required this.overallStatus,
    required this.decisionType,
    required this.dominanceScore,
    required this.reportId,
    required this.sessionId,
    required this.questions,
    required this.errorMessage,
    required this.failedAtStage,
    required this.stage,
    required this.stageLabel,
    required this.completedSteps,
    required this.totalSteps,
  });

  factory PolicyAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PolicyAnalysisResult(
      policyId: json['policyId']?.toString() ?? '',
      policyName: json['policyName']?.toString() ?? '',
      insuranceCompany: json['insuranceCompany']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      overallStatus: json['overallStatus']?.toString() ?? '',
      decisionType: json['decisionType']?.toString() ?? '',
      dominanceScore: (json['dominanceScore'] as num?)?.toDouble() ?? 0.0,
      reportId: json['reportId']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      questions: (json['questions'] as List?) ?? const [],
      errorMessage: json['errorMessage']?.toString() ?? '',
      failedAtStage: json['failedAtStage']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'queued',
      stageLabel: json['stageLabel']?.toString() ?? '',
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isWaitingForUser => status == 'waiting_for_user';
  bool get isFailed => status == 'failed' || status == 'invalid';
  bool get isDone =>
      status == 'completed' || status == 'manual_review_required' || isFailed;
  bool get isRunning => !isDone && !isWaitingForUser;
  bool get hasReport => reportId.isNotEmpty;

  /// Fraction of this policy's steps that are actually done, or null when the
  /// backend did not report step counts (nothing to draw rather than a guess).
  double? get stepProgress {
    if (totalSteps <= 0) return null;
    return (completedSteps.clamp(0, totalSteps)) / totalSteps;
  }

  /// What this policy is doing right now, in words.
  String get progressLabel {
    if (stageLabel.isNotEmpty) return stageLabel;
    if (isDone) return 'Finished';
    if (isWaitingForUser) return 'Waiting for your answer';
    return 'Waiting to start';
  }

  /// Same policy, restarted: the step counters go back to zero because none of
  /// its steps are finished any more.
  PolicyAnalysisResult restarted(String newStatus) {
    return PolicyAnalysisResult(
      policyId: policyId,
      policyName: policyName,
      insuranceCompany: insuranceCompany,
      status: newStatus,
      overallStatus: '',
      decisionType: decisionType,
      dominanceScore: dominanceScore,
      reportId: reportId,
      sessionId: sessionId,
      questions: const [],
      errorMessage: '',
      failedAtStage: '',
      stage: 'queued',
      stageLabel: '',
      completedSteps: 0,
      totalSteps: totalSteps,
    );
  }

  String get displayName {
    if (policyName.trim().isNotEmpty) return policyName.trim();
    if (insuranceCompany.trim().isNotEmpty) return insuranceCompany.trim();
    return 'Policy';
  }

  /// Short label for the status chip.
  String get statusLabel {
    switch (status) {
      case 'queued':
        return 'Queued';
      case 'extracting':
      case 'analyzing':
      case 'reanalyzing':
        return 'Analyzing';
      case 'waiting_for_user':
        return 'Needs your input';
      case 'manual_review_required':
        return 'Manual review';
      case 'invalid':
        return 'Invalid policy';
      case 'failed':
        return 'Failed';
      case 'completed':
        return overallStatus.isNotEmpty ? overallStatus : 'Completed';
      default:
        return status;
    }
  }
}

class MultiAnalysisSession {
  final String sessionId;
  final String prescriptionId;
  final String status;
  final int policyCount;
  final List<PolicyAnalysisResult> policyAnalyses;
  final Map<String, dynamic> comparisonSummary;
  final Map<String, dynamic> prescription;
  final String errorMessage;

  /// Session-wide progress reported by the backend, counted in steps the
  /// pipeline has actually finished.
  final AnalysisProgress progress;

  const MultiAnalysisSession({
    required this.sessionId,
    required this.prescriptionId,
    required this.status,
    required this.policyCount,
    required this.policyAnalyses,
    required this.comparisonSummary,
    required this.prescription,
    required this.errorMessage,
    required this.progress,
  });

  factory MultiAnalysisSession.fromJson(Map<String, dynamic> json) {
    return MultiAnalysisSession(
      sessionId: json['sessionId']?.toString() ?? '',
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      policyCount: (json['policyCount'] as num?)?.toInt() ?? 0,
      policyAnalyses: ((json['policyAnalyses'] as List?) ?? const [])
          .map((e) => PolicyAnalysisResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      comparisonSummary: Map<String, dynamic>.from(
          (json['comparisonSummary'] as Map?) ?? const {}),
      prescription: Map<String, dynamic>.from((json['prescription'] as Map?) ?? const {}),
      errorMessage: json['errorMessage']?.toString() ?? '',
      progress: AnalysisProgress.fromJson(
        (json['progress'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// The first policy still awaiting an answer, if any.
  PolicyAnalysisResult? get pendingClarification {
    for (final p in policyAnalyses) {
      if (p.isWaitingForUser && p.questions.isNotEmpty) return p;
    }
    return null;
  }

  bool get isSettled => policyAnalyses.every((p) => p.isDone);
  int get completedCount => policyAnalyses.where((p) => p.isDone).length;
  String get bestPolicyId => comparisonSummary['bestPolicyId']?.toString() ?? '';

  /// The same session with one policy marked as started again — used the moment
  /// the user answers or retries, so the screen reacts without claiming any
  /// progress the server has not reported yet.
  MultiAnalysisSession withPolicyRestarted(String policyId, String status) {
    return MultiAnalysisSession(
      sessionId: sessionId,
      prescriptionId: prescriptionId,
      status: 'analyzing',
      policyCount: policyCount,
      policyAnalyses: policyAnalyses
          .map((p) => p.policyId == policyId ? p.restarted(status) : p)
          .toList(),
      comparisonSummary: comparisonSummary,
      prescription: prescription,
      errorMessage: '',
      progress: progress,
    );
  }

  /// True while the backend still has work in flight for this session.
  bool get isWorking => policyAnalyses.any((p) => p.isRunning) || policyAnalyses.isEmpty;

  /// True when everything that can proceed has, and the user must answer first.
  bool get isBlockedOnUser =>
      !isWorking && policyAnalyses.any((p) => p.isWaitingForUser);
}

/// Steps finished out of steps planned, straight from the server.
///
/// Nothing here is estimated or time-based: the counters only move when the
/// pipeline reports a step as reached, so an empty payload yields no bar at all
/// rather than a made-up one.
class AnalysisProgress {
  final int completedSteps;
  final int totalSteps;
  final String label;
  final int policiesFinished;
  final int policyCount;

  const AnalysisProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.label,
    required this.policiesFinished,
    required this.policyCount,
  });

  factory AnalysisProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AnalysisProgress.unknown();
    return AnalysisProgress(
      completedSteps: (json['completedSteps'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      policiesFinished: (json['policiesFinished'] as num?)?.toInt() ?? 0,
      policyCount: (json['policyCount'] as num?)?.toInt() ?? 0,
    );
  }

  const AnalysisProgress.unknown()
      : completedSteps = 0,
        totalSteps = 0,
        label = '',
        policiesFinished = 0,
        policyCount = 0;

  bool get isKnown => totalSteps > 0;

  /// 0.0–1.0, or null when the server reported no step counts — the UI then
  /// shows an indeterminate indicator instead of inventing a value.
  double? get fraction {
    if (!isKnown) return null;
    return completedSteps.clamp(0, totalSteps) / totalSteps;
  }

  int get percent => isKnown ? ((fraction ?? 0) * 100).round() : 0;
}
