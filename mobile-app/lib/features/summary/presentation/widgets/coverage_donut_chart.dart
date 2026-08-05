import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A responsive, animated Donut Chart widget that visually represents
/// the percentage breakdown of Covered, Partially Covered, and Not Covered claim items.
class CoverageDonutChart extends StatefulWidget {
  final Map<String, dynamic>? coverageBreakdown;
  final bool isPolicyValid;
  final bool isPrescriptionValid;

  const CoverageDonutChart({
    super.key,
    required this.coverageBreakdown,
    this.isPolicyValid = true,
    this.isPrescriptionValid = true,
  });

  @override
  State<CoverageDonutChart> createState() => _CoverageDonutChartState();
}

class _CoverageDonutChartState extends State<CoverageDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  // Selected segment index: 0 = Covered, 1 = Partially Covered, 2 = Not Covered, null = none
  int? _selectedSegment;

  // Theme colors
  static const Color coveredColor = Color(0xFF059669); // Emerald Green
  static const Color partiallyCoveredColor = Color(0xFFD97706); // Amber / Orange
  static const Color notCoveredColor = Color(0xFFDC2626); // Danger Red

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Calculates whole percentages that guaranteed sum to 100% using Largest Remainder Method.
  Map<String, int> _calculateWholePercentages({
    required int covered,
    required int partiallyCovered,
    required int notCovered,
  }) {
    final total = covered + partiallyCovered + notCovered;
    if (total == 0) {
      return {'covered': 0, 'partiallyCovered': 0, 'notCovered': 0};
    }

    final double coveredPct = (covered / total) * 100;
    final double partialPct = (partiallyCovered / total) * 100;
    final double notCoveredPct = (notCovered / total) * 100;

    final int cFloor = coveredPct.floor();
    final int pFloor = partialPct.floor();
    final int nFloor = notCoveredPct.floor();

    final int remainder = 100 - (cFloor + pFloor + nFloor);

    final remainders = [
      MapEntry('covered', coveredPct - cFloor),
      MapEntry('partiallyCovered', partialPct - pFloor),
      MapEntry('notCovered', notCoveredPct - nFloor),
    ];

    // Sort descending by remainder
    remainders.sort((a, b) => b.value.compareTo(a.value));

    final result = {
      'covered': cFloor,
      'partiallyCovered': pFloor,
      'notCovered': nFloor,
    };

    for (int i = 0; i < remainder && i < remainders.length; i++) {
      final key = remainders[i].key;
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Visibility Check: Only display when BOTH Policy and Prescription are valid
    if (!widget.isPolicyValid || !widget.isPrescriptionValid) {
      return const SizedBox.shrink();
    }

    // 2. Error handling / Malformed data check
    if (widget.coverageBreakdown == null) {
      debugPrint('CoverageDonutChart: coverageBreakdown is null.');
      return const SizedBox.shrink();
    }

    try {
      final breakdown = widget.coverageBreakdown!;
      final int coveredCount = _parseInt(breakdown['covered']);
      final int partiallyCoveredCount = _parseInt(breakdown['partiallyCovered']);
      final int notCoveredCount = _parseInt(breakdown['notCovered']);
      final int totalEvaluated = coveredCount + partiallyCoveredCount + notCoveredCount;

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
      final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

      // 3. Empty State: When zero items are evaluated
      if (totalEvaluated == 0) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No evaluated claim items available.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // 4. Percentage calculation
      final percentages = _calculateWholePercentages(
        covered: coveredCount,
        partiallyCovered: partiallyCoveredCount,
        notCovered: notCoveredCount,
      );

      final int coveredPct = percentages['covered'] ?? 0;
      final int partialPct = percentages['partiallyCovered'] ?? 0;
      final int notCoveredPct = percentages['notCovered'] ?? 0;

      // Angles in radians
      final double coveredAngle = (coveredCount / totalEvaluated) * 2 * math.pi;
      final double partialAngle = (partiallyCoveredCount / totalEvaluated) * 2 * math.pi;
      final double notCoveredAngle = (notCoveredCount / totalEvaluated) * 2 * math.pi;

      return Semantics(
        label: 'Coverage Distribution Donut Chart: '
            '$coveredPct% Covered ($coveredCount items), '
            '$partialPct% Partially Covered ($partiallyCoveredCount items), '
            '$notCoveredPct% Not Covered ($notCoveredCount items).',
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(40)
                    : Colors.grey.shade200.withAlpha(100),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.donut_large_rounded,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Coverage Distribution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalEvaluated ${totalEvaluated == 1 ? "Item" : "Items"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Responsive Chart & Legend Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 420;

                  final chartWidget = AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return SizedBox(
                        width: 170,
                        height: 170,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(170, 170),
                              painter: _DonutChartPainter(
                                coveredAngle: coveredAngle * _animation.value,
                                partialAngle: partialAngle * _animation.value,
                                notCoveredAngle: notCoveredAngle * _animation.value,
                                coveredColor: coveredColor,
                                partialColor: partiallyCoveredColor,
                                notCoveredColor: notCoveredColor,
                                strokeWidth: 22,
                                highlightedIndex: _selectedSegment,
                              ),
                            ),
                            // Center Content
                            _buildCenterContent(
                              textColor: textColor,
                              textSecondary: textSecondary,
                              coveredPct: coveredPct,
                              partialPct: partialPct,
                              notCoveredPct: notCoveredPct,
                              coveredCount: coveredCount,
                              partialCount: partiallyCoveredCount,
                              notCoveredCount: notCoveredCount,
                              totalEvaluated: totalEvaluated,
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  final legendWidget = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        context: context,
                        label: 'Covered',
                        count: coveredCount,
                        percentage: coveredPct,
                        color: coveredColor,
                        index: 0,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        context: context,
                        label: 'Partially Covered',
                        count: partiallyCoveredCount,
                        percentage: partialPct,
                        color: partiallyCoveredColor,
                        index: 1,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        context: context,
                        label: 'Not Covered',
                        count: notCoveredCount,
                        percentage: notCoveredPct,
                        color: notCoveredColor,
                        index: 2,
                        isDark: isDark,
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        chartWidget,
                        const SizedBox(width: 20),
                        Expanded(child: legendWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        Center(child: chartWidget),
                        const SizedBox(height: 20),
                        legendWidget,
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('CoverageDonutChart rendering error: $e\n$stackTrace');
      return const SizedBox.shrink();
    }
  }

  /// Builds the center label inside the donut hole
  Widget _buildCenterContent({
    required Color textColor,
    required Color textSecondary,
    required int coveredPct,
    required int partialPct,
    required int notCoveredPct,
    required int coveredCount,
    required int partialCount,
    required int notCoveredCount,
    required int totalEvaluated,
  }) {
    String title = 'Coverage';
    String value = '100%';
    String subtitle = '$totalEvaluated ${totalEvaluated == 1 ? "Item" : "Items"}';
    Color titleColor = textSecondary;

    if (_selectedSegment == 0) {
      title = 'Covered';
      value = '$coveredPct%';
      subtitle = '$coveredCount ${coveredCount == 1 ? "Item" : "Items"}';
      titleColor = coveredColor;
    } else if (_selectedSegment == 1) {
      title = 'Partial';
      value = '$partialPct%';
      subtitle = '$partialCount ${partialCount == 1 ? "Item" : "Items"}';
      titleColor = partiallyCoveredColor;
    } else if (_selectedSegment == 2) {
      title = 'Not Covered';
      value = '$notCoveredPct%';
      subtitle = '$notCoveredCount ${notCoveredCount == 1 ? "Item" : "Items"}';
      titleColor = notCoveredColor;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSegment = null;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: 0.2,
            ),
            child: Text(title),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
            child: Text(value),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
            child: Text(subtitle),
          ),
        ],
      ),
    );
  }

  /// Builds a single legend row item
  Widget _buildLegendItem({
    required BuildContext context,
    required String label,
    required int count,
    required int percentage,
    required Color color,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _selectedSegment == index;

    return Tooltip(
      message: '$label: $percentage% ($count items)',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSegment = isSelected ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withAlpha(isDark ? 40 : 25)
                : (isDark ? Colors.grey.shade900.withAlpha(100) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withAlpha(120)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(90),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isDark ? Colors.grey.shade200 : const Color(0xFF374151),
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentData {
  final double angle;
  final Color color;
  final int index;

  _SegmentData(this.angle, this.color, this.index);
}

/// Custom painter for rendering the donut chart segments
class _DonutChartPainter extends CustomPainter {
  final double coveredAngle;
  final double partialAngle;
  final double notCoveredAngle;
  final Color coveredColor;
  final Color partialColor;
  final Color notCoveredColor;
  final double strokeWidth;
  final int? highlightedIndex;

  _DonutChartPainter({
    required this.coveredAngle,
    required this.partialAngle,
    required this.notCoveredAngle,
    required this.coveredColor,
    required this.partialColor,
    required this.notCoveredColor,
    required this.strokeWidth,
    this.highlightedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (baseRadius <= 0) return;

    final segments = [
      _SegmentData(coveredAngle, coveredColor, 0),
      _SegmentData(partialAngle, partialColor, 1),
      _SegmentData(notCoveredAngle, notCoveredColor, 2),
    ];

    final nonZeroSegments = segments.where((s) => s.angle > 0.001).toList();

    // If only one segment takes 100%
    if (nonZeroSegments.length == 1) {
      final seg = nonZeroSegments.first;
      final isHighlighted = highlightedIndex == seg.index;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? strokeWidth + 4 : strokeWidth;
      canvas.drawCircle(center, baseRadius, paint);
      return;
    }

    // Multiple segments: draw arcs with smooth gap
    double startAngle = -math.pi / 2;
    const double gapAngle = 0.05; // ~2.8 degrees gap

    for (final seg in segments) {
      if (seg.angle <= 0.001) continue;

      final isHighlighted = highlightedIndex == seg.index;
      final currentStroke = isHighlighted ? strokeWidth + 4 : strokeWidth;
      final currentRadius = isHighlighted ? baseRadius + 1 : baseRadius;
      final currentRect = Rect.fromCircle(center: center, radius: currentRadius);

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentStroke
        ..strokeCap = StrokeCap.round;

      final sweep = math.max(0.0, seg.angle - gapAngle);
      final actualStart = startAngle + (gapAngle / 2);

      canvas.drawArc(currentRect, actualStart, sweep, false, paint);
      startAngle += seg.angle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.coveredAngle != coveredAngle ||
        oldDelegate.partialAngle != partialAngle ||
        oldDelegate.notCoveredAngle != notCoveredAngle ||
        oldDelegate.highlightedIndex != highlightedIndex ||
        oldDelegate.coveredColor != coveredColor ||
        oldDelegate.partialColor != partialColor ||
        oldDelegate.notCoveredColor != notCoveredColor;
  }
}
