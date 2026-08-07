class Prescription {
  final String id;
  final String hospitalName;
  final String doctorName;
  final String? patientName;
  final String? prescriptionNumber;
  final DateTime? visitDate;
  final String? diagnosis;
  final String? gridFsFileId;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;
  final int? sequenceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool isManual;
  final String? manualText;
  final String? prescriptionSource;
  final String? extractedPrescriptionText;

  String get displayId {
    if (sequenceNumber != null) {
      return 'PSCT${sequenceNumber.toString().padLeft(4, '0')}';
    }
    return id.isNotEmpty ? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()) : 'PSCT';
  }

  Prescription({
    required this.id,
    required this.hospitalName,
    required this.doctorName,
    this.patientName,
    this.prescriptionNumber,
    this.visitDate,
    this.diagnosis,
    this.gridFsFileId,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    this.sequenceNumber,
    this.createdAt,
    this.updatedAt,
    this.isManual = false,
    this.manualText,
    this.prescriptionSource,
    this.extractedPrescriptionText,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
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
    final extractedJson = json['extractedPrescriptionJson'] is Map ? json['extractedPrescriptionJson'] as Map<String, dynamic> : null;

    final pName = json['patientName'] 
        ?? meta?['patient_name'] 
        ?? meta?['patient'] 
        ?? extractedJson?['patientName'] 
        ?? extractedJson?['patient'];

    final pNumber = json['prescriptionNumber'] 
        ?? meta?['prescription_number'] 
        ?? meta?['prescription_no'] 
        ?? meta?['bill_number'] 
        ?? meta?['invoice_number'] 
        ?? extractedJson?['prescriptionNumber'];

    final hName = (json['hospitalName'] != null && json['hospitalName'].toString().isNotEmpty)
        ? json['hospitalName']
        : (meta?['hospital_name'] ?? meta?['clinic_name'] ?? extractedJson?['hospital'] ?? extractedJson?['hospitalName'] ?? '');

    final docName = (json['doctorName'] != null && json['doctorName'].toString().isNotEmpty)
        ? json['doctorName']
        : (meta?['doctor_name'] ?? extractedJson?['doctor'] ?? extractedJson?['doctorName'] ?? '');

    final vDate = parseDate(json['visitDate'] ?? meta?['hospital_visit_date'] ?? meta?['consultation_date'] ?? meta?['visit_date'] ?? meta?['admission_date'] ?? extractedJson?['visitDate'] ?? extractedJson?['consultationDate']);

    final manualContent = json['manualText'] 
        ?? json['extractedPrescriptionText'] 
        ?? meta?['manual_text'] 
        ?? meta?['prescription_text']
        ?? extractedJson?['manualText'];

    final isMan = json['isManual'] == true ||
        json['prescriptionSource'] == 'Self-entered Prescription' ||
        (manualContent != null && manualContent.toString().trim().isNotEmpty);

    return Prescription(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      hospitalName: hName.toString(),
      doctorName: docName.toString(),
      patientName: pName?.toString(),
      prescriptionNumber: pNumber?.toString(),
      visitDate: vDate,
      diagnosis: json['diagnosis'] ?? meta?['diagnosis']?.toString() ?? extractedJson?['diagnosis']?.toString(),
      gridFsFileId: json['gridFsFileId'],
      originalFileName: json['originalFileName'] ?? meta?['original_file_name'],
      mimeType: json['mimeType'],
      fileSize: (json['fileSize'] as num?)?.toInt(),
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      isManual: isMan,
      manualText: manualContent?.toString(),
      prescriptionSource: json['prescriptionSource']?.toString() ?? (isMan ? 'Self-entered Prescription' : 'PDF Upload'),
      extractedPrescriptionText: json['extractedPrescriptionText']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hospitalName': hospitalName,
      'doctorName': doctorName,
      'patientName': patientName,
      'prescriptionNumber': prescriptionNumber,
      'visitDate': visitDate?.toIso8601String(),
      'diagnosis': diagnosis,
      'gridFsFileId': gridFsFileId,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'isManual': isManual,
      'manualText': manualText,
      'prescriptionSource': prescriptionSource,
    };
  }
}
