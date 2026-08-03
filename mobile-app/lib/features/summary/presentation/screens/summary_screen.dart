import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/utils/shared_prefs.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  final String? reportId;
  const SummaryScreen({super.key, this.reportId});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    if (widget.reportId != null) {
      try {
        final response = await ApiClient().dio.get('/analysis/${widget.reportId}');
        return response.data as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Error fetching report: $e");
        return {};
      }
    }

    final prefs = SharedPrefs.instance;
    final resultStr = prefs.getString('analysis_result');
    if (resultStr != null) {
      return jsonDecode(resultStr);
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF4B5563);
    final Color successGreen = const Color(0xFF059669);
    final Color dangerRed = const Color(0xFFDC2626);
    final Color warningAmber = const Color(0xFFD97706);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              key: const ValueKey('loading'),
              backgroundColor: theme.scaffoldBackgroundColor,
              body: const Center(child: CircularProgressIndicator()),
            );
          }

        final data = snapshot.data ?? {};
        final dominanceScore = data['dominanceScore'] ?? 0;
        final coverageBreakdown = data['coverageBreakdown'] as Map<String, dynamic>? ?? {};
        final overallStatus = data['overallStatus'] ?? 'Unknown';
        final summaryText = data['summaryText'] ?? 'No summary available.';
        final comparison = data['comparison'] as List<dynamic>? ?? [];
        final policyJson = data['policyJson'] as Map<String, dynamic>? ?? {};
        final prescriptionJson = data['prescriptionJson'] as Map<String, dynamic>? ?? {};
        final processingTime = data['processingTimeMs'] ?? 0;

        // Determine status color
        Color statusColor;
        IconData statusIcon;
        Color statusBg;
        Color statusBorder;
        if (overallStatus == 'Covered') {
          statusColor = successGreen;
          statusIcon = Icons.check_circle;
          statusBg = isDark ? successGreen.withAlpha(20) : const Color(0xFFECFDF5);
          statusBorder = isDark ? successGreen.withAlpha(50) : const Color(0xFFA7F3D0);
        } else if (overallStatus == 'Not Covered') {
          statusColor = dangerRed;
          statusIcon = Icons.cancel;
          statusBg = isDark ? dangerRed.withAlpha(20) : const Color(0xFFFEF2F2);
          statusBorder = isDark ? dangerRed.withAlpha(50) : const Color(0xFFFECACA);
        } else {
          statusColor = warningAmber;
          statusIcon = Icons.warning_amber_rounded;
          statusBg = isDark ? warningAmber.withAlpha(20) : const Color(0xFFFFFBEB);
          statusBorder = isDark ? warningAmber.withAlpha(50) : const Color(0xFFFDE68A);
        }

        final bool isInvalid = overallStatus.startsWith('Invalid');

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24.0, right: 24.0, top: 16.0, bottom: 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/dashboard'),
                        child: Icon(Icons.cancel_outlined,
                            color: textColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Coverage Summary',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      // Processing time badge
                      if (processingTime > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryBlue.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(processingTime / 1000).toStringAsFixed(1)}s',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Coverage Status Card ───
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(statusIcon, color: statusColor, size: 32),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          overallStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$dominanceScore% Dominance Score',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        if (coverageBreakdown.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withAlpha(20) : Colors.white.withAlpha(150),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Coverage Breakdown',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildBreakdownStat('Covered', coverageBreakdown['covered'] ?? 0, successGreen),
                                    _buildBreakdownStat('Partial', coverageBreakdown['partiallyCovered'] ?? 0, warningAmber),
                                    _buildBreakdownStat('Not Covered', coverageBreakdown['notCovered'] ?? 0, dangerRed),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          summaryText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!isInvalid) ...[
                    // ─── Policy Summary ───
                    if (policyJson.isNotEmpty)
                      _buildInfoCard(
                      isDark: isDark,
                      theme: theme,
                      title: 'Policy Summary',
                      icon: Icons.policy_outlined,
                      iconColor: primaryBlue,
                      items: [
                        _infoRow(isDark, 'Company', policyJson['insuranceCompany']),
                        _infoRow(isDark, 'Policy', policyJson['policyName']),
                        _infoRow(isDark, 'Number', policyJson['policyNumber']),
                        _infoRow(isDark, 'Type', policyJson['policyType']),
                        _infoRow(isDark, 'Coverage', policyJson['coverageAmount'] != null
                            ? '₹${policyJson['coverageAmount']}'
                            : null),
                        _infoRow(isDark, 'Max Claim', policyJson['maximumClaimAmount'] != null
                            ? '₹${policyJson['maximumClaimAmount']}'
                            : null),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // ─── Prescription Summary ───
                  if (prescriptionJson.isNotEmpty)
                    _buildInfoCard(
                      isDark: isDark,
                      theme: theme,
                      title: 'Prescription Summary',
                      icon: Icons.medical_information_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      items: [
                        _infoRow(isDark, 'Patient', prescriptionJson['patientName']),
                        _infoRow(isDark, 'Hospital', prescriptionJson['hospitalName']),
                        _infoRow(isDark, 'Doctor', prescriptionJson['doctorName']),
                        _infoRow(isDark, 'Diagnosis', prescriptionJson['diagnosis']),
                        _infoRow(isDark, 'Hospitalization',
                            prescriptionJson['hospitalizationRequired'] == true
                                ? 'Required'
                                : prescriptionJson['hospitalizationRequired'] == false
                                    ? 'Not Required'
                                    : null),
                        _infoRow(isDark, 'Est. Cost',
                            prescriptionJson['estimatedTreatmentCost'] != null
                                ? '₹${prescriptionJson['estimatedTreatmentCost']}'
                                : null),
                      ],
                    ),
                  const SizedBox(height: 24),


                  // ─── Comparison Table ───
                  if (comparison.isNotEmpty) ...[
                    Text(
                      'Coverage Comparison',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: const [
                                Expanded(
                                  flex: 2,
                                  child: Text('ITEM',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6B7280))),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text('COST',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6B7280))),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('STATUS',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6B7280))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                          ...comparison.map((item) {
                            final isCovered = item['isCovered'] == true;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['item'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            item['cost'] != null && item['cost'] != 0 
                                                ? '₹${item['cost']}' 
                                                : '-',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            item['status'] ?? '',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isCovered
                                                  ? successGreen
                                                  : dangerRed,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (comparison.last != item)
                                  Divider(
                                      height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Detailed Coverage Explanations ───
                  if (comparison.isNotEmpty) ...[
                    Text(
                      'Coverage Decision Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...comparison.map((item) {
                      final status = (item['status'] ?? item['coverageStatus'] ?? 'Not Covered').toString();
                      final isCovered = status == 'Covered';
                      final isPartial = status == 'Partially Covered';

                      Color itemColor;
                      Color itemBg;
                      Color itemBorder;
                      IconData itemIcon;

                      if (isCovered) {
                        itemColor = successGreen;
                        itemBg = isDark ? successGreen.withAlpha(15) : const Color(0xFFECFDF5);
                        itemBorder = isDark ? successGreen.withAlpha(40) : const Color(0xFFA7F3D0);
                        itemIcon = Icons.check_circle_outline;
                      } else if (isPartial) {
                        itemColor = warningAmber;
                        itemBg = isDark ? warningAmber.withAlpha(15) : const Color(0xFFFFFBEB);
                        itemBorder = isDark ? warningAmber.withAlpha(40) : const Color(0xFFFDE68A);
                        itemIcon = Icons.rule_folder_outlined;
                      } else {
                        itemColor = dangerRed;
                        itemBg = isDark ? dangerRed.withAlpha(15) : const Color(0xFFFEF2F2);
                        itemBorder = isDark ? dangerRed.withAlpha(40) : const Color(0xFFFECACA);
                        itemIcon = Icons.cancel_outlined;
                      }

                      final reason = (item['explanation'] ?? item['reason'] ?? item['coverageStatusReason'] ?? '').toString().trim();
                      final policyEvidence = (item['policyEvidence'] ?? '').toString().trim();
                      final financialDecision = (item['financialDecision'] ?? '').toString().trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: itemBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: itemBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(itemIcon, color: itemColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['item'] ?? 'Unknown Item',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: itemColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: itemColor.withAlpha(60)),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: itemColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            if (policyEvidence.isNotEmpty && policyEvidence != "No matching policy clause found.") ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.gavel_outlined, size: 14, color: primaryBlue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Policy Evidence: $policyEvidence',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (financialDecision.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Financial Note: $financialDecision',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            color: Color(0xFFD97706), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Disclaimer: ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text:
                                      'This is a system-generated reference. It does not guarantee approval. Final decisions rest with your insurance provider.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ], // End of !isInvalid check
                  
                  const SizedBox(height: 32),

                  // ─── Back to Dashboard Button ───
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
                      onPressed: () => context.go('/dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF374151) : primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Back to Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  // ─── Helper: Breakdown Stat ───
  Widget _buildBreakdownStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withAlpha(200),
          ),
        ),
      ],
    );
  }

  // ─── Helper: Info Card ───
  Widget _buildInfoCard({
    required bool isDark,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget?> items,
  }) {
    final validItems = items.whereType<Widget>().toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ...validItems,
        ],
      ),
    );
  }

  // ─── Helper: Info Row (returns null if value is null) ───
  Widget? _infoRow(bool isDark, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                )),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF111827), 
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
