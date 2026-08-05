import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';

class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  ConsumerState<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends ConsumerState<UploadPrescriptionScreen> {
  String? _selectedFileName;
  String? _uploadedPath;
  bool _isUploading = false;
  bool _isExtracting = false;

  String? _formatDisplayDate(dynamic dateVal) {
    if (dateVal == null) return null;
    final str = dateVal.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;

    try {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        return DateFormat('dd-MM-yyyy').format(parsed);
      }
      
      final slashParts = str.split('/');
      if (slashParts.length == 3) {
        if (slashParts[0].length == 4) {
          return "${slashParts[2].padLeft(2, '0')}-${slashParts[1].padLeft(2, '0')}-${slashParts[0]}";
        }
        return "${slashParts[0].padLeft(2, '0')}-${slashParts[1].padLeft(2, '0')}-${slashParts[2]}";
      }

      final dashParts = str.split('-');
      if (dashParts.length == 3) {
        if (dashParts[0].length == 4) {
          return "${dashParts[2].padLeft(2, '0')}-${dashParts[1].padLeft(2, '0')}-${dashParts[0]}";
        }
        return "${dashParts[0].padLeft(2, '0')}-${dashParts[1].padLeft(2, '0')}-${dashParts[2]}";
      }
    } catch (_) {}

    return str;
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
          final prefs = SharedPrefs.instance;
          await prefs.setString('prescription_path', _uploadedPath!);
          
          try {
            await ApiClient().dio.post('/prescriptions', data: {
              'hospitalName': '',
              'gridFsFileId': _uploadedPath,
              'originalFileName': _selectedFileName,
              'agreement': {
                'termsAccepted': true,
                'termsVersion': '1.0',
                'appVersion': '1.0.0',
                'platform': 'Android',
              }
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful')));
            }
          } catch (e) {
            debugPrint("Failed to save prescription record: $e");
            try {
              await ApiClient().dio.delete('/upload/$_uploadedPath');
            } catch (deleteError) {
              debugPrint("Failed to rollback uploaded file: $deleteError");
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save prescription record. Please try again.')));
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

  Future<void> _processNext() async {
    if (_uploadedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a file first.')));
      return;
    }

    if (_isExtracting) return;

    setState(() {
      _isExtracting = true;
    });

    List<dynamic> policiesList = [];
    bool hasPolicies = false;
    
    try {
      final response = await ApiClient().dio.get('/policies/summary');
      if (response.statusCode == 200 && response.data['success'] == true) {
        policiesList = response.data['policies'];
        hasPolicies = policiesList.isNotEmpty;
      }
    } catch (e) {
      debugPrint("Failed to fetch policies: $e");
    }

    if (!mounted) return;

    setState(() {
      _isExtracting = false;
    });

    if (!hasPolicies) {
      context.push('/upload-policy');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text("Existing Policy Found", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            "We found existing policies in your account. Would you like to analyze this prescription using one of your saved policies?",
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/upload-policy');
              },
              child: Text(
                "Upload New Policy",
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showPolicySelectionDialog(policiesList);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Continue Existing Policy"),
            ),
          ],
        );
      },
    );
  }

  void _showPolicySelectionDialog(List<dynamic> policies) {
    String? localSelectedPolicyId;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Select Policy", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: policies.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = policies[index];
                    final isSelected = localSelectedPolicyId == p['id'];
                    
                    final String provider = p['providerName'] ?? 'Insurance Policy';
                    final String policyType = p['policyType'] ?? '';
                    final String? holderName = p['policyHolderName'];
                    final String? formattedStart = _formatDisplayDate(p['startDate']);
                    final String? formattedEnd = _formatDisplayDate(p['endDate'] ?? p['expiryDate']);
                    final String policyNo = p['displayId'] ?? p['policyNumber'] ?? 'Unknown';
                    final String? fileName = p['originalFileName'];

                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          localSelectedPolicyId = p['id'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0x4D1E3A8A) : const Color(0xFFEFF6FF))
                              : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    policyType.isNotEmpty ? "$provider - $policyType" : provider,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (holderName != null && holderName.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "Holder: $holderName",
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  Row(
                                    children: [
                                      Icon(Icons.tag, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        "No: $policyNo",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  if (formattedStart != null && formattedEnd != null) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Validity: $formattedStart to $formattedEnd",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                  ] else if (formattedStart != null) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Start Date: $formattedStart",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                  ] else if (formattedEnd != null) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.event_busy_outlined, size: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Expiry: $formattedEnd",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  if (fileName != null && fileName.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(Icons.description_outlined, size: 13, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "File: $fileName",
                                            style: TextStyle(
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: isSelected
                                  ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 22)
                                  : Icon(Icons.circle_outlined, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 22),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
                ),
                ElevatedButton(
                  onPressed: localSelectedPolicyId == null ? null : () async {
                    Navigator.of(dialogContext).pop();
                    final prefs = SharedPrefs.instance;
                    await prefs.setString('policy_id', localSelectedPolicyId!);
                    await prefs.remove('policy_path'); // Ensure policy_path is cleared
                    if (mounted) context.push('/analysis');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Analyze With Selected Policy"),
                ),
              ],
            );
          }
        );
      }
    );
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
                    'Add Prescription',
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
              
              // Progress Bars (Step 2 of 3)
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
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Description
              Text(
                "Step 2: Upload your doctor's prescription, diagnosis, or medical bills.",
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
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
                            color: Color(0xFFE0E7FF), // light blue bg for icon
                            shape: BoxShape.circle,
                          ),
                          child: _isUploading 
                              ? const CircularProgressIndicator()
                              : const Icon(
                                  Icons.find_in_page_outlined, // magnifying glass on doc
                                  size: 32,
                                  color: Color(0xFF4338CA), // indigo darker blue
                                ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _selectedFileName ?? 'Tap to upload Medical Docs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFileName == null ? 'Supports handwriting via OCR' : 'File uploaded successfully',
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
              
              // Process Button
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
                  onPressed: (_isUploading || _isExtracting) ? null : _processNext, // Go to next step

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
                      if (_isExtracting) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Extracting...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Process Prescription',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
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
