/**
 * Extraction Validator
 * Handles strict schema validation, calculating confidence scores, and generating warnings.
 */

function isPopulated(val) {
    if (val === null || val === undefined) return false;
    if (typeof val === 'string' && val.trim() === '') return false;
    if (Array.isArray(val) && val.length === 0) return false;
    
    // Explicitly check for invalid AI default strings
    if (typeof val === 'string') {
        const lower = val.toLowerCase().trim();
        if (['unknown', 'n/a', 'none', 'not specified'].includes(lower)) return false;
    }
    
    return true;
}

/**
 * Validates extraction results against a schema and calculates confidence.
 * @param {object} extractedJson - The JSON object from AI
 * @param {string[]} requiredFields - Fields that MUST be present for extraction to be valid
 * @param {string[]} allExpectedFields - All fields expected in the document for confidence scoring
 * @returns {object} Validation result
 */
function validateExtraction(extractedJson, requiredFields, allExpectedFields) {
    if (!extractedJson || typeof extractedJson !== 'object') {
        return {
            isValid: false,
            confidence: 0,
            warnings: ['Extracted JSON is missing or invalid object type.'],
            errors: ['Invalid root object']
        };
    }

    const errors = [];
    const warnings = [];
    
    // Clean up "Unknown" fields to null
    for (const key of Object.keys(extractedJson)) {
        if (!isPopulated(extractedJson[key])) {
            extractedJson[key] = null;
        }
    }

    // Check required fields
    for (const field of requiredFields) {
        if (!isPopulated(extractedJson[field])) {
            errors.push(`Missing required field: ${field}`);
        }
    }

    // Calculate confidence based on expected fields population
    let populatedCount = 0;
    for (const field of allExpectedFields) {
        if (isPopulated(extractedJson[field])) {
            populatedCount++;
        } else {
            warnings.push(`Field missing or unpopulated: ${field}`);
        }
    }

    // Basic confidence algorithm
    // 50% weight to required fields (if valid, else 0)
    // 50% weight to overall fields populated
    const requiredScore = errors.length === 0 ? 50 : (50 - (errors.length * 10));
    const normalizedRequiredScore = Math.max(0, requiredScore);
    
    const overallRatio = populatedCount / allExpectedFields.length;
    const overallScore = Math.round(overallRatio * 50);
    
    const confidence = normalizedRequiredScore + overallScore;

    return {
        isValid: errors.length === 0,
        confidence,
        errors,
        warnings,
        cleanedJson: extractedJson
    };
}

module.exports = { validateExtraction };
