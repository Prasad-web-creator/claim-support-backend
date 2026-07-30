class AnalysisReport {
  final String id;
  final String title;
  final String? summary;
  final String? content;
  final String? relatedFileId; // e.g. the policy or report that was analyzed
  final String? relatedModel; // 'Policy', 'Prescription', 'MedicalReport', 'MedicalBill'
  final int? confidenceScore;
  final String? overallStatus;
  final String? summaryText;
  final int? reportNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AnalysisReport({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    this.relatedFileId,
    this.relatedModel,
    this.confidenceScore,
    this.overallStatus,
    this.summaryText,
    this.reportNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory AnalysisReport.fromJson(Map<String, dynamic> json) {
    return AnalysisReport(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? 'Analysis Report',
      summary: json['summary'],
      content: json['content'],
      relatedFileId: json['relatedFileId'],
      relatedModel: json['relatedModel'],
      confidenceScore: (json['confidenceScore'] as num?)?.toInt(),
      overallStatus: json['overallStatus'],
      summaryText: json['summaryText'],
      reportNumber: (json['reportNumber'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'relatedFileId': relatedFileId,
      'relatedModel': relatedModel,
      'confidenceScore': confidenceScore,
      'overallStatus': overallStatus,
      'summaryText': summaryText,
    };
  }
}
