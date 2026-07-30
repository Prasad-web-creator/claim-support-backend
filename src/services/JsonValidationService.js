/**
 * JSON Validation Service
 * Handles Stage 6: Validate extracted JSON objects.
 */

/**
 * Validates the extracted policy and prescription JSON objects.
 * 
 * @param {Object} policyJson - The extracted policy JSON object.
 * @param {Object} prescriptionJson - The extracted prescription JSON object.
 * @returns {Object} Validation result containing isValid, errors array, and the validated JSONs.
 */
function validateExtractedJson(policyJson, prescriptionJson) {
  
  const errors = [];
  
  // Basic object checks
  if (!policyJson || typeof policyJson !== 'object') {
    errors.push('policyJson is missing or not an object');
  }
  
  if (!prescriptionJson || typeof prescriptionJson !== 'object') {
    errors.push('prescriptionJson is missing or not an object');
  }
  
  if (errors.length > 0) {
    return {
      isValid: false,
      errors,
      validatedPolicyJson: policyJson,
      validatedPrescriptionJson: prescriptionJson
    };
  }
  
  // Validate Policy JSON required fields
  const requiredPolicyFields = ['insuranceCompany', 'coveredTreatments', 'excludedTreatments'];
  for (const field of requiredPolicyFields) {
    if (!(field in policyJson)) {
      errors.push(`policyJson is missing required field: ${field}`);
    }
  }
  
  // Validate Prescription JSON required fields
  const requiredPrescriptionFields = ['diagnosis'];
  for (const field of requiredPrescriptionFields) {
    if (!(field in prescriptionJson)) {
      errors.push(`prescriptionJson is missing required field: ${field}`);
    }
  }
  
  // Type validation
  if (policyJson.coveredTreatments !== undefined && policyJson.coveredTreatments !== null && !Array.isArray(policyJson.coveredTreatments)) {
    errors.push('policyJson.coveredTreatments must be an array or null');
  }
  
  if (policyJson.excludedTreatments !== undefined && policyJson.excludedTreatments !== null && !Array.isArray(policyJson.excludedTreatments)) {
    errors.push('policyJson.excludedTreatments must be an array or null');
  }

  // --- AI Robustness Sanitization ---
  function sanitizeArrayOfObjects(arr, defaultKey = 'name') {
    if (arr === null || arr === undefined) return null;
    
    // Detect and parse JSON strings
    if (typeof arr === 'string') {
      try {
        const parsed = JSON.parse(arr);
        if (Array.isArray(parsed) || typeof parsed === 'object') {
          arr = parsed;
        } else {
          return [{ [defaultKey]: arr, cost: null }];
        }
      } catch (e) {
        return [{ [defaultKey]: arr, cost: null }];
      }
    }
    
    if (!Array.isArray(arr)) {
      return [{ [defaultKey]: String(arr), cost: null }];
    }
    
    // Flatten nested arrays
    arr = arr.flat(Infinity);
    
    return arr.map(item => {
      // Detect string elements in array of objects and correct them
      if (typeof item === 'string') {
        return { [defaultKey]: item, cost: null };
      }
      if (typeof item === 'object' && item !== null) {
        return item; // Keep as is
      }
      return { [defaultKey]: String(item), cost: null };
    });
  }

  prescriptionJson.medicalTests = sanitizeArrayOfObjects(prescriptionJson.medicalTests, 'name');
  prescriptionJson.procedures = sanitizeArrayOfObjects(prescriptionJson.procedures, 'name');
  
  // Return validation results
  const isValid = errors.length === 0;

  return {
    isValid,
    errors,
    validatedPolicyJson: policyJson,
    validatedPrescriptionJson: prescriptionJson
  };
}

module.exports = { validateExtractedJson };
