/**
 * Business Rule Engine
 * Handles Stage 7: Run backend business rules WITHOUT AI.
 */

/**
 * Runs deterministic business rules based on the JSON inputs.
 * 
 * @param {Object} policyJson - The validated policy JSON.
 * @param {Object} prescriptionJson - The validated prescription JSON.
 * @returns {Object} The results of the business rules, including blockers, warnings, and overall eligibility.
 */
function runBusinessRules(policyJson, prescriptionJson) {

  const rules = {};
  const blockers = [];
  const warnings = [];

  // Helper to standardise results
  const result = (passed, reason) => ({ passed, reason });

  // 1. policyExpired
  if (policyJson.policyEndDate) {
    const endDate = new Date(policyJson.policyEndDate);
    const now = new Date(); 
    if (isNaN(endDate.getTime())) {
      rules.policyExpired = result(null, 'Invalid policyEndDate format');
    } else if (endDate < now) {
      rules.policyExpired = result(false, 'Policy has expired');
      blockers.push('Policy has expired');
    } else {
      rules.policyExpired = result(true, 'Policy is currently active');
    }
  } else {
    rules.policyExpired = result(null, 'Insufficient data to evaluate: missing policyEndDate');
  }

  // 2. waitingPeriodCompleted
  if (policyJson.policyStartDate && policyJson.waitingPeriodDays !== undefined && policyJson.waitingPeriodDays !== null) {
    const startDate = new Date(policyJson.policyStartDate);
    const now = new Date();
    if (isNaN(startDate.getTime())) {
      rules.waitingPeriodCompleted = result(null, 'Invalid policyStartDate format');
    } else {
      const daysSinceStart = Math.floor((now - startDate) / (1000 * 60 * 60 * 24));
      if (daysSinceStart < policyJson.waitingPeriodDays) {
        rules.waitingPeriodCompleted = result(false, `Waiting period not completed. ${daysSinceStart} days elapsed out of ${policyJson.waitingPeriodDays}.`);
        blockers.push('Waiting period not completed');
      } else {
        rules.waitingPeriodCompleted = result(true, 'Waiting period completed');
      }
    }
  } else {
    rules.waitingPeriodCompleted = result(null, 'Insufficient data to evaluate: missing policyStartDate or waitingPeriodDays');
  }

  // 3. diagnosisCovered
  const diagnosis = prescriptionJson.diagnosis;
  if (diagnosis) {
    const covered = [...(policyJson.coveredDiseases || []), ...(policyJson.coveredTreatments || [])];
    const isCovered = covered.some(c => c.toLowerCase().includes(diagnosis.toLowerCase()) || diagnosis.toLowerCase().includes(c.toLowerCase()));
    
    if (isCovered) {
      rules.diagnosisCovered = result(true, `Diagnosis '${diagnosis}' is listed in covered treatments/diseases`);
    } else if (covered.length > 0) {
      rules.diagnosisCovered = result(false, `Diagnosis '${diagnosis}' not found in covered lists`);
      warnings.push(`Diagnosis '${diagnosis}' is not explicitly covered`);
    } else {
      rules.diagnosisCovered = result(null, 'Insufficient data to evaluate: no covered list provided in policy');
    }
  } else {
    rules.diagnosisCovered = result(null, 'Insufficient data to evaluate: missing diagnosis in prescription');
  }

  // 4. diagnosisExcluded
  if (diagnosis) {
    const excluded = policyJson.excludedTreatments || [];
    const isExcluded = excluded.some(e => e.toLowerCase().includes(diagnosis.toLowerCase()) || diagnosis.toLowerCase().includes(e.toLowerCase()));
    
    if (isExcluded) {
      rules.diagnosisExcluded = result(false, `Diagnosis '${diagnosis}' is explicitly excluded`);
      blockers.push(`Diagnosis '${diagnosis}' is excluded`);
    } else {
      rules.diagnosisExcluded = result(true, `Diagnosis '${diagnosis}' is not in excluded list`);
    }
  } else {
    rules.diagnosisExcluded = result(null, 'Insufficient data to evaluate: missing diagnosis');
  }

  // 5. hospitalizationCovered
  if (prescriptionJson.hospitalizationRequired !== undefined && prescriptionJson.hospitalizationRequired !== null) {
    if (prescriptionJson.hospitalizationRequired) {
      const policyCoversHosp = policyJson.hospitalizationCovered !== false; 
      if (policyCoversHosp) {
        rules.hospitalizationCovered = result(true, 'Hospitalization is required and covered');
      } else {
        rules.hospitalizationCovered = result(false, 'Hospitalization required but not covered by policy');
        blockers.push('Hospitalization is required but not covered by this policy');
      }
    } else {
      rules.hospitalizationCovered = result(true, 'Hospitalization not required');
    }
  } else {
    rules.hospitalizationCovered = result(null, 'Insufficient data to evaluate: missing hospitalizationRequired');
  }

  // 6. coverageAmountSufficient
  if (prescriptionJson.estimatedTreatmentCost !== undefined && prescriptionJson.estimatedTreatmentCost !== null) {
    const cost = Number(prescriptionJson.estimatedTreatmentCost);
    const coverageAmount = policyJson.coverageAmount || policyJson.maximumClaimAmount;
    
    if (coverageAmount !== undefined && coverageAmount !== null) {
      const maxLimit = Number(coverageAmount);
      if (cost <= maxLimit) {
        rules.coverageAmountSufficient = result(true, `Estimated cost (${cost}) is within limits (${maxLimit})`);
      } else {
        rules.coverageAmountSufficient = result(false, `Estimated cost (${cost}) exceeds limits (${maxLimit})`);
        warnings.push(`Treatment cost exceeds coverage amount limits`);
      }
    } else {
      rules.coverageAmountSufficient = result(null, 'Insufficient data to evaluate: missing policy coverage limit');
    }
  } else {
    rules.coverageAmountSufficient = result(null, 'Insufficient data to evaluate: missing estimated treatment cost');
  }

  // 7. preExistingDiseaseCheck
  if (diagnosis && policyJson.preExistingDiseaseRules) {
    const isPreExisting = policyJson.preExistingDiseaseRules.toLowerCase().includes(diagnosis.toLowerCase());
    if (isPreExisting) {
      rules.preExistingDiseaseCheck = result(false, `Diagnosis '${diagnosis}' matches pre-existing disease rules`);
      warnings.push(`Diagnosis might be pre-existing`);
    } else {
      rules.preExistingDiseaseCheck = result(true, 'Diagnosis does not match pre-existing disease rules');
    }
  } else {
    rules.preExistingDiseaseCheck = result(null, 'Insufficient data to evaluate: missing diagnosis or preExistingDiseaseRules');
  }

  const overallEligible = blockers.length === 0;
  

  return {
    rules,
    overallEligible,
    blockers,
    warnings
  };
}

module.exports = { runBusinessRules };
