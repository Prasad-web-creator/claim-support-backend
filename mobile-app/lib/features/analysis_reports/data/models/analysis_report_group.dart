import 'package:intl/intl.dart';

/// A Coverage Analysis Reports list entry.
///
/// One group = one analysis. When several policies were analysed against the
/// same prescription they share a group; a classic single-policy analysis is a
/// group of one. Each policy inside keeps its own independent result.
class PolicyReportRow {
  final String policyId;
  final String policyName;
  final String policyNumber;
  final String insuranceCompany;
  final String policyStartDate;
  final String policyEndDate;
  final String status;
  final String overallStatus;
  final String outcome;
  final String decisionType;
  final double dominanceScore;
  final int processingTimeMs;
  final String reportId;
  final String reportLabel;
  final String errorMessage;
  final List<dynamic> questions;

  const PolicyReportRow({
    required this.policyId,
    required this.policyName,
    required this.policyNumber,
    required this.insuranceCompany,
    this.policyStartDate = '',
    this.policyEndDate = '',
    required this.status,
    required this.overallStatus,
    required this.outcome,
    required this.decisionType,
    required this.dominanceScore,
    required this.processingTimeMs,
    required this.reportId,
    required this.reportLabel,
    required this.errorMessage,
    required this.questions,
  });

  factory PolicyReportRow.fromJson(Map<String, dynamic> json) {
    return PolicyReportRow(
      policyId: json['policyId']?.toString() ?? '',
      policyName: json['policyName']?.toString() ?? '',
      policyNumber: json['policyNumber']?.toString() ?? '',
      insuranceCompany: json['insuranceCompany']?.toString() ?? '',
      policyStartDate: json['policyStartDate']?.toString() ?? '',
      policyEndDate: json['policyEndDate']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      overallStatus: json['overallStatus']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? '',
      decisionType: json['decisionType']?.toString() ?? '',
      dominanceScore: (json['dominanceScore'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: (json['processingTimeMs'] as num?)?.toInt() ?? 0,
      reportId: json['reportId']?.toString() ?? '',
      reportLabel: json['reportLabel']?.toString() ?? '',
      errorMessage: json['errorMessage']?.toString() ?? '',
      questions: (json['questions'] as List?) ?? const [],
    );
  }

  bool get hasReport => reportId.isNotEmpty;
  bool get isWaitingForUser => status == 'waiting_for_user';
  bool get isFailed => status == 'failed' || status == 'invalid';
  bool get isRunning =>
      status == 'queued' || status == 'extracting' || status == 'analyzing' || status == 'reanalyzing';

  String get displayName {
    if (policyName.trim().isNotEmpty) return policyName.trim();
    if (insuranceCompany.trim().isNotEmpty) return insuranceCompany.trim();
    return 'Policy';
  }

  String get displayPeriod {
    final start = _formatDateStr(policyStartDate);
    final end = _formatDateStr(policyEndDate);
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start to $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '';
  }

  static String _formatDateStr(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return raw;
  }

  /// Text for the per-policy status chip.
  String get statusLabel {
    if (isWaitingForUser) return 'Needs your input';
    if (status == 'failed') return 'Failed';
    if (status == 'invalid') return overallStatus.isNotEmpty ? overallStatus : 'Invalid policy';
    if (status == 'manual_review_required') return 'Manual review';
    if (isRunning) return 'Analyzing';
    return overallStatus.isNotEmpty ? overallStatus : 'Completed';
  }

  String get displayProcessingTime =>
      processingTimeMs > 0 ? '${(processingTimeMs / 1000).toStringAsFixed(1)}s' : '';
}

class AnalysisReportGroup {
  final String groupId;
  final String groupType; // 'multi' | 'single'
  final String prescriptionId;
  final String status;
  final int policyCount;
  final int completedCount;
  final int totalProcessingTimeMs;
  final List<String> reportIds;
  final List<PolicyReportRow> policyReports;
  final Map<String, dynamic> prescription;
  final DateTime? createdAt;

  const AnalysisReportGroup({
    required this.groupId,
    required this.groupType,
    required this.prescriptionId,
    required this.status,
    required this.policyCount,
    required this.completedCount,
    required this.totalProcessingTimeMs,
    required this.reportIds,
    required this.policyReports,
    required this.prescription,
    required this.createdAt,
  });

  factory AnalysisReportGroup.fromJson(Map<String, dynamic> json) {
    return AnalysisReportGroup(
      groupId: json['groupId']?.toString() ?? '',
      groupType: json['groupType']?.toString() ?? 'single',
      prescriptionId: json['prescriptionId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      policyCount: (json['policyCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      totalProcessingTimeMs: (json['totalProcessingTimeMs'] as num?)?.toInt() ?? 0,
      reportIds: ((json['reportIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      policyReports: ((json['policyReports'] as List?) ?? const [])
          .map((e) => PolicyReportRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      prescription: Map<String, dynamic>.from((json['prescription'] as Map?) ?? const {}),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isMultiPolicy => groupType == 'multi' && policyCount > 1;

  String get diagnosis => prescription['diagnosis']?.toString() ?? '';
  String get patientName => prescription['patientName']?.toString() ?? '';
  String get visitDate => prescription['visitDate']?.toString() ?? '';

  String get displayVisitDate {
    if (visitDate.trim().isEmpty) return '';
    try {
      final dt = DateTime.tryParse(visitDate);
      if (dt != null) {
        return DateFormat('dd-MMM-yyyy').format(dt);
      }
    } catch (_) {}
    return visitDate;
  }

  /// Heading for the group card.
  String get title {
    if (diagnosis.trim().isNotEmpty) return diagnosis.trim();
    if (patientName.trim().isNotEmpty) return patientName.trim();
    if (policyReports.isNotEmpty) {
      final label = policyReports.first.reportLabel;
      if (label.isNotEmpty) return label;
    }
    return 'Coverage Analysis';
  }

  /// Overall status text shown on the group header.
  String get statusLabel {
    switch (status) {
      case 'partial':
        return 'Partially completed';
      case 'waiting_for_user':
        return 'Needs your input';
      case 'failed':
        return 'Failed';
      case 'queued':
      case 'extracting':
      case 'analyzing':
      case 'reanalyzing':
        return 'Analyzing';
      case 'manual_review_required':
        return 'Manual review';
      case 'completed':
        return 'Completed';
      default:
        return status.isEmpty ? 'Pending' : status;
    }
  }

  String get displayProcessingTime =>
      totalProcessingTimeMs > 0 ? '${(totalProcessingTimeMs / 1000).toStringAsFixed(1)}s' : '';
}
