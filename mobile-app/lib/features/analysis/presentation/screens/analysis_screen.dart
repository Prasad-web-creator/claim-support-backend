import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:claimsupport/core/utils/shared_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/analysis/presentation/controllers/analysis_controller.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _hasError = false;
  String _errorMessage = '';
  int _currentStage = 0;
  late AnimationController _pulseController;

  final List<String> _stageLabels = [
    'Validating Documents',
    'Extracting PDF Text',
    'Cleaning & Normalizing',
    'Extracting Policy Data',
    'Extracting Prescription Data',
    'Validating Extracted Data',
    'Running Business Rules',
    'Coverage Analysis',
    'Generating Report',
    'Saving Results',
    'Loading Coverage Summary...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _simulateProgress();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateProgress() async {
    // Simulate stage progression for visual feedback
    for (int i = 0; i < _stageLabels.length; i++) {
      await Future.delayed(Duration(milliseconds: 1500 + (i * 600)));
      if (!mounted || _hasError) return;
      
      setState(() {
        // Stop the simulation from checking off the very last stage.
        if (i < _stageLabels.length - 1) {
          _currentStage = i + 1;
        }
      });
    }
  }

  Widget _buildContent(
    BuildContext context, 
    ThemeData theme, 
    bool isDark, 
    Color primaryBlue, 
    Color textColor, 
    Color textSecondary, 
    Color successGreen
  ) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated Shield Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryBlue.withAlpha(20),
                          primaryBlue.withAlpha(40),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _hasError
                            ? Icons.error_outline
                            : (_currentStage >= _stageLabels.length
                                ? Icons.check_circle
                                : Icons.gpp_maybe_outlined),
                        size: 56,
                        color: _hasError ? Colors.red : primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  _hasError
                      ? 'Analysis Failed'
                      : (_currentStage >= _stageLabels.length
                          ? 'Analysis Complete!'
                          : 'Analyzing...'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _hasError ? Colors.red.shade700 : textColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  _hasError
                      ? 'Something went wrong during the analysis.'
                      : 'Our system is reading your documents and cross-referencing coverage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Pipeline Progress
                if (!_hasError)
                  Container(
                    padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF374151) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                    child: Column(
                      children: List.generate(_stageLabels.length, (index) {
                        final isCompleted = index < _currentStage;
                        final isActive = index == _currentStage;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _stageLabels.length - 1 ? 12 : 0,
                          ),
                          child: Row(
                            children: [
                              // Status icon
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: isCompleted
                                    ? Icon(Icons.check_circle,
                                        color: successGreen, size: 22)
                                    : isActive
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: primaryBlue,
                                            ),
                                          )
                                        : Icon(Icons.circle_outlined,
                                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                                            size: 22),
                              ),
                              const SizedBox(width: 14),
                              // Label
                              Expanded(
                                child: Text(
                                  _stageLabels[index],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCompleted
                                        ? successGreen
                                        : isActive
                                            ? textColor
                                            : textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                // Error Display
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withAlpha(50) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.red.shade900 : Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                              _currentStage = 0;
                            });
                            _simulateProgress();
                            final prefs = SharedPrefs.instance;
                            final prescriptionPath = prefs.getString('prescription_path');
                            final policyPath = prefs.getString('policy_path');
                            if (prescriptionPath != null && policyPath != null) {
                               ref.invalidate(analysisJobProvider(AnalysisParams(prescriptionPath, policyPath)));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF374151) : Colors.white,
                            foregroundColor: isDark ? Colors.white : const Color(0xFF374151),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Retry Analysis'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/dashboard'),
                          child: Text('Return to Dashboard',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ],
                    ),
                  ),
                ] else if (_currentStage < _stageLabels.length) ...[
                   const SizedBox(height: 48),
                   Text(
                     'Please keep this screen open',
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.w600,
                       color: textSecondary,
                     ),
                   ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final Color successGreen = const Color(0xFF059669);

    final prefs = SharedPrefs.instance;
    final prescriptionPath = prefs.getString('prescription_path');
    final policyPath = prefs.getString('policy_path');

    if (prescriptionPath == null || policyPath == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Missing uploaded files."),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text("Return to Dashboard"),
              )
            ],
          ),
        ),
      );
    }

    final params = AnalysisParams(prescriptionPath, policyPath);
    final analysisState = ref.watch(analysisJobProvider(params));

    // Handle state mapping outside of build return
    analysisState.whenData((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted && _currentStage < _stageLabels.length) {
            setState(() {
              _currentStage = _stageLabels.length;
            });
            prefs.setString('analysis_result', jsonEncode(data));
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) context.pushReplacement('/summary');
            });
         }
      });
    });

    // Handle error state
    if (analysisState.hasError && !_hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           setState(() {
             _hasError = true;
             _errorMessage = analysisState.error.toString();
           });
        }
      });
    } else if (!analysisState.hasError && _hasError) {
      // If error was cleared via invalidate
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           setState(() {
             _hasError = false;
             _errorMessage = '';
           });
        }
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _buildContent(context, theme, isDark, primaryBlue, textColor, textSecondary, successGreen),
    );
  }
}
