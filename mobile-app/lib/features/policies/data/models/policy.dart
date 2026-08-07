class Policy {
  final String id;
  final String policyNumber;
  final String policyName;
  final String? policyHolderName;
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
    return id.isNotEmpty ? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()) : 'PCY';
  }

  Policy({
    required this.id,
    required this.policyNumber,
    required this.policyName,
    this.policyHolderName,
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
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val.isUtc ? val.toLocal() : val;
      final str = val.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null') return null;

      String parseableStr = str;
      if (str.contains('T') && !str.endsWith('Z') && !str.contains('+')) {
        parseableStr = '${str}Z';
      }

      final dt = DateTime.tryParse(parseableStr) ?? DateTime.tryParse(str);
      if (dt != null) {
        return dt.toLocal();
      }
      
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
      return null;
    }

    final meta = json['metadata'] is Map ? json['metadata'] as Map<String, dynamic> : null;
    final extractedJson = json['extractedPolicyJson'] is Map ? json['extractedPolicyJson'] as Map<String, dynamic> : null;

    final holder = json['policyHolderName'] 
        ?? meta?['policy_holder_name'] 
        ?? meta?['insured_person_name'] 
        ?? extractedJson?['policyHolderName'] 
        ?? extractedJson?['policyHolder']
        ?? extractedJson?['insuredName'];

    final pName = (json['policyName'] != null && json['policyName'].toString().isNotEmpty && json['policyName'] != 'Uploaded Policy')
        ? json['policyName']
        : (meta?['plan_name'] ?? extractedJson?['policyName'] ?? json['insuranceCompany'] ?? meta?['provider_name'] ?? json['policyName'] ?? '');

    final pNum = (json['policyNumber'] != null && json['policyNumber'].toString().isNotEmpty)
        ? json['policyNumber']
        : (meta?['policy_number'] ?? extractedJson?['policyNumber'] ?? '');

    final pStart = parseDate(json['policyStartDate'] ?? meta?['policy_start_date'] ?? extractedJson?['policyStartDate'] ?? extractedJson?['startDate']);
    final pEnd = parseDate(json['policyEndDate'] ?? meta?['policy_expiry_date'] ?? extractedJson?['policyEndDate'] ?? extractedJson?['expiryDate']);

    return Policy(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      policyNumber: pNum.toString(),
      policyName: pName.toString(),
      policyHolderName: holder?.toString(),
      insuranceCompany: json['insuranceCompany'] ?? meta?['provider_name'] ?? extractedJson?['insuranceCompany'] ?? '',
      policyType: json['policyType'] ?? meta?['policy_type'] ?? extractedJson?['policyType'],
      policyStartDate: pStart,
      policyEndDate: pEnd,
      coverageAmount: (json['coverageAmount'] as num?)?.toDouble(),
      status: json['status'] ?? 'Active',
      gridFsFileId: json['gridFsFileId'],
      originalFileName: json['originalFileName'] ?? meta?['original_file_name'],
      mimeType: json['mimeType'],
      fileSize: (json['fileSize'] as num?)?.toInt(),
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policyNumber': policyNumber,
      'policyName': policyName,
      'policyHolderName': policyHolderName,
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
