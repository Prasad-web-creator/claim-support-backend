class AnalysisReport {
  final String id;
  final String title;
  final String? summary;
  final String? content;
  final String? relatedFileId; // e.g. the policy or report that was analyzed
  final String? relatedModel; // 'Policy', 'Prescription', 'MedicalReport', 'MedicalBill'
  final double? dominanceScore;
  final Map<String, dynamic>? coverageBreakdown;
  final String? overallStatus;
  final String? summaryText;
  final int? reportNumber;
  final int? processingTimeMs;
  final String? policyName;
  final String? patientName;
  final Map<String, dynamic>? policyJson;
  final Map<String, dynamic>? prescriptionJson;
  final Map<String, dynamic>? policyMetadata;
  final Map<String, dynamic>? prescriptionMetadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AnalysisReport({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    this.relatedFileId,
    this.relatedModel,
    this.dominanceScore,
    this.coverageBreakdown,
    this.overallStatus,
    this.summaryText,
    this.reportNumber,
    this.processingTimeMs,
    this.policyName,
    this.patientName,
    this.policyJson,
    this.prescriptionJson,
    this.policyMetadata,
    this.prescriptionMetadata,
    this.createdAt,
    this.updatedAt,
  });

  String get displayReportNumber {
    if (reportNumber != null) {
      return 'AN${reportNumber.toString().padLeft(4, '0')}';
    }
    if (id.isNotEmpty) {
      return id.length >= 6 ? 'AN${id.substring(0, 4).toUpperCase()}' : 'AN$id';
    }
    return 'AN0001';
  }

  String get displayPolicyName {
    if (policyName != null && policyName!.trim().isNotEmpty && policyName != 'Uploaded Policy') {
      return policyName!.trim();
    }
    final polName = policyJson?['policyName'] ??
        policyJson?['insuranceCompany'] ??
        policyMetadata?['policy_name'] ??
        policyMetadata?['insurance_company'];
    if (polName != null && polName.toString().trim().isNotEmpty && polName.toString().trim() != 'Uploaded Policy') {
      return polName.toString().trim();
    }
    return 'Not Specified';
  }

  String get displayPatientName {
    if (patientName != null && patientName!.trim().isNotEmpty) {
      return patientName!.trim();
    }
    final pat = prescriptionJson?['patientName'] ??
        prescriptionJson?['patient'] ??
        prescriptionMetadata?['patient_name'] ??
        prescriptionMetadata?['patient'];
    if (pat != null && pat.toString().trim().isNotEmpty) {
      return pat.toString().trim();
    }
    return 'Not Specified';
  }

  String get displayProcessingTime {
    if (processingTimeMs != null && processingTimeMs! > 0) {
      return '${(processingTimeMs! / 1000).toStringAsFixed(1)}s';
    }
    return '';
  }

  factory AnalysisReport.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      final str = val.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return null;
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt;

      try {
        final slashParts = str.split('/');
        if (slashParts.length == 3) {
          if (slashParts[0].length == 4) {
            return DateTime.tryParse("${slashParts[0]}-${slashParts[1].padLeft(2, '0')}-${slashParts[2].padLeft(2, '0')}");
          }
          return DateTime.tryParse("${slashParts[2]}-${slashParts[1].padLeft(2, '0')}-${slashParts[0].padLeft(2, '0')}");
        }
        final dashParts = str.split('-');
        if (dashParts.length == 3) {
          if (dashParts[0].length == 4) {
            return DateTime.tryParse("${dashParts[0]}-${dashParts[1].padLeft(2, '0')}-${dashParts[2].padLeft(2, '0')}");
          }
          return DateTime.tryParse("${dashParts[2]}-${dashParts[1].padLeft(2, '0')}-${dashParts[0].padLeft(2, '0')}");
        }
      } catch (_) {}
      return null;
    }

    final pJson = json['policyJson'] is Map ? json['policyJson'] as Map<String, dynamic> : null;
    final pMeta = json['policyMetadata'] is Map ? json['policyMetadata'] as Map<String, dynamic> : null;
    final rxJson = json['prescriptionJson'] is Map ? json['prescriptionJson'] as Map<String, dynamic> : null;
    final rxMeta = json['prescriptionMetadata'] is Map ? json['prescriptionMetadata'] as Map<String, dynamic> : null;

    final polName = pJson?['policyName'] ??
        pJson?['insuranceCompany'] ??
        pMeta?['policy_name'] ??
        pMeta?['insurance_company'] ??
        json['policyName'];

    final patName = rxJson?['patientName'] ??
        rxJson?['patient'] ??
        rxMeta?['patient_name'] ??
        rxMeta?['patient'] ??
        json['patientName'];

    return AnalysisReport(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? 'Analysis Report',
      summary: json['summary'],
      content: json['content'],
      relatedFileId: json['relatedFileId'],
      relatedModel: json['relatedModel'],
      dominanceScore: (json['dominanceScore'] as num?)?.toDouble(),
      coverageBreakdown: json['coverageBreakdown'] as Map<String, dynamic>?,
      overallStatus: json['overallStatus'],
      summaryText: json['summaryText'],
      reportNumber: (json['reportNumber'] as num?)?.toInt(),
      processingTimeMs: (json['processingTimeMs'] as num?)?.toInt(),
      policyName: polName?.toString(),
      patientName: patName?.toString(),
      policyJson: pJson,
      prescriptionJson: rxJson,
      policyMetadata: pMeta,
      prescriptionMetadata: rxMeta,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'relatedFileId': relatedFileId,
      'relatedModel': relatedModel,
      'dominanceScore': dominanceScore,
      'coverageBreakdown': coverageBreakdown,
      'overallStatus': overallStatus,
      'summaryText': summaryText,
      'reportNumber': reportNumber,
      'processingTimeMs': processingTimeMs,
      'policyName': policyName,
      'patientName': patientName,
      'policyJson': policyJson,
      'prescriptionJson': prescriptionJson,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
