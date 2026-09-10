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

class _UploadPolicyScreenState extends State<UploadPolicyScreen> {
  String? _selectedFileName;
  String? _uploadedPath;
  String? _policyId;
  DateTime? _selectedPolicyStartDate;
  bool _isUploading = false;

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = (_selectedPolicyStartDate != null && !_selectedPolicyStartDate!.isAfter(today))
        ? _selectedPolicyStartDate!
        : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: today,
      helpText: 'Select Policy Start Date',
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

    if (picked != null) {
      setState(() {
        _selectedPolicyStartDate = picked;
      });

      final prefs = SharedPrefs.instance;
      await prefs.setString('user_policy_start_date', picked.toIso8601String());

      // If policy record already exists in DB, update it
      if (_policyId != null) {
        try {
          await ApiClient().dio.put('/policies/$_policyId', data: {
            'policyStartDate': picked.toIso8601String(),
          });
        } catch (e) {
          debugPrint("Failed to update policy start date: $e");
        }
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFileName = result.files.single.name;
        _isUploading = true;
      });

      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(result.files.single.path!),
        });

        final response = await ApiClient().dio.post('/upload', data: formData);
        
        if (response.statusCode == 200) {
          _uploadedPath = response.data['fileId'].toString();
          final isImageBased = response.data['isImageBased'] == true ||
              _selectedFileName?.toLowerCase().endsWith('.jpg') == true ||
              _selectedFileName?.toLowerCase().endsWith('.jpeg') == true ||
              _selectedFileName?.toLowerCase().endsWith('.png') == true;
          final prefs = SharedPrefs.instance;
          await prefs.setString('policy_path', _uploadedPath!);
          await prefs.setBool('policy_is_image_based', isImageBased);
          await prefs.remove('policy_id'); // Ensure old policy_id is cleared
          
          try {
            final agreementData = await DeviceAppInfo.buildAgreementData();
            final policyResponse = await ApiClient().dio.post('/policies', data: {
              'insuranceCompany': '',
              'policyNumber': '',
              'policyName': 'Uploaded Policy',
              'gridFsFileId': _uploadedPath,
              'originalFileName': _selectedFileName,
              'policyStartDate': _selectedPolicyStartDate?.toIso8601String(),
              'agreement': agreementData,
            });
            
            final newPolicyId = policyResponse.data['_id'] ?? policyResponse.data['id'];
            _policyId = newPolicyId.toString();
            await prefs.setString('policy_id', _policyId!);
            await prefs.remove('policy_path');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful')));
            }
          } catch (e) {
            debugPrint("Failed to save policy record: $e");
            try {
              await ApiClient().dio.delete('/upload/$_uploadedPath');
            } catch (deleteError) {
              debugPrint("Failed to rollback uploaded file: $deleteError");
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save policy record. Please try again.')));
              setState(() {
                _isUploading = false;
                _uploadedPath = null;
              });
            }
            return;
          }
        }
      } on DioException catch (e) {
        if (mounted) {
          String msg;
          if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            msg = "Unable to connect to the server. Please check your internet connection and try again.";
          } else {
            msg = "Our servers are experiencing issues processing your upload. Please try again later.";
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred during upload. Please try again later.')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _analyzeDocuments() async {
    if (_selectedPolicyStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the policy start date before analyzing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_uploadedPath == null && _policyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a file first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure policy record has latest start date if already uploaded
    if (_policyId != null && _selectedPolicyStartDate != null) {
      try {
        await ApiClient().dio.put('/policies/$_policyId', data: {
          'policyStartDate': _selectedPolicyStartDate!.toIso8601String(),
        });
      } catch (e) {
        debugPrint("Failed to sync policy start date before analysis: $e");
      }
    }

    if (mounted) {
      context.push('/analysis');
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
                "Step 3: Upload your current insurance policy document for System extraction.",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Policy Start Date Input (Required)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Policy Start Date",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "*",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPolicyStartDate != null
                              ? primaryBlue
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          width: _selectedPolicyStartDate != null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryBlue.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedPolicyStartDate != null
                                  ? DateFormat('dd-MM-yyyy').format(_selectedPolicyStartDate!)
                                  : 'Select Policy Start Date (DD-MM-YYYY)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _selectedPolicyStartDate != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedPolicyStartDate != null
                                    ? textColor
                                    : textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Upload Area with Dashed Border
              GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadFile,
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
                          _selectedFileName ?? 'Tap to upload PDF or Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFileName == null ? 'Max file size: 10MB' : 'File uploaded successfully',
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
                    children: const [
                      Text(
                        'Analyze Documents',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.show_chart, size: 20),
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
