import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Colors, Text, debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Professional, insurance-grade Coverage Report PDF Generator.
/// Generates printable, multi-page vector PDF documents entirely client-side.
class CoverageReportPdfService {
  // ─── Color Palette (Tailored for Crisp Printing) ───────────────────────────
  static final PdfColor _primaryNavy = PdfColor.fromHex('#1E3A8A'); // Primary Brand Blue
  static final PdfColor _accentSlate = PdfColor.fromHex('#475569');
  static final PdfColor _darkText = PdfColor.fromHex('#0F172A');
  static final PdfColor _mutedText = PdfColor.fromHex('#64748B');
  static final PdfColor _lightBg = PdfColor.fromHex('#F8FAFC');
  static final PdfColor _cardBg = PdfColor.fromHex('#FFFFFF');
  static final PdfColor _borderColor = PdfColor.fromHex('#E2E8F0');
  static final PdfColor _dividerColor = PdfColor.fromHex('#F1F5F9');

  // Status Colors
  static final PdfColor _successGreen = PdfColor.fromHex('#059669');
  static final PdfColor _successGreenLight = PdfColor.fromHex('#ECFDF5');
  static final PdfColor _successGreenBorder = PdfColor.fromHex('#A7F3D0');

  static final PdfColor _warningAmber = PdfColor.fromHex('#D97706');
  static final PdfColor _warningAmberLight = PdfColor.fromHex('#FFFBEB');
  static final PdfColor _warningAmberBorder = PdfColor.fromHex('#FDE68A');

  static final PdfColor _dangerRed = PdfColor.fromHex('#DC2626');
  static final PdfColor _dangerRedLight = PdfColor.fromHex('#FEF2F2');
  static final PdfColor _dangerRedBorder = PdfColor.fromHex('#FECACA');

  /// Main entry point to generate and share/print the Coverage Report PDF.
  static Future<void> generateAndSharePdf(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final pdfBytes = await generatePdfBytes(data);
      final filename = _generateFilename(data);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: filename,
      );
    } catch (e, stackTrace) {
      debugPrint('[CoverageReportPdfService] PDF Generation failed: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate Coverage Report. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Builds the complete PDF document and returns the raw bytes.
  static Future<Uint8List> generatePdfBytes(Map<String, dynamic> data) async {
    final pdf = pw.Document(
      title: 'Coverage Report',
      author: 'Claim Support',
      subject: 'Health Insurance Coverage Analysis Report',
      creator: 'Claim Support',
      keywords: 'Coverage, Insurance, Health, Claim, Policy, Prescription',
    );

    // Extract Data Safely
    final policyJson = data['policyJson'] as Map<String, dynamic>? ?? {};
    final prescriptionJson = data['prescriptionJson'] as Map<String, dynamic>? ?? {};
    final coverageBreakdown = data['coverageBreakdown'] as Map<String, dynamic>? ?? {};
    final comparison = data['comparison'] as List<dynamic>? ?? [];
    final coverageAnalysis = data['coverageAnalysis'] as Map<String, dynamic>? ?? {};
    final clarificationQA = data['clarificationAnswersUsed'] as List<dynamic>? ?? [];

    final overallStatus = (data['overallStatus'] ?? 'Unknown').toString();
    final dominanceScore = data['dominanceScore'] ?? 0;
    final dynamic coverageScore = data['coverageScore'];
    final summaryText = (data['summaryText'] ?? data['summary'] ?? 'Coverage analysis evaluation completed.').toString();
    final processingTimeMs = data['processingTimeMs'] ?? 0;
    final reportNumber = data['reportNumber'];
    final reportId = (data['reportId'] ?? data['_id'] ?? data['id'] ?? '').toString();
    final analysisVersion = (data['analysisVersion'] ?? '2.0.0').toString();

    final generatedDateTime = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    final generatedDateOnly = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    // Compute breakdown counts
    final int coveredCount = (coverageBreakdown['covered'] as num?)?.toInt() ?? 0;
    final int partialCount = (coverageBreakdown['partiallyCovered'] as num?)?.toInt() ?? 0;
    final int notCoveredCount = (coverageBreakdown['notCovered'] as num?)?.toInt() ?? 0;
    final int totalCount = (coverageBreakdown['total'] as num?)?.toInt() ?? (coveredCount + partialCount + notCoveredCount);

    // Recommendations extraction
    String? recommendationsText;
    if (coverageAnalysis['recommendation'] != null && coverageAnalysis['recommendation'].toString().trim().isNotEmpty) {
      recommendationsText = coverageAnalysis['recommendation'].toString().trim();
      if (coverageAnalysis['nextSteps'] is List && (coverageAnalysis['nextSteps'] as List).isNotEmpty) {
        final steps = (coverageAnalysis['nextSteps'] as List).map((s) => s.toString().trim()).join(' ');
        recommendationsText = '$recommendationsText $steps';
      }
    } else if (data['recommendations'] != null && data['recommendations'].toString().trim().isNotEmpty) {
      recommendationsText = data['recommendations'].toString().trim();
    }

    // Build the Multi-Page Document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        header: (pw.Context context) {
          // Compact header on subsequent pages
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Coverage Report | Claim Support',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _mutedText,
                    ),
                  ),
                  pw.Text(
                    'Report ID: ${reportId.isNotEmpty ? (reportId.length > 12 ? reportId.substring(0, 12) : reportId) : 'N/A'}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _mutedText,
                    ),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Claim Support | Coverage Report',
                  style: pw.TextStyle(fontSize: 8.5, color: _mutedText),
                ),
                pw.Text(
                  'Generated on: $generatedDateOnly',
                  style: pw.TextStyle(fontSize: 8.5, color: _mutedText),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _mutedText),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // ─── 1. Cover Header Card ───
            _buildCoverHeader(
              generatedDateTime: generatedDateTime,
              reportNumber: reportNumber,
              reportId: reportId,
              analysisVersion: analysisVersion,
              processingTimeMs: processingTimeMs,
            ),
            pw.SizedBox(height: 14),

            // ─── 2. Executive Summary ───
            ..._buildExecutiveSummary(
              overallStatus: overallStatus,
              dominanceScore: dominanceScore,
              coverageScore: coverageScore,
              summaryText: summaryText,
              coveredCount: coveredCount,
              partialCount: partialCount,
              notCoveredCount: notCoveredCount,
              totalCount: totalCount,
            ),
            pw.SizedBox(height: 14),

            // ─── 3. Document Information Cards (Policy & Prescription) ───
            _buildDocumentInfoSection(
              policyJson: policyJson,
              prescriptionJson: prescriptionJson,
            ),
            pw.SizedBox(height: 14),

            // ─── 4. Coverage Distribution Donut Chart & Statistics ───
            if (totalCount > 0) ...[
              ..._buildChartAndStatisticsSection(
                coveredCount: coveredCount,
                partialCount: partialCount,
                notCoveredCount: notCoveredCount,
                totalCount: totalCount,
              ),
              pw.SizedBox(height: 14),
            ],

            // ─── 5. Policy & Prescription Detailed Specifications ───
            ..._buildDetailedSpecsSection(
              policyJson: policyJson,
              prescriptionJson: prescriptionJson,
            ),
            pw.SizedBox(height: 14),

            // ─── 6. Clarification Q&A Section ───
            if (clarificationQA.isNotEmpty) ...[
              _buildClarificationQASection(clarificationQA),
              pw.SizedBox(height: 14),
            ],

            // ─── 7. Coverage Comparison Table ───
            if (comparison.isNotEmpty) ...[
              _buildComparisonTableSection(comparison),
              pw.SizedBox(height: 14),
            ],

            // ─── 8. Coverage Decision Details (Card-Based Layout) ───
            if (comparison.isNotEmpty) ...[
              ..._buildDecisionDetailsSection(comparison),
              pw.SizedBox(height: 14),
            ],

            // ─── 9. Recommendations Section ───
            if (recommendationsText != null && recommendationsText.isNotEmpty) ...[
              _buildRecommendationsSection(recommendationsText),
              pw.SizedBox(height: 14),
            ],

            // ─── 10. Important Notes Box ───
            _buildImportantNotesBox(),
            pw.SizedBox(height: 12),

            // ─── 11. Professional Disclaimer ───
            _buildDisclaimerBox(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ─── Section Builders ──────────────────────────────────────────────────────

  /// Clarification Q&A section — shows LLM questions and user answers used in analysis.
  static pw.Widget _buildClarificationQASection(List<dynamic> qaList) {
    final cyColor = PdfColor.fromHex('#0891B2');
    final cyLight = PdfColor.fromHex('#ECFEFF');
    final cyBorder = PdfColor.fromHex('#A5F3FC');

    final items = <pw.Widget>[];
    for (int i = 0; i < qaList.length; i++) {
      final qa = qaList[i] as Map<String, dynamic>? ?? {};
      final title = (qa['Title'] ?? qa['title'] ?? '').toString().trim();
      final question = (qa['Question'] ?? qa['question'] ?? '').toString().trim();
      final answer = (qa['User_Answer'] ?? qa['userAnswer'] ?? qa['answer'] ?? '').toString().trim();
      if (title.isEmpty && question.isEmpty) continue;

      items.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: cyLight,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: cyBorder, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Number badge
              pw.Container(
                width: 20,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: cyColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '${i + 1}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: cyColor,
                        ),
                      ),
                    if (question.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        question,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          color: _darkText,
                          lineSpacing: 1.3,
                        ),
                      ),
                    ],
                    if (answer.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _cardBg,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: _borderColor, width: 0.6),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'Answer: ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: _mutedText,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                answer,
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: cyColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'CLARIFICATION Q&A',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                '${items.length} ${items.length == 1 ? 'Question' : 'Questions'}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: const PdfColor(1, 1, 1, 0.7),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        ...items,
      ],
    );
  }

  /// Header Card with Branding, Title, Report Number, and Timestamps.
  static pw.Widget _buildCoverHeader({
    required String generatedDateTime,
    required dynamic reportNumber,
    required String reportId,
    required String analysisVersion,
    required dynamic processingTimeMs,
  }) {
    final reportCode = reportNumber != null
        ? 'CR-${reportNumber.toString().padLeft(4, '0')}'
        : (reportId.isNotEmpty ? 'CR-${reportId.length > 8 ? reportId.substring(0, 8).toUpperCase() : reportId.toUpperCase()}' : 'CR-0001');

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Claim Support',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Coverage Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Health Insurance Claim Analysis',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _mutedText,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  reportCode,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Generated: $generatedDateTime',
                style: pw.TextStyle(fontSize: 8.5, color: _mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Executive Summary Card with Big Status, Dominance Score, and Stat Boxes.
  static List<pw.Widget> _buildExecutiveSummary({
    required String overallStatus,
    required dynamic dominanceScore,
    required dynamic coverageScore,
    required String summaryText,
    required int coveredCount,
    required int partialCount,
    required int notCoveredCount,
    required int totalCount,
  }) {
    final statusBadge = _buildStatusBadge(overallStatus, fontSize: 11);

    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
              pw.Text(
                'Executive Summary',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkText,
                ),
              ),
              statusBadge,
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            summaryText,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: _darkText,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 12),
          // 4 Metric Mini-Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricMiniCard(
                  label: 'Dominance Score',
                  value: '$dominanceScore%',
                  color: _primaryNavy,
                  bgColor: _lightBg,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricMiniCard(
                  label: 'Covered Items',
                  value: '$coveredCount',
                  subValue: totalCount > 0 ? '${((coveredCount / totalCount) * 100).round()}%' : '0%',
                  color: _successGreen,
                  bgColor: _successGreenLight,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricMiniCard(
                  label: 'Partially Covered',
                  value: '$partialCount',
                  subValue: totalCount > 0 ? '${((partialCount / totalCount) * 100).round()}%' : '0%',
                  color: _warningAmber,
                  bgColor: _warningAmberLight,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricMiniCard(
                  label: 'Not Covered',
                  value: '$notCoveredCount',
                  subValue: totalCount > 0 ? '${((notCoveredCount / totalCount) * 100).round()}%' : '0%',
                  color: _dangerRed,
                  bgColor: _dangerRedLight,
                ),
              ),
            ],
          ),
      ];
  }

  /// 2-Column Info Section for Policy and Prescription.
  static pw.Widget _buildDocumentInfoSection({
    required Map<String, dynamic> policyJson,
    required Map<String, dynamic> prescriptionJson,
  }) {
    final bool isManual = prescriptionJson['isManual'] == true ||
        prescriptionJson['prescriptionSource'] == 'Self-entered Prescription' ||
        (prescriptionJson['manualText'] != null && prescriptionJson['manualText'].toString().isNotEmpty);

    final policyRows = <pw.Widget>[];
    _addInfoRowIfPresent(policyRows, 'Policy Name', policyJson['policyName']);
    _addInfoRowIfPresent(policyRows, 'Policy Number', policyJson['policyNumber']);
    _addInfoRowIfPresent(policyRows, 'Insurance Provider', policyJson['insuranceCompany']);
    _addInfoRowIfPresent(policyRows, 'Policy Type', policyJson['policyType']);
    _addInfoRowIfPresent(policyRows, 'Start Date', policyJson['policyStartDate']);
    _addInfoRowIfPresent(policyRows, 'Expiry Date', policyJson['policyEndDate']);
    if (policyJson['coverageAmount'] != null) {
      _addInfoRowIfPresent(policyRows, 'Coverage Amount', 'Rs. ${policyJson['coverageAmount']}');
    }
    if (policyJson['waitingPeriodDays'] != null) {
      _addInfoRowIfPresent(policyRows, 'Waiting Period', '${policyJson['waitingPeriodDays']} Days');
    }

    final rxRows = <pw.Widget>[];
    if (isManual) {
      _addInfoRowIfPresent(rxRows, 'Source', 'Self-entered Prescription');
      _addInfoRowIfPresent(rxRows, 'Diagnosis', prescriptionJson['diagnosis']);
    }
    _addInfoRowIfPresent(rxRows, 'Patient Name', prescriptionJson['patientName']);
    _addInfoRowIfPresent(rxRows, 'Treating Doctor', prescriptionJson['doctor'] ?? prescriptionJson['doctorName']);
    _addInfoRowIfPresent(rxRows, 'Hospital / Clinic', prescriptionJson['hospital'] ?? prescriptionJson['hospitalName']);
    _addInfoRowIfPresent(rxRows, 'Visit / Rx Date', prescriptionJson['visitDate'] ?? prescriptionJson['prescriptionDate']);
    if (prescriptionJson['hospitalizationRequired'] != null) {
      _addInfoRowIfPresent(
        rxRows,
        'Hospitalization',
        prescriptionJson['hospitalizationRequired'] == true ? 'Required' : 'Not Required',
      );
    }
    if (prescriptionJson['estimatedCost'] != null) {
      _addInfoRowIfPresent(rxRows, 'Estimated Cost', 'Rs. ${prescriptionJson['estimatedCost']}');
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildInfoCard(
            title: 'Policy Information',
            badgeText: 'Policy Verified',
            badgeColor: _primaryNavy,
            rows: policyRows,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildInfoCard(
            title: isManual ? 'Self-entered Prescription' : 'Prescription Information',
            badgeText: isManual ? 'Self-entered Rx' : 'Medical Rx',
            badgeColor: isManual ? PdfColor.fromHex('#2563EB') : PdfColor.fromHex('#7C3AED'),
            rows: rxRows,
          ),
        ),
      ],
    );
  }

  /// Coverage Distribution Donut Chart with Vector Drawing and Side Legends.
  static List<pw.Widget> _buildChartAndStatisticsSection({
    required int coveredCount,
    required int partialCount,
    required int notCoveredCount,
    required int totalCount,
  }) {
    final coveredPct = totalCount > 0 ? (coveredCount / totalCount) * 100 : 0.0;
    final partialPct = totalCount > 0 ? (partialCount / totalCount) * 100 : 0.0;
    final notCoveredPct = totalCount > 0 ? (notCoveredCount / totalCount) * 100 : 0.0;

    return [
      pw.Text(
        'Coverage Distribution',
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _darkText,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _borderColor, thickness: 1),
      pw.SizedBox(height: 6),
      pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Vector Donut Chart
              pw.Container(
                width: 120,
                height: 120,
                child: pw.Stack(
                  alignment: pw.Alignment.center,
                  children: [
                    pw.CustomPaint(
                      size: const PdfPoint(120, 120),
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        _drawDonutChart(
                          canvas,
                          size,
                          coveredCount: coveredCount,
                          partialCount: partialCount,
                          notCoveredCount: notCoveredCount,
                          totalCount: totalCount,
                        );
                      },
                    ),
                    pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          '$totalCount',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _darkText,
                          ),
                        ),
                        pw.Text(
                          'Total Items',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              // Legends & Percentages
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildLegendRow('Covered Items', coveredCount, coveredPct, _successGreen),
                    pw.SizedBox(height: 8),
                    _buildLegendRow('Partially Covered', partialCount, partialPct, _warningAmber),
                    pw.SizedBox(height: 8),
                    _buildLegendRow('Not Covered', notCoveredCount, notCoveredPct, _dangerRed),
                  ],
                ),
              ),
            ],
          ),
      pw.SizedBox(height: 8),
      pw.Divider(color: _borderColor, thickness: 1),
    ];
  }

  /// Policy & Prescription Spec Breakdown Cards.
  static List<pw.Widget> _buildDetailedSpecsSection({
    required Map<String, dynamic> policyJson,
    required Map<String, dynamic> prescriptionJson,
  }) {
    final medicines = prescriptionJson['medicines'] as List<dynamic>? ?? [];
    final tests = (prescriptionJson['medicalTests'] ?? prescriptionJson['tests']) as List<dynamic>? ?? [];
    final procedures = prescriptionJson['procedures'] as List<dynamic>? ?? [];

    final medicinesStr = medicines.map((m) {
      if (m is Map) {
        final name = m['name'] ?? m['medicineName'] ?? '';
        final dosage = m['dosage'] != null ? ' (${m['dosage']})' : '';
        return '$name$dosage';
      }
      return m.toString();
    }).where((s) => s.trim().isNotEmpty).join(', ');

    final testsStr = tests.map((t) {
      if (t is Map) return t['name'] ?? t['testName'] ?? '';
      return t.toString();
    }).where((s) => s.trim().isNotEmpty).join(', ');

    final proceduresStr = procedures.map((p) {
      if (p is Map) return p['name'] ?? p['procedureName'] ?? '';
      return p.toString();
    }).where((s) => s.trim().isNotEmpty).join(', ');

    final rows = <pw.Widget>[];
    if (medicinesStr.isNotEmpty) _addInfoRowIfPresent(rows, 'Prescribed Medicines', medicinesStr);
    if (testsStr.isNotEmpty) _addInfoRowIfPresent(rows, 'Medical Investigations', testsStr);
    if (proceduresStr.isNotEmpty) _addInfoRowIfPresent(rows, 'Recommended Procedures', proceduresStr);

    if (rows.isEmpty) return [pw.SizedBox.shrink()];

    return [
      pw.Text(
        'Prescribed Medical Breakdown',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _darkText,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _borderColor, thickness: 1),
      pw.SizedBox(height: 6),
      ...rows,
      pw.SizedBox(height: 4),
      pw.Divider(color: _borderColor, thickness: 1),
    ];
  }

  /// Coverage Comparison Table with Header, Alternating Rows, and Status Badges.
  static pw.Widget _buildComparisonTableSection(List<dynamic> comparison) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Coverage Comparison',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _darkText,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(
            top: pw.BorderSide(color: _borderColor, width: 1),
            bottom: pw.BorderSide(color: _borderColor, width: 1),
            left: pw.BorderSide(color: _borderColor, width: 1),
            right: pw.BorderSide(color: _borderColor, width: 1),
            horizontalInside: pw.BorderSide(color: _dividerColor, width: 0.8),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.2),
            1: const pw.FlexColumnWidth(2.0),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2.2),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _lightBg),
              children: [
                _buildTableCell('ITEM / PROCEDURE', isHeader: true),
                _buildTableCell('CATEGORY', isHeader: true),
                _buildTableCell('COST', isHeader: true, align: pw.TextAlign.center),
                _buildTableCell('COVERAGE STATUS', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            // Data Rows
            ...comparison.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value as Map<String, dynamic>;
              final itemName = item['item'] ?? 'Unknown';
              final category = item['itemType'] ?? item['category'] ?? 'General';
              final cost = item['cost'] ?? item['prescriptionCost'];
              final costStr = cost != null && cost != 0 ? 'Rs. $cost' : '-';
              final status = (item['status'] ?? item['coverageStatus'] ?? 'Not Covered').toString();
              final isEven = idx % 2 == 0;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isEven ? _cardBg : _lightBg,
                ),
                children: [
                  _buildTableCell(itemName, isBold: true),
                  _buildTableCell(category),
                  _buildTableCell(costStr, align: pw.TextAlign.center),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: _buildStatusBadge(status, fontSize: 8),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Card-Based Coverage Decision Details with Quotation-Styled Policy Evidence.
  static List<pw.Widget> _buildDecisionDetailsSection(List<dynamic> comparison) {
    return [
        pw.Text(
          'Coverage Decision Details & Policy Evidence',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _darkText,
          ),
        ),
        pw.SizedBox(height: 10),
        ...comparison.map((item) {
          final itemMap = item as Map<String, dynamic>;
          final itemName = (itemMap['item'] ?? 'Evaluated Item').toString();
          final category = (itemMap['itemType'] ?? itemMap['category'] ?? 'General').toString();
          final status = (itemMap['status'] ?? itemMap['coverageStatus'] ?? 'Not Covered').toString();
          final reason = (itemMap['explanation'] ?? itemMap['reason'] ?? itemMap['coverageStatusReason'] ?? '').toString().trim();
          final policyEvidence = (itemMap['policyEvidence'] ?? '').toString().trim();
          final financialDecision = (itemMap['financialDecision'] ?? itemMap['recommendation'] ?? '').toString().trim();
          final policyLimit = (itemMap['policyLimit'] ?? '').toString().trim();

          final isCovered = status == 'Covered';
          final isPartial = status == 'Partially Covered';

          final PdfColor cardBorderColor = isCovered
              ? _successGreenBorder
              : (isPartial ? _warningAmberBorder : _dangerRedBorder);

          return pw.Wrap(
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _cardBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: cardBorderColor, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                // Top Row: Item Name, Category Tag & Status Badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        itemName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _darkText,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _lightBg,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: _borderColor, width: 0.5),
                          ),
                          child: pw.Text(
                            category,
                            style: pw.TextStyle(fontSize: 7.5, color: _mutedText, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        _buildStatusBadge(status, fontSize: 8),
                      ],
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    reason,
                    style: pw.TextStyle(fontSize: 8.5, color: _darkText, lineSpacing: 1.5),
                  ),
                ],
                // Policy Evidence Quote Block
                if (policyEvidence.isNotEmpty &&
                    policyEvidence != 'No matching policy clause found.' &&
                    policyEvidence != 'null') ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _lightBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: _borderColor, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Policy Evidence & Clause Extract:',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryNavy,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '"$policyEvidence"',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                            color: _accentSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (policyLimit.isNotEmpty && policyLimit != 'null') ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Policy Limit: $policyLimit',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primaryNavy),
                  ),
                ],
                if (financialDecision.isNotEmpty && financialDecision != 'null') ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Recommendation / Financial Note: $financialDecision',
                    style: pw.TextStyle(fontSize: 8, color: _mutedText),
                  ),
                ],
                  ],
                ),
              ),
            ],
          );
        }),
      ];
  }

  /// Recommendations Highlight Box.
  static pw.Widget _buildRecommendationsSection(String recommendations) {
    return pw.Wrap(
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _lightBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: _borderColor, width: 1),
          ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Claim Recommendations & Actionable Next Steps',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _primaryNavy,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            recommendations,
            style: pw.TextStyle(
              fontSize: 8.5,
              color: _darkText,
              lineSpacing: 1.5,
            ),
          ),
        ],
      ),
    ), // Close Container
      ], // Close children list
    ); // Close Wrap
  }

  /// Important Notes Box with Amber Highlight.
  static pw.Widget _buildImportantNotesBox() {
    return pw.Wrap(
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _warningAmberLight,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: _warningAmberBorder, width: 1),
          ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Important Claim Notes & Observations:',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _warningAmber,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '- Coverage determinations are evaluated based strictly on the uploaded policy clauses and prescription facts.',
            style: pw.TextStyle(fontSize: 8, color: _darkText),
          ),
          pw.Text(
            '- Any exclusions, room rent caps, co-payments, or waiting periods in your policy agreement will apply at final settlement.',
            style: pw.TextStyle(fontSize: 8, color: _darkText),
          ),
          pw.Text(
            '- Pre-authorization may be required for scheduled hospitalizations and high-value diagnostic procedures.',
            style: pw.TextStyle(fontSize: 8, color: _darkText),
          ),
        ],
      ),
    ), // Close Container
      ], // Close children list
    ); // Close Wrap
  }

  /// Professional Disclaimer Footer Box.
  static pw.Widget _buildDisclaimerBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderColor, width: 0.8),
      ),
      child: pw.Text(
        'DISCLAIMER: This document is an automated System assisted claim coverage analysis report prepared for reference and decision support only. It does not constitute a guaranteed claim authorization or legal underwriting agreement. Final reimbursement and cashless approvals remain subject to the terms, conditions, deductibles, and verification protocols of your insurance provider.',
        style: pw.TextStyle(
          fontSize: 7,
          color: _mutedText,
          lineSpacing: 1.4,
        ),
      ),
    );
  }

  // ─── Visual & Helper Components ───────────────────────────────────────────

  /// Vector Drawing for Donut Chart on PDF Graphics.
  static void _drawDonutChart(
    PdfGraphics canvas,
    PdfPoint size, {
    required int coveredCount,
    required int partialCount,
    required int notCoveredCount,
    required int totalCount,
  }) {
    if (totalCount <= 0) return;

    final cx = size.x / 2;
    final cy = size.y / 2;
    final outerRadius = math.min(cx, cy) - 2;
    final innerRadius = outerRadius * 0.58;

    final coveredAngle = (coveredCount / totalCount) * 2 * math.pi;
    final partialAngle = (partialCount / totalCount) * 2 * math.pi;
    final notCoveredAngle = (notCoveredCount / totalCount) * 2 * math.pi;

    double currentAngle = -math.pi / 2; // Start from 12 o'clock

    // Helper to draw filled sector
    void drawSector(double angleSpan, PdfColor color) {
      if (angleSpan <= 0) return;
      canvas.setFillColor(color);
      canvas.moveTo(cx, cy);

      const int steps = 40;
      for (int i = 0; i <= steps; i++) {
        final theta = currentAngle + (angleSpan * (i / steps));
        final px = cx + outerRadius * math.cos(theta);
        final py = cy + outerRadius * math.sin(theta);
        canvas.lineTo(px, py);
      }
      canvas.lineTo(cx, cy);
      canvas.fillPath();

      currentAngle += angleSpan;
    }

    // 1. Draw Sectors
    drawSector(coveredAngle, _successGreen);
    drawSector(partialAngle, _warningAmber);
    drawSector(notCoveredAngle, _dangerRed);

    // 2. Cut out Center Circle (Donut Hole)
    canvas.setFillColor(_cardBg);
    canvas.drawEllipse(cx, cy, innerRadius, innerRadius);
    canvas.fillPath();
  }

  /// Modern Status Badge Widget (Covered = Green, Partially Covered = Amber, Not Covered = Red).
  static pw.Widget _buildStatusBadge(String status, {double fontSize = 9}) {
    PdfColor badgeColor;
    PdfColor badgeBg;
    PdfColor badgeBorder;

    final lower = status.toLowerCase();
    if (lower == 'covered') {
      badgeColor = _successGreen;
      badgeBg = _successGreenLight;
      badgeBorder = _successGreenBorder;
    } else if (lower.contains('partially') || lower.contains('partial')) {
      badgeColor = _warningAmber;
      badgeBg = _warningAmberLight;
      badgeBorder = _warningAmberBorder;
    } else {
      badgeColor = _dangerRed;
      badgeBg = _dangerRedLight;
      badgeBorder = _dangerRedBorder;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: badgeBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: badgeBorder, width: 0.8),
      ),
      child: pw.Text(
        status.toUpperCase(),
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: badgeColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Metric Mini Card Widget.
  static pw.Widget _buildMetricMiniCard({
    required String label,
    required String value,
    String? subValue,
    required PdfColor color,
    required PdfColor bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderColor, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _mutedText),
          ),
          pw.SizedBox(height: 2),
          pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.end,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color),
              ),
              if (subValue != null) ...[
                pw.SizedBox(width: 4),
                pw.Text(
                  subValue,
                  style: pw.TextStyle(fontSize: 8, color: _mutedText),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Information Card Container for Policy and Prescription.
  static pw.Widget _buildInfoCard({
    required String title,
    required String badgeText,
    required PdfColor badgeColor,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkText,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: badgeColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  badgeText,
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  /// Helper to add a clean key-value row only when the value is present and non-empty.
  static void _addInfoRowIfPresent(List<pw.Widget> list, String label, dynamic value) {
    if (value == null) return;
    final strVal = value.toString().trim();
    if (strVal.isEmpty || strVal == 'null' || strVal == 'N/A' || strVal == 'None' || strVal == 'Unknown') {
      return;
    }

    list.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 8),
                child: pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 8, color: _mutedText, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.Expanded(
              flex: 7,
              child: pw.Text(
                strVal,
                style: pw.TextStyle(fontSize: 8.5, color: _darkText, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Legend Row with Color Bullet, Label, Count, and Percentage.
  static pw.Widget _buildLegendRow(String label, int count, double percentage, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkText),
            ),
          ],
        ),
        pw.Text(
          '$count items (${percentage.toStringAsFixed(0)}%)',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  /// Table Cell Helper.
  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 8.5,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _mutedText : _darkText,
        ),
      ),
    );
  }

  /// Generates clean filename: `Coverage_Report_<PolicyNumber>_<PrescriptionNumber>.pdf`
  static String _generateFilename(Map<String, dynamic> data) {
    final policyJson = data['policyJson'] as Map<String, dynamic>? ?? {};
    final prescriptionJson = data['prescriptionJson'] as Map<String, dynamic>? ?? {};

    String policyNum = (policyJson['policyNumber'] ?? data['policyNumber'] ?? 'POL').toString().trim();
    String rxNum = (prescriptionJson['prescriptionNumber'] ?? data['prescriptionNumber'] ?? 'RX').toString().trim();

    // Sanitize for file system
    policyNum = policyNum.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    rxNum = rxNum.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

    if (policyNum.isEmpty) policyNum = 'POLICY';
    if (rxNum.isEmpty) rxNum = 'PRESCRIPTION';

    return 'Coverage_Report_${policyNum}_$rxNum.pdf';
  }
}
