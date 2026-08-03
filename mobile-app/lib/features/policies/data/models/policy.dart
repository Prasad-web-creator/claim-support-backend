class Policy {
  final String id;
  final String policyNumber;
  final String policyName;
  final String insuranceCompany;
  final String? policyType;
  final DateTime? policyStartDate;
  final DateTime? policyEndDate;
  final double? coverageAmount;
  final String status;
  final String? gridFsFileId;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;
  final int? sequenceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayId {
    if (sequenceNumber != null) {
      return 'PCY${sequenceNumber.toString().padLeft(4, '0')}';
    }
    return id.substring(0, 8).toUpperCase();
  }

  Policy({
    required this.id,
    required this.policyNumber,
    required this.policyName,
    required this.insuranceCompany,
    this.policyType,
    this.policyStartDate,
    this.policyEndDate,
    this.coverageAmount,
    required this.status,
    this.gridFsFileId,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    this.sequenceNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['_id']?.toString() ?? '',
      policyNumber: json['policyNumber'] ?? '',
      policyName: json['policyName'] ?? '',
      insuranceCompany: json['insuranceCompany'] ?? '',
      policyType: json['policyType'],
      policyStartDate: json['policyStartDate'] != null ? DateTime.parse(json['policyStartDate']) : null,
      policyEndDate: json['policyEndDate'] != null ? DateTime.parse(json['policyEndDate']) : null,
      coverageAmount: json['coverageAmount']?.toDouble(),
      status: json['status'] ?? 'Active',
      gridFsFileId: json['gridFsFileId'],
      originalFileName: json['originalFileName'],
      mimeType: json['mimeType'],
      fileSize: (json['fileSize'] as num?)?.toInt(),
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policyNumber': policyNumber,
      'policyName': policyName,
      'insuranceCompany': insuranceCompany,
      'policyType': policyType,
      'policyStartDate': policyStartDate?.toIso8601String(),
      'policyEndDate': policyEndDate?.toIso8601String(),
      'coverageAmount': coverageAmount,
      'status': status,
      'gridFsFileId': gridFsFileId,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
    };
  }
}
