/**
 * Prescription Extraction Service
 * Stage 5: Extract Structured Prescription JSON using AI
 */

const { extractJsonWithRetry } = require('../utils/aiClient');
const { validateExtraction } = require('../utils/extractionValidator');
const { splitTextIntelligently, mergeExtractedJson } = require('../utils/documentSplitter');

const PRESCRIPTION_FIELDS = [
    'patientName', 'age', 'gender', 'doctor', 'hospital', 'visitDate', 
    'diagnosis', 'symptoms', 'medicines', 'dosage', 'frequency', 
    'medicalTests', 'admission', 'discharge', 'hospitalizationRequired', 
    'procedures', 'estimatedCost', 'followUp', 'doctorNotes', 'medicalNotes'
];

const REQUIRED_PRESCRIPTION_FIELDS = ['patientName', 'diagnosis'];

async function extractPrescriptionJson(cleanedPrescriptionText, abortSignal = null) {

    if (!cleanedPrescriptionText) {
        throw new Error('Cleaned prescription text is required for extraction.');
    }

    const systemPrompt = `You are a strict medical data extraction AI. Your task is to extract structured medical information from the given prescription/medical document text.
Extract ONLY what is explicitly stated in the text. Do not make medical assumptions.

CRITICAL RULES:
1. Return ONLY JSON. Never return markdown blocks, explanations, or introductory text.
2. Return null ONLY if information is unavailable in the text.
3. NEVER return strings like "Unknown", "N/A", "Not specified", or "None". If missing, return null.
4. Do not invent or guess any medical values.
5. Preserve dates exactly.
6. Preserve medicine names, hospital names, and doctor names exactly.

Return ONLY a valid JSON object with the following fields:
- patientName (string)
- age (number) - MUST BE RAW NUMBER, NO MATH EXPRESSIONS
- gender (string)
- doctor (string)
- hospital (string)
- visitDate (string)
- diagnosis (string)
- symptoms (array of strings)
- medicines (array of objects, each with { name, dosage, frequency, duration, cost })
- dosage (string)
- frequency (string)
- medicalTests (array of objects, each with { name, cost })
- admission (string)
- discharge (string)
- hospitalizationRequired (boolean)
- procedures (array of objects, each with { name, cost })
- estimatedCost (number)
- followUp (string)
- doctorNotes (string)
- medicalNotes (string)`;

    const startTime = Date.now();
    const chunks = splitTextIntelligently(cleanedPrescriptionText);
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
    const validationResult = validateExtraction(mergedJson, REQUIRED_PRESCRIPTION_FIELDS, PRESCRIPTION_FIELDS);
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

module.exports = { extractPrescriptionJson };
