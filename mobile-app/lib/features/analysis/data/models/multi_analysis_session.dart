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
    );
  }

  bool get isWaitingForUser => status == 'waiting_for_user';
  bool get isFailed => status == 'failed' || status == 'invalid';
  bool get isDone =>
      status == 'completed' || status == 'manual_review_required' || isFailed;
  bool get isRunning => !isDone && !isWaitingForUser;
  bool get hasReport => reportId.isNotEmpty;

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

  const MultiAnalysisSession({
    required this.sessionId,
    required this.prescriptionId,
    required this.status,
    required this.policyCount,
    required this.policyAnalyses,
    required this.comparisonSummary,
    required this.prescription,
    required this.errorMessage,
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
}
