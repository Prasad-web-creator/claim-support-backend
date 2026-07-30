/**
 * Policy Extraction Service
 * Stage 4: Extract Structured Policy JSON using AI
 */

const { extractJsonWithRetry } = require('../utils/aiClient');
const { validateExtraction } = require('../utils/extractionValidator');
const { splitTextIntelligently, mergeExtractedJson } = require('../utils/documentSplitter');

const POLICY_FIELDS = [
    'insuranceCompany', 'policyHolder', 'policyNumber', 'policyType', 
    'policyStartDate', 'policyEndDate', 'coverageAmount', 'waitingPeriodDays', 
    'roomEligibility', 'coveredDiseases', 'excludedDiseases', 'coveredTreatments', 
    'excludedTreatments', 'medicinesCoverage', 'medicalTestsCoverage', 
    'hospitalization', 'icu', 'emergency', 'dayCare', 'preExistingDiseases', 
    'networkHospitalRules', 'coPay', 'deductibles', 'specialConditions', 'notes'
];

const REQUIRED_POLICY_FIELDS = ['insuranceCompany', 'policyNumber', 'coveredTreatments'];

async function extractPolicyJson(cleanedPolicyText, abortSignal = null) {

    if (!cleanedPolicyText) {
        throw new Error('Cleaned policy text is required for extraction.');
    }

    const systemPrompt = `You are a strict data extraction AI. Your task is to extract structured information from the given insurance policy text.
Do NOT determine coverage or make decisions. Extract ONLY what is explicitly stated in the text. Never hallucinate.

CRITICAL RULES:
1. Return ONLY JSON. Never return markdown blocks, explanations, or introductory text.
2. Return null ONLY if information truly does not exist.
3. NEVER return strings like "Unknown", "N/A", "Not specified", or "None". If missing, return null.
4. Never invent values.
5. Preserve dates exactly.
6. Preserve monetary values.

Return ONLY a valid JSON object with the following fields:
- insuranceCompany (string)
- policyHolder (string)
- policyNumber (string)
- policyType (string)
- policyStartDate (string)
- policyEndDate (string)
- coverageAmount (number)
- waitingPeriodDays (number) - MUST BE RAW NUMBER, NO MATH EXPRESSIONS (e.g., use 1440 instead of 48 * 30)
- roomEligibility (string)
- coveredDiseases (array of strings)
- excludedDiseases (array of strings)
- coveredTreatments (array of strings)
- excludedTreatments (array of strings)
- medicinesCoverage (string)
- medicalTestsCoverage (string)
- hospitalization (string)
- icu (string)
- emergency (string)
- dayCare (string)
- preExistingDiseases (string)
- networkHospitalRules (string)
- coPay (string)
- deductibles (string)
- specialConditions (array of strings)
- notes (string)`;

    const startTime = Date.now();
    const chunks = splitTextIntelligently(cleanedPolicyText);
    const extractedJsons = [];
    let totalPromptTokens = 0;
    let totalCompletionTokens = 0;
    let totalRetries = 0;


    for (const chunk of chunks) {
        const result = await extractJsonWithRetry(systemPrompt, chunk, process.env.AI_MODEL || 'gemini-2.5-flash', 4000, abortSignal);
        extractedJsons.push(result.extractedJson);
        totalPromptTokens += result.tokens.promptTokens;
        totalCompletionTokens += result.tokens.completionTokens;
        totalRetries += result.retryCount;
    }

    const mergedJson = mergeExtractedJson(extractedJsons);
    const validationResult = validateExtraction(mergedJson, REQUIRED_POLICY_FIELDS, POLICY_FIELDS);
    const processingTime = Date.now() - startTime;


    return {
        success: validationResult.isValid,
        extractionConfidence: validationResult.confidence,
        processingTime,
        retryCount: totalRetries,
        tokens: { prompt: totalPromptTokens, completion: totalCompletionTokens },
        extractedJson: validationResult.cleanedJson,
        validationSummary: validationResult.errors,
        warnings: validationResult.warnings
    };
}

module.exports = { extractPolicyJson };
