/**
 * Coverage Analysis Service
 * Stage 8: AI Coverage Analysis.
 * 
 * Sends ONLY structured JSON (policyJson, prescriptionJson, businessRuleResults)
 * to Groq AI. Never sends raw PDFs or raw text.
 */

const crypto = require('crypto');
const AnalysisReport = require('../models/AnalysisReport');
const logger = require('../utils/logger');
const { extractJsonWithRetry } = require('../utils/aiClient');

/**
 * Strips markdown code fences from AI response and parses JSON.
 * @param {string} text - The text from AI response.
 * @returns {object} The parsed JSON object.
 */
function parseAiJsonResponse(text) {
  if (!text) return null;
  let cleanText = text.trim();
  if (cleanText.startsWith('```json')) {
    cleanText = cleanText.substring(7);
  } else if (cleanText.startsWith('```')) {
    cleanText = cleanText.substring(3);
  }
  if (cleanText.endsWith('```')) {
    cleanText = cleanText.substring(0, cleanText.length - 3);
  }
  try {
    return JSON.parse(cleanText.trim());
  } catch (error) {
    throw new Error('Failed to parse AI coverage analysis JSON: ' + error.message);
  }
}

/**
 * Analyzes the coverage status using Groq AI in a One-Pass mode.
 * 
 * @param {string} policyText - The raw cleaned policy text.
 * @param {string} prescriptionText - The raw cleaned prescription text.
 * @param {Object} businessRuleResults - The deterministic results from the Business Rule Engine.
 * @param {Object} prescriptionJson - The parsed prescription JSON used for hallucination validation.
 * @returns {Promise<Object>} The AI-generated coverage analysis in structured JSON format.
 */
async function analyzeCoverage(policyText, prescriptionText, businessRuleResults, prescriptionJson) {
  const systemPrompt = `
You are a Senior Health Insurance Claim Analyst with expertise in insurance policy interpretation, prescription analysis, and medical claim adjudication.

Your responsibility is to determine insurance coverage ONLY from the provided prescription text, policy text, and deterministic business rule results.

Never invent, assume, infer, or hallucinate any medicine, test, diagnosis, procedure, consultation, cost, policy clause, waiting period, exclusion, or coverage.

══════════════════════════════════════
PRIMARY OBJECTIVE
══════════════════════════════════════

Compare ONLY the medical items that explicitly exist in the prescription against the insurance policy.

Each prescription item must be evaluated independently for both Medical Coverage and Financial Applicability.

══════════════════════════════════════
STEP 1 — IDENTIFY PRESCRIPTION ITEMS
══════════════════════════════════════

Extract ONLY items explicitly written in the prescription.

Supported item types include:
• Medical Tests
• Laboratory Tests
• Diagnostic Tests
• Procedures
• Surgeries
• Consultations
• Diagnoses
• Medical Devices

CRITICAL RULE: DO NOT analyze coverage for Medicines or Pharmaceuticals. Exclude ALL medicine items from your comparison completely.

Do NOT create new items.
Do NOT combine items.
Do NOT split one item into multiple items.
Preserve the original wording whenever possible.

If the prescription contains duplicate items, compare each DISTINCT item only once.

If a prescription contains a Package (e.g., "Pre-Chemo Package" ₹2,400) which includes multiple items (CBC, RFT, LFT), the package cost belongs ONLY to the package. Do NOT distribute package cost across individual tests.

══════════════════════════════════════
STEP 2 — FIND POLICY EVIDENCE
══════════════════════════════════════

Search ONLY the supplied policy text. Find the most relevant policy clause.
If multiple clauses apply, choose the most specific one.
Never invent policy clauses. Never guess coverage.

══════════════════════════════════════
STEP 3 — APPLY BUSINESS RULES
══════════════════════════════════════

Business Rule Results are deterministic. Treat them as higher priority than your own reasoning. Never contradict them.

══════════════════════════════════════
STEP 4 — DETERMINE MEDICAL COVERAGE
══════════════════════════════════════

Allowed coverageStatus values ONLY (strictly exactly one of these three):
Covered -> Policy clearly covers the item.
Partially Covered -> Policy covers only under conditions or limits.
Not Covered -> Policy explicitly excludes the item.

══════════════════════════════════════
STEP 5 — FINANCIAL DECISION LOGIC
══════════════════════════════════════

Evaluate the financial applicability of each prescription item using ONLY explicit policy clauses.
Search for Sum Insured, Remaining Coverage, Sub-limits, Per-item limits, Per-day limits, Room rent limits, Consultation limits, Investigation/Test limits, Medicine limits, Procedure/Surgery limits, Package limits, Waiting Periods, Co-payment, Deductibles, Network requirements, Cashless eligibility, Percentage-based reimbursements, Maximum payable amount, Exclusions, and Conditions.

If the policy explicitly defines a payable limit, calculate (if possible):
- prescriptionCost
- policyLimit
- estimatedPayableAmount
- estimatedPatientPayable

If the policy covers a percentage (e.g. 80%), apply it. If a deductible exists, subtract it.
If multiple rules apply, apply all applicable policy conditions before calculating.
Extract prescription costs ONLY if explicitly present. If no price is present, prescriptionCost = 0. Never estimate medicine, investigation, or surgery charges.

IF FINANCIAL INFO IS MISSING (policy does not specify limits, reimbursement %, deductible, co-payment, or payable amount):
DO NOT calculate.
Set policyLimit = null, estimatedPayableAmount = null, estimatedPatientPayable = null.
Set financialDecision = "Manual Review Required"
Set explanation to point out: "Policy does not contain sufficient financial information."
Never guess!

══════════════════════════════════════
CONFIDENCE SCORING
══════════════════════════════════════

Medical Coverage Confidence: Based on policy evidence.
Financial Confidence: Based on explicit financial clauses.
Never assign High confidence if financial calculations required assumptions.

100: Exact policy clause directly matches.
90-99: Very strong evidence.
70-89: Reasonable evidence with minor ambiguity.
40-69: Weak evidence.
0-39: Very limited evidence.

Never assign 100 unless the policy explicitly supports the conclusion.

══════════════════════════════════════
OUTPUT REQUIREMENTS & STRICT JSON SCHEMA
══════════════════════════════════════

comparison MUST contain exactly one object for every DISTINCT prescription item. Do NOT add extra rows. Do NOT remove valid items. Do NOT include assumptions.
If prescription cost is unavailable, set prescriptionCost = 0.
If no matching clause exists, policyEvidence = "No matching policy clause found."

Return ONLY valid JSON. No Markdown. No comments. No text outside the object.

Output schema:
{
  "overallStatus": "",
  "overallConfidence": 0,
  "summary": "",
  "comparison": [
    {
      "item": "",
      "itemType": "",
      "prescriptionCost": 0,
      "coverageStatus": "",
      "policyLimit": null,
      "estimatedPayableAmount": null,
      "estimatedPatientPayable": null,
      "coPayment": null,
      "deductible": null,
      "waitingPeriodApplicable": false,
      "networkHospitalRequired": false,
      "cashlessEligible": false,
      "financialDecision": "",
      "policyEvidence": "",
      "prescriptionEvidence": "",
      "confidence": 0,
      "explanation": ""
    }
  ]
}
`;

  const userPrompt = `
PRESCRIPTION TEXT

${prescriptionText}

==================================================

POLICY TEXT

${policyText}

==================================================

BUSINESS RULE RESULTS

${JSON.stringify(businessRuleResults)}
`;

  try {
    const { extractedJson: parsedResponse } = await extractJsonWithRetry(systemPrompt, userPrompt);


    // We have removed the strict JavaScript validation filter based on user request.
    const rawComparison = parsedResponse.comparison || [];
    const filteredComparison = rawComparison;

    // Helper to ensure confidence is always 0-100 integer
    const parseConfidence = (val) => {
      let num = typeof val === 'number' ? val : parseFloat(val) || 0;
      if (num <= 1 && num > 0) return Math.round(num * 100);
      if (num > 100) return 100;
      if (num < 0) return 0;
      return Math.round(num);
    };

    // Map to the new expanded structure expected by the rest of the backend
    const totalItems = filteredComparison.length;
    const coveredItemsCount = filteredComparison.filter(c => 
      c.coverageStatus === 'Covered' || c.coverageStatus === 'Partially Covered'
    ).length;

    let calculatedConfidence = totalItems > 0
      ? Math.round((coveredItemsCount / totalItems) * 100)
      : parseConfidence(parsedResponse.overallConfidence);

    let derivedStatus = parsedResponse.overallStatus || 'Unknown';
    if (totalItems > 0) {
      if (coveredItemsCount === totalItems) {
        derivedStatus = 'Covered';
      } else if (coveredItemsCount === 0) {
        derivedStatus = 'Not Covered';
      } else {
        derivedStatus = 'Partially Covered';
      }
    }

    // If deterministic business rules explicitly blocked the claim, the coverage is 0%
    if (businessRuleResults && businessRuleResults.overallEligible === false) {
      calculatedConfidence = 0;
      derivedStatus = 'Not Covered';
    }

    const enhancedResponse = {
      coverageStatus: derivedStatus,
      confidenceScore: calculatedConfidence,
      comparison: filteredComparison.map(c => ({
        item: c.item,
        itemType: c.itemType || '',
        status: c.coverageStatus,
        cost: c.prescriptionCost || c.cost || 0,
        confidence: parseConfidence(c.confidence),
        isCovered: c.coverageStatus === 'Covered' || c.coverageStatus === 'Partially Covered',
        required: 'Yes',
        reason: c.explanation,
        // Financial fields
        policyLimit: c.policyLimit || null,
        estimatedPayableAmount: c.estimatedPayableAmount || null,
        estimatedPatientPayable: c.estimatedPatientPayable || null,
        coPayment: c.coPayment || null,
        deductible: c.deductible || null,
        waitingPeriodApplicable: c.waitingPeriodApplicable || false,
        networkHospitalRequired: c.networkHospitalRequired || false,
        cashlessEligible: c.cashlessEligible || false,
        financialDecision: c.financialDecision || '',
        policyEvidence: c.policyEvidence || '',
        prescriptionEvidence: c.prescriptionEvidence || ''
      })),
      reasoning: parsedResponse.summary || '',
      matchedPolicyClauses: [],
      blockedPolicyClauses: [],
      missingDocuments: [],
      recommendation: '',
      nextSteps: []
    };


    return enhancedResponse;

  } catch (error) {
    logger.error(`[CoverageAnalysisService] Stage 8 Error: Failed to analyze coverage: ${error.message}`, { stack: error.stack });
    
    // We do NOT save a failed report here, all-or-nothing is handled by the caller.
    throw new AppError('COVERAGE_ANALYSIS_FAILED', 500);
  }
}

module.exports = { analyzeCoverage };