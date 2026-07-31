const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');
const baseSchemaFields = require('./BaseSchema');

/**
 * AnalysisReport Schema — Production Pipeline v2.0
 * 
 * Stores the complete output of the 11-stage AI analysis pipeline,
 * including extracted JSONs, business rule results, AI coverage analysis,
 * and per-stage processing logs.
 */
const analysisReportSchema = new mongoose.Schema({
  ...baseSchemaFields,

  // --- Ownership ---
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  policyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Policy',
  },
  prescriptionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Prescription',
  },

  // --- Pipeline Status ---
  status: {
    type: String,
    enum: ['pending', 'extracting', 'analyzing', 'completed', 'failed'],
    default: 'pending',
  },
  analysisVersion: {
    type: String,
    default: '2.0.0',
  },

  // --- Stage 4: Extracted Policy JSON ---
  policyJson: {
    insuranceCompany: String,
    policyName: String,
    policyNumber: String,
    policyType: String,
    coverageAmount: Number,
    waitingPeriodDays: Number,
    roomRentLimit: Number,
    coveredDiseases: [String],
    coveredTreatments: [String],
    excludedTreatments: [String],
    emergencyCoverage: Boolean,
    networkHospitals: [String],
    preExistingDiseaseRules: String,
    coPayPercentage: Number,
    deductibleAmount: Number,
    maximumClaimAmount: Number,
    specialConditions: [String],
    importantClauses: [String],
    policyStartDate: String,
    policyEndDate: String,
    coverageNotes: String,
  },

  // --- Stage 5: Extracted Prescription JSON ---
  prescriptionJson: {
    patientName: String,
    hospitalName: String,
    doctorName: String,
    diagnosis: String,
    symptoms: [String],
    medicines: [{
      name: String,
      dosage: String,
      frequency: String,
      duration: String,
    }],
    medicalTests: [{
      name: String,
      cost: Number,
    }],
    procedures: [{
      name: String,
      cost: Number,
    }],
    hospitalizationRequired: Boolean,
    estimatedHospitalStayDays: Number,
    admissionDate: String,
    dischargeDate: String,
    followUpDate: String,
    followUpNotes: String,
    medicalNotes: String,
    estimatedTreatmentCost: Number,
  },

  // --- Stage 7: Business Rule Engine Results ---
  businessRules: {
    rules: {
      type: mongoose.Schema.Types.Mixed,
    },
    overallEligible: Boolean,
    blockers: [String],
    warnings: [String],
  },

  // --- Stage 8: AI Coverage Analysis & Document Validity ---
  documentValidity: {
    prescriptionValid: { type: Boolean, default: true },
    policyValid: { type: Boolean, default: true },
    injectionAttemptDetected: { type: Boolean, default: false },
    injectionAttemptDetails: { type: String, default: '' },
    detectedDocumentTypeIfInvalid: { type: String, default: '' },
  },
  overallStatus: { type: String },
  overallConfidence: { type: Number },
  summary: { type: String },

  coverageAnalysis: {
    coverageStatus: String,
    confidenceScore: Number,
    coveredTreatments: [{
      treatment: String,
      policyCoverage: String,
      status: String,
    }],
    excludedTreatments: [{
      treatment: String,
      reason: String,
    }],
    matchedPolicyClauses: [String],
    blockedPolicyClauses: [String],
    hospitalizationCovered: Boolean,
    waitingPeriodApplicable: Boolean,
    coverageAmountApplicable: Number,
    missingDocuments: [String],
    reasoning: String,
    recommendation: String,
    nextSteps: [String],
  },

  // --- Audit Trail ---
  policyText: { type: String },
  prescriptionText: { type: String },

  // --- Summary & Detailed Comparison Schema ---
  confidenceScore: { type: Number },
  summaryText: { type: String },
  comparison: [{
    item: { type: String },
    itemType: { type: String },
    prescriptionCost: { type: Number, default: 0 },
    cost: { type: Number, default: 0 }, // backward compatibility
    coverageStatus: { type: String },
    status: { type: String }, // backward compatibility
    coverageStatusReason: { type: String },
    policyLimit: { type: mongoose.Schema.Types.Mixed, default: null },
    estimatedPayableAmount: { type: mongoose.Schema.Types.Mixed, default: null },
    estimatedPatientPayable: { type: mongoose.Schema.Types.Mixed, default: null },
    coPayment: { type: mongoose.Schema.Types.Mixed, default: null },
    deductible: { type: mongoose.Schema.Types.Mixed, default: null },
    waitingPeriodApplicable: { type: Boolean, default: false },
    waitingPeriodVerified: { type: Boolean, default: false },
    networkHospitalRequired: { type: Boolean, default: false },
    cashlessEligible: { type: Boolean, default: false },
    financialDecision: { type: String },
    policyEvidence: { type: String },
    prescriptionEvidence: { type: String },
    confidence: { type: Number, default: 0 },
    explanation: { type: String },
    reason: { type: String }, // backward compatibility
    isCovered: { type: Boolean },
    required: { type: String },
  }],

  // --- Processing Metadata ---
  processingTimeMs: { type: Number },
  stages: [{
    name: String,
    status: { type: String, enum: ['success', 'failed', 'skipped'] },
    durationMs: Number,
    error: String,
  }],

  // --- Error Info (if pipeline failed) ---
  errorMessage: { type: String },
  failedAtStage: { type: String },

  reportNumber: { type: Number },

}, { timestamps: true, strict: true });

// Compound index for optimal dashboard counts and pagination
analysisReportSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });

analysisReportSchema.pre('save', async function(next) {
  if (this.isNew) {
    const Counter = require('./Counter');
    const counter = await Counter.findOneAndUpdate(
      { userId: this.userId, entityType: 'AnalysisReport' },
      { $inc: { seq: 1 } },
      { new: true, upsert: true }
    );
    this.reportNumber = counter.seq;
  }
  next();
});

analysisReportSchema.plugin(mongoosePaginate);

module.exports = mongoose.model('AnalysisReport', analysisReportSchema);
