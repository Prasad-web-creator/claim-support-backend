import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:claimsupport/core/utils/device_app_info.dart';

class UploadPolicyScreen extends StatefulWidget {
  const UploadPolicyScreen({super.key});

  @override
  State<UploadPolicyScreen> createState() => _UploadPolicyScreenState();
}

/// One policy the user has uploaded in this session, with its own start date.
///
/// Policies are independent documents, so each keeps its own record id and
/// date rather than sharing one screen-wide value.
class _UploadedPolicy {
  _UploadedPolicy({
    required this.fileName,
    required this.fileId,
    required this.policyId,
  });

  final String fileName;
  final String fileId;
  final String policyId;
  DateTime? startDate;
}

class _UploadPolicyScreenState extends State<UploadPolicyScreen> {
  /// Matches the server's MAX_POLICIES_PER_ANALYSIS limit.
  static const int _maxPolicies = 5;

  final List<_UploadedPolicy> _policies = [];
  bool _isUploading = false;

  Future<void> _pickStartDate(_UploadedPolicy policy) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = (policy.startDate != null && !policy.startDate!.isAfter(today))
        ? policy.startDate!
        : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: today,
      helpText: 'Start date for ${policy.fileName}',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1F2937) : Colors.white,
              onSurface: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() => policy.startDate = picked);

    try {
      await ApiClient().dio.put('/policies/${policy.policyId}', data: {
        'policyStartDate': picked.toIso8601String(),
      });
    } catch (e) {
      debugPrint("Failed to update policy start date: $e");
    }
  }

  /// Upload one or more policy documents. Each file becomes its own policy
  /// record, so the prescription can be compared against all of them.
  Future<void> _pickAndUploadFiles() async {
    final remaining = _maxPolicies - _policies.length;
    if (remaining <= 0) {
      _toast('You can compare up to $_maxPolicies policies at once.');
      return;
    }

    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      allowMultiple: true,
    );

    final picked = result?.files.where((f) => f.path != null).toList() ?? [];
    if (picked.isEmpty) return;

    var files = picked;
    if (files.length > remaining) {
      files = files.sublist(0, remaining);
      _toast('Only the first $remaining added — you can compare up to $_maxPolicies policies.');
    }

    setState(() => _isUploading = true);
    try {
      for (final file in files) {
        await _uploadOne(file);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Upload a single file and create its policy record. A failure on one file
  /// leaves the policies already added untouched.
  Future<void> _uploadOne(PlatformFile file) async {
    String? fileId;
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!),
      });

      final response = await ApiClient().dio.post('/upload', data: formData);
      if (response.statusCode != 200) {
        _toast('Could not upload ${file.name}.');
        return;
      }

      fileId = response.data['fileId'].toString();
      final isImageBased = response.data['isImageBased'] == true ||
          file.name.toLowerCase().endsWith('.jpg') ||
          file.name.toLowerCase().endsWith('.jpeg') ||
          file.name.toLowerCase().endsWith('.png');

      final agreementData = await DeviceAppInfo.buildAgreementData();
      final policyResponse = await ApiClient().dio.post('/policies', data: {
        'insuranceCompany': '',
        'policyNumber': '',
        'policyName': 'Uploaded Policy',
        'gridFsFileId': fileId,
        'originalFileName': file.name,
        'agreement': agreementData,
      });

      final newPolicyId =
          (policyResponse.data['_id'] ?? policyResponse.data['id']).toString();

      await SharedPrefs.instance.setBool('policy_is_image_based', isImageBased);

      if (!mounted) return;
      setState(() {
        _policies.add(_UploadedPolicy(
          fileName: file.name,
          fileId: fileId!,
          policyId: newPolicyId,
        ));
      });
    } on DioException catch (e) {
      await _rollbackUpload(fileId);
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      _toast(offline
          ? 'Unable to connect to the server. Please check your internet connection and try again.'
          : 'Our servers could not process ${file.name}. Please try again later.');
    } catch (e) {
      debugPrint("Failed to save policy record: $e");
      await _rollbackUpload(fileId);
      _toast('Could not add ${file.name}. Please try again.');
    }
  }

  Future<void> _rollbackUpload(String? fileId) async {
    if (fileId == null) return;
    try {
      await ApiClient().dio.delete('/upload/$fileId');
    } catch (deleteError) {
      debugPrint("Failed to rollback uploaded file: $deleteError");
    }
  }

  Future<void> _removePolicy(_UploadedPolicy policy) async {
    setState(() => _policies.remove(policy));
    try {
      await ApiClient().dio.delete('/policies/${policy.policyId}');
    } catch (e) {
      debugPrint("Failed to delete removed policy: $e");
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _analyzeDocuments() async {
    if (_policies.isEmpty) {
      _toast('Please upload at least one policy document.');
      return;
    }

    final missingDate = _policies.where((p) => p.startDate == null).toList();
    if (missingDate.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missingDate.length == 1
              ? 'Please select the start date for ${missingDate.first.fileName}.'
              : 'Please select a start date for each policy.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Make sure the dates the user picked are stored before the analysis reads them.
    for (final policy in _policies) {
      try {
        await ApiClient().dio.put('/policies/${policy.policyId}', data: {
          'policyStartDate': policy.startDate!.toIso8601String(),
        });
      } catch (e) {
        debugPrint("Failed to sync policy start date before analysis: $e");
      }
    }

    final prefs = SharedPrefs.instance;
    await prefs.remove('policy_path');

    // One policy keeps the original single-analysis flow; several go to the
    // comparison screen, exactly as selecting saved policies does.
    if (_policies.length == 1) {
      await prefs.setString('policy_id', _policies.first.policyId);
      await prefs.remove('policy_ids');
      if (mounted) context.push('/analysis');
    } else {
      await prefs.setString(
        'policy_ids',
        jsonEncode(_policies.map((p) => p.policyId).toList()),
      );
      await prefs.remove('policy_id');
      if (mounted) context.push('/analysis-multi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back, color: textColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Upload Policy',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Progress Bars (Step 3 of 3)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Description
              Text(
                "Step 3: Upload one or more insurance policy documents. Add several to compare them against the same prescription.",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Uploaded policies — each one keeps its own start date, because
              // the waiting-period checks are per policy.
              if (_policies.isNotEmpty) ...[
                Text(
                  _policies.length == 1
                      ? "1 policy added"
                      : "${_policies.length} policies added",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ..._policies.map((policy) => _buildPolicyTile(
                      policy: policy,
                      isDark: isDark,
                      textColor: textColor,
                      textSecondary: textSecondary,
                      primaryBlue: primaryBlue,
                    )),
                const SizedBox(height: 12),
              ],

              // Upload Area with Dashed Border
              GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadFiles,
                child: CustomPaint(
                  painter: DashedBorderPainter(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    strokeWidth: 2,
                    gap: 6,
                    radius: 24,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0E7FF),
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading
                              ? const CircularProgressIndicator()
                              : const Icon(
                                  Icons.note_add_outlined,
                                  size: 32,
                                  color: Color(0xFF4338CA),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _policies.isEmpty
                              ? 'Tap to upload PDF or Image'
                              : 'Tap to add another policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can select several files at once · up to $_maxPolicies policies · max 10MB each',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Analyze Documents Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _analyzeDocuments, // Finalize and go to analysis loading/results
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _policies.length > 1
                            ? 'Compare ${_policies.length} Policies'
                            : 'Analyze Documents',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.show_chart, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One uploaded policy: its file name, its own start date and a way to drop it.
  Widget _buildPolicyTile({
    required _UploadedPolicy policy,
    required bool isDark,
    required Color textColor,
    required Color textSecondary,
    required Color primaryBlue,
  }) {
    final hasDate = policy.startDate != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDate
              ? primaryBlue
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          width: hasDate ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  policy.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removePolicy(policy),
                icon: const Icon(Icons.close, size: 18),
                color: textSecondary,
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Required per policy: waiting periods are judged against this date.
          GestureDetector(
            onTap: () => _pickStartDate(policy),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: primaryBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasDate
                          ? 'Start date: ${DateFormat('dd-MM-yyyy').format(policy.startDate!)}'
                          : 'Select policy start date *',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                        color: hasDate ? textColor : Colors.red.shade400,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Dashed Border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));

    final Path dashedPath = Path();
    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        final double len = gap; // length of dash
        dashedPath.addPath(measurePath.extractPath(distance, distance + len), Offset.zero);
        distance += len + gap; // jump by length + gap
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
