import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';

class DashboardStats {
  final int totalPolicies;
  final int totalPrescriptions;

  final int totalAnalysisReports;
  final List<AnalysisReport> recentAnalyses;

  DashboardStats({
    required this.totalPolicies,
    required this.totalPrescriptions,

    required this.totalAnalysisReports,
    this.recentAnalyses = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalPolicies: (json['totalPolicies'] as num?)?.toInt() ?? 0,
      totalPrescriptions: (json['totalPrescriptions'] as num?)?.toInt() ?? 0,

      totalAnalysisReports: (json['totalAnalysisReports'] as num?)?.toInt() ?? 0,
      recentAnalyses: (json['recentAnalyses'] as List<dynamic>?)
              ?.map((e) => AnalysisReport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
