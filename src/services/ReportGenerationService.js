/**
 * Report Generation Service
 * Handles Stage 9: Generate the final structured coverage summary.
 */

/**
 * Generates the final structured coverage summary report based on all pipeline outputs.
 * 
 * @param {Object} policyJson - Extracted JSON data from the policy document.
 * @param {Object} prescriptionJson - Extracted JSON data from the prescription document.
 * @param {Object} businessRuleResults - Results from the business rules execution.
 * @param {Object} coverageAnalysis - Detailed analysis results from the LLM.
 * @param {number} processingTimeMs - Total pipeline processing time in milliseconds.
 * @returns {Object} The complete report object.
 */
function generateReport(policyJson, prescriptionJson, businessRuleResults, coverageAnalysis, processingTimeMs) {

  // Gracefully handle missing inputs by defaulting to empty objects
  policyJson = policyJson || {};
  prescriptionJson = prescriptionJson || {};
  businessRuleResults = businessRuleResults || {};
  coverageAnalysis = coverageAnalysis || {};

  const coverageStatus = coverageAnalysis.coverageStatus || 'Unknown';
  const confidenceScore = coverageAnalysis.confidenceScore || 0;

  const policySummary = {
    company: policyJson.insuranceCompany || 'Unknown',
    policyName: policyJson.policyName || 'Unknown',
    policyNumber: policyJson.policyNumber || 'Unknown',
    policyType: policyJson.policyType || 'Unknown',
    coverageAmount: policyJson.coverageAmount || 0,
    status: policyJson.policyEndDate && new Date(policyJson.policyEndDate) < new Date() ? 'Expired' : 'Active'
  };

  const prescriptionSummary = {
    patientName: prescriptionJson.patientName || 'Unknown',
    hospital: prescriptionJson.hospitalName || 'Unknown',
    doctor: prescriptionJson.doctorName || 'Unknown',
    diagnosis: prescriptionJson.diagnosis || 'Unknown',
    hospitalizationRequired: prescriptionJson.hospitalizationRequired !== undefined ? prescriptionJson.hospitalizationRequired : null
  };

  // Use the AI-generated comparison array if available, otherwise fallback to empty array
  const comparison = coverageAnalysis.comparison || [];

  const matchedItems = coverageAnalysis.coveredTreatments || comparison.filter(c => c.isCovered).map(c => c.item);
  const excludedItems = coverageAnalysis.excludedTreatments || comparison.filter(c => !c.isCovered).map(c => c.item);

  // Create human-readable summary text
  const summaryText = `Analysis complete with status: ${coverageStatus}. Patient ${prescriptionSummary.patientName} diagnosed with ${prescriptionSummary.diagnosis}. ${matchedItems.length} items are covered, while ${excludedItems.length} items are not covered or excluded. Confidence Score: ${confidenceScore}.`;

  let recommendations = coverageAnalysis.recommendation || '';
  if (coverageAnalysis.nextSteps && Array.isArray(coverageAnalysis.nextSteps)) {
    recommendations += ' ' + coverageAnalysis.nextSteps.join(' ');
  }

  const report = {
    coverageStatus,
    confidenceScore,
    policySummary,
    prescriptionSummary,
    matchedItems,
    excludedItems,
    applicableClauses: coverageAnalysis.matchedPolicyClauses || [],
    blockedClauses: coverageAnalysis.blockedPolicyClauses || [],
    businessRuleResults,
    recommendations: recommendations.trim(),
    reasoning: coverageAnalysis.reasoning || '',
    missingDocuments: coverageAnalysis.missingDocuments || [],
    processingTimeMs: processingTimeMs || 0,
    analysisVersion: '2.0.0',
    summaryText,
    comparison
  };

  
  return report;
}

module.exports = {
  generateReport
};
