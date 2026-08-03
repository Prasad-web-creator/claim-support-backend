class Prescription {
  final String id;
  final String hospitalName;
  final String doctorName;
  final DateTime visitDate;
  final String? diagnosis;
  final String? gridFsFileId;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;
  final int? sequenceNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayId {
    if (sequenceNumber != null) {
      return 'PSCT${sequenceNumber.toString().padLeft(4, '0')}';
    }
    return id.substring(0, 8).toUpperCase();
  }

  Prescription({
    required this.id,
    required this.hospitalName,
    required this.doctorName,
    required this.visitDate,
    this.diagnosis,
    this.gridFsFileId,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    this.sequenceNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['_id']?.toString() ?? '',
      hospitalName: json['hospitalName'] ?? '',
      doctorName: json['doctorName'] ?? '',
      visitDate: json['visitDate'] != null ? DateTime.parse(json['visitDate']) : DateTime.now(),
      diagnosis: json['diagnosis'],
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
      'hospitalName': hospitalName,
      'doctorName': doctorName,
      'visitDate': visitDate.toIso8601String(),
      'diagnosis': diagnosis,
      'gridFsFileId': gridFsFileId,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
    };
  }
}
