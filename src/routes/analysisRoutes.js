const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const auth = require('../middleware/authMiddleware');
const AnalysisReport = require('../models/AnalysisReport');
const ActivityLog = require('../models/ActivityLog');

// --- Pipeline Services ---
const { extractDocument } = require('../services/DocumentExtractionService');
const { cleanText } = require('../services/TextCleaningService');
const { extractPolicyJson } = require('../services/PolicyExtractionService');
const { extractPrescriptionJson } = require('../services/PrescriptionExtractionService');
const { validateExtractedJson } = require('../services/JsonValidationService');
const { runBusinessRules } = require('../services/BusinessRuleEngine');
const { analyzeCoverage } = require('../services/CoverageAnalysisService');
const { generateReport } = require('../services/ReportGenerationService');
const rateLimit = require('express-rate-limit');

const aiLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20, // Limit each User to 20 AI processing requests per window
  keyGenerator: (req, res) => req.user ? req.user.id : 'unauthenticated',
  message: { message: 'AI processing limit reached. Please try again later.' }
});

/**
 * Helper: Record a pipeline stage result
 */
function recordStage(stages, name, startTime, status, error = null) {
  stages.push({
    name,
    status,
    durationMs: Date.now() - startTime,
    error: error ? error.toString().substring(0, 500) : null,
  });
}

// =====================================================
// @route   POST /api/analysis/start
// @desc    Run the full 11-stage AI analysis pipeline
// @access  Private
// =====================================================
router.post('/start', auth, aiLimiter, async (req, res) => {
  const pipelineStart = Date.now();
  const stages = [];
  let report = null;
  const abortController = new AbortController();
  let isClientConnected = true;
  
  req.on('close', () => {
    isClientConnected = false;
    logger.warn(`[Analysis] Client disconnected before completion. Aborting pipeline.`);
    abortController.abort();
  });

  try {
    const { prescriptionPath, policyPath } = req.body;

    // ─── STAGE 1: Validate Input ───
    if (!prescriptionPath || !policyPath) {
      return res.status(400).json({
        success: false,
        message: 'Prescription file ID and Policy file ID are required.',
      });
    }

    const mongoose = require('mongoose');
    if (!mongoose.Types.ObjectId.isValid(prescriptionPath) || !mongoose.Types.ObjectId.isValid(policyPath)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid file ID format provided.',
      });
    }

    // --- IDEMPOTENCY GUARD ---
    // Check if an analysis for these exact files is already in progress or completed.
    const AnalysisReport = require('../models/AnalysisReport');
    const existingReport = await AnalysisReport.findOne({
      policyId: policyPath,
      prescriptionId: prescriptionPath,
      status: { $in: ['pending', 'extracting', 'analyzing', 'completed'] }
    });

    if (existingReport) {
      if (existingReport.status === 'completed') {
        return res.json({
          success: true,
          reportId: existingReport._id,
          policyJson: existingReport.policyJson,
          prescriptionJson: existingReport.prescriptionJson,
          businessRules: existingReport.businessRules,
          coverageAnalysis: existingReport.coverageAnalysis,
          confidenceScore: existingReport.confidenceScore,
          overallStatus: existingReport.overallStatus,
          summaryText: existingReport.summaryText,
          comparison: existingReport.comparison,
          processingTimeMs: existingReport.processingTimeMs,
          stages: existingReport.stages,
        });
      } else {
        // HTTP 409 Conflict: Already processing.
        return res.status(409).json({ success: false, message: 'Analysis is already in progress.' });
      }
    }

    // Report will only be created and saved in Stage 10 if successful

    // ─── STAGE 2: Extract Documents ───
    let stageStart = Date.now();
    let prescriptionExtraction, policyExtraction;
    try {
      // Run sequentially to prevent async pdf-parse rejections from escaping
      prescriptionExtraction = await extractDocument(prescriptionPath);
      policyExtraction = await extractDocument(policyPath);
      recordStage(stages, 'Document Extraction', stageStart, 'success');
    } catch (err) {
      recordStage(stages, 'Document Extraction', stageStart, 'failed', err.message);
      throw new Error(`Document Extraction Failed: ${err.message}`);
    }

    // ─── STAGE 3: Clean Text ───
    stageStart = Date.now();
    const cleanedPrescriptionText = cleanText(prescriptionExtraction.text);
    const cleanedPolicyText = cleanText(policyExtraction.text);
    recordStage(stages, 'Text Cleaning', stageStart, 'success');

    

    // Text cleaning complete (saved in memory)

    // ─── STAGE 4: Extract Policy JSON (AI) ───
    stageStart = Date.now();
    let policyJson;
    let policyExtractionResult;
    try {
      policyExtractionResult = await extractPolicyJson(cleanedPolicyText, abortController.signal);
      policyJson = policyExtractionResult.extractedJson;
      recordStage(stages, 'Policy Extraction (System)', stageStart, 'success');
    } catch (err) {
      recordStage(stages, 'Policy Extraction (System)', stageStart, 'failed', err.message);
      throw new Error(`Policy Extraction Failed: ${err.message}`);
    }

    // ─── STAGE 5: Extract Prescription JSON (AI) ───
    stageStart = Date.now();
    let prescriptionJson;
    let prescriptionExtractionResult;
    try {
      prescriptionExtractionResult = await extractPrescriptionJson(cleanedPrescriptionText, abortController.signal);
      prescriptionJson = prescriptionExtractionResult.extractedJson;
      recordStage(stages, 'Prescription Extraction (System)', stageStart, 'success');
    } catch (err) {
      recordStage(stages, 'Prescription Extraction (System)', stageStart, 'failed', err.message);
      throw new Error(`Prescription Extraction Failed: ${err.message}`);
    }

    // ─── STAGE 6: Validate JSON ───
    stageStart = Date.now();
    const validation = validateExtractedJson(policyJson, prescriptionJson);
    if (!validation.isValid) {
      // We no longer retry here because the aiClient inside the extraction services already retries internally.
      // We just use the best-effort data.
      policyJson = validation.validatedPolicyJson || policyJson;
      prescriptionJson = validation.validatedPrescriptionJson || prescriptionJson;
    } else {
      policyJson = validation.validatedPolicyJson;
      prescriptionJson = validation.validatedPrescriptionJson;
    }
    recordStage(stages, 'JSON Validation', stageStart, 'success');

    // ─── STAGE 7: Business Rule Engine ───
    stageStart = Date.now();
    const businessRuleResults = runBusinessRules(policyJson, prescriptionJson);
    recordStage(stages, 'Business Rules', stageStart, 'success');
    if (businessRuleResults.blockers.length > 0) {
    }
    if (businessRuleResults.warnings.length > 0) {
    }

    // ─── STAGE 8: AI Coverage Analysis ───
    stageStart = Date.now();
    let coverageAnalysis;
    try {
      coverageAnalysis = await analyzeCoverage(cleanedPolicyText, cleanedPrescriptionText, businessRuleResults, prescriptionJson);
      recordStage(stages, 'Coverage Analysis (System)', stageStart, 'success');
    } catch (err) {
      recordStage(stages, 'Coverage Analysis (System)', stageStart, 'failed', err.message);
      throw new Error(`Coverage Analysis Failed: ${err.message}`);
    }

    // ─── STAGE 9: Generate Report ───
    stageStart = Date.now();
    const processingTimeMs = Date.now() - pipelineStart;
    const finalReport = generateReport(
      policyJson,
      prescriptionJson,
      businessRuleResults,
      coverageAnalysis,
      processingTimeMs
    );
    recordStage(stages, 'Report Generation', stageStart, 'success');

    // ─── STAGE 10: Store in MongoDB ───
    stageStart = Date.now();
    report = new AnalysisReport({
      userId: req.user.id,
      createdBy: req.user.id,
      policyId: policyPath,
      prescriptionId: prescriptionPath,
      status: 'completed',
      policyText: cleanedPolicyText.substring(0, 10000), // Store first 10K for audit
      prescriptionText: cleanedPrescriptionText.substring(0, 10000),
      policyJson: policyJson,
      prescriptionJson: prescriptionJson,
      businessRules: businessRuleResults,
      coverageAnalysis: coverageAnalysis,
      documentValidity: finalReport.documentValidity || coverageAnalysis.documentValidity,
      confidenceScore: finalReport.confidenceScore,
      overallStatus: finalReport.overallStatus || finalReport.coverageStatus,
      overallConfidence: finalReport.overallConfidence !== undefined ? finalReport.overallConfidence : finalReport.confidenceScore,
      summary: finalReport.summary || finalReport.summaryText,
      summaryText: finalReport.summaryText,
      comparison: finalReport.comparison,
      processingTimeMs: processingTimeMs,
      stages: stages,
      analysisVersion: '2.0.0'
    });

    await report.save();
    recordStage(stages, 'MongoDB Storage', stageStart, 'success');

    await ActivityLog.create({
      userId: req.user.id,
      action: 'Generated System analysis report',
      entityType: 'AnalysisReport',
      entityId: report._id,
    });

    // ─── STAGE 11: Return Response ───
    const totalTime = Date.now() - pipelineStart;

    res.json({
      success: true,
      reportId: report._id,
      policyJson,
      prescriptionJson,
      businessRules: businessRuleResults,
      coverageAnalysis,
      // Backward compatibility fields
      confidenceScore: finalReport.confidenceScore,
      overallStatus: finalReport.coverageStatus,
      summaryText: finalReport.summaryText,
      comparison: finalReport.comparison,
      processingTimeMs: totalTime,
      stages,
    });

  } catch (err) {
    const totalTime = Date.now() - pipelineStart;
    logger.error(`[Analysis Pipeline] FAILED after ${totalTime}ms: ${err.message}`, { stack: err.stack });

    // We deliberately DO NOT save failed reports to the DB (All-or-Nothing storage rule).

    res.status(err.statusCode || 500).json({
      success: false,
      message: err.message,
      failedAtStage: stages.length > 0 ? stages[stages.length - 1].name : 'Initialization',
      processingTimeMs: totalTime,
      stages,
    });
  }
});

// =====================================================
// @route   GET /api/analysis
// @desc    Get all analysis reports for user (paginated)
// @access  Private
// =====================================================
router.get('/', auth, async (req, res) => {
  try {
    const { page = 1, limit = 10, search = '' } = req.query;

    const escapeRegex = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const safeSearch = search ? escapeRegex(search) : '';

    const query = { userId: req.user.id };
    if (safeSearch) {
      const orConditions = [
        { overallStatus: { $regex: safeSearch, $options: 'i' } },
        { summaryText: { $regex: safeSearch, $options: 'i' } },
      ];

      const mongoose = require('mongoose');
      if (mongoose.Types.ObjectId.isValid(search)) {
        orConditions.push({ _id: search });
      }

      orConditions.push({
        $expr: {
          $regexMatch: {
            input: { $dateToString: { format: "%Y-%m-%d %H:%M", date: "$createdAt" } },
            regex: safeSearch,
            options: "i"
          }
        }
      });

      query.$or = orConditions;
    }

    const parsedLimit = parseInt(limit, 10) || 10;
    const safeLimit = Math.min(Math.max(parsedLimit, 1), 100);

    const options = {
      page: parseInt(page, 10),
      limit: safeLimit,
      sort: { createdAt: -1 },
      select: '-policyText -prescriptionText', // Exclude large audit fields from list
    };

    const reports = await AnalysisReport.paginate(query, options);
    res.json(reports);
  } catch (err) {
    logger.error(`[GET /api/analysis] ${err.message}`, { stack: err.stack });
    res.status(500).send('Server Error');
  }
});

// =====================================================
// @route   GET /api/analysis/:id
// @desc    Get full analysis report by ID
// @access  Private
// =====================================================
router.get('/:id', auth, async (req, res) => {
  try {
    const report = await AnalysisReport.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!report) {
      return res.status(404).json({ message: 'Analysis report not found' });
    }

    res.json(report);
  } catch (err) {
    logger.error(`[GET /api/analysis/:id] ${err.message}`, { stack: err.stack });
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Analysis report not found' });
    }
    res.status(500).send('Server Error');
  }
});

// =====================================================
// @route   GET /api/analysis/:id/policy-json
// @desc    Get extracted policy JSON for a report
// @access  Private
// =====================================================
router.get('/:id/policy-json', auth, async (req, res) => {
  try {
    const report = await AnalysisReport.findOne(
      { _id: req.params.id, userId: req.user.id },
      'policyJson'
    );
    if (!report) {
      return res.status(404).json({ message: 'Analysis report not found' });
    }
    res.json(report.policyJson || {});
  } catch (err) {
    logger.error(`[GET /api/analysis/:id/policy-json] ${err.message}`, { stack: err.stack });
    res.status(500).send('Server Error');
  }
});

// =====================================================
// @route   GET /api/analysis/:id/prescription-json
// @desc    Get extracted prescription JSON for a report
// @access  Private
// =====================================================
router.get('/:id/prescription-json', auth, async (req, res) => {
  try {
    const report = await AnalysisReport.findOne(
      { _id: req.params.id, userId: req.user.id },
      'prescriptionJson'
    );
    if (!report) {
      return res.status(404).json({ message: 'Analysis report not found' });
    }
    res.json(report.prescriptionJson || {});
  } catch (err) {
    logger.error(`[GET /api/analysis/:id/prescription-json] ${err.message}`, { stack: err.stack });
    res.status(500).send('Server Error');
  }
});


// =====================================================
// @route   DELETE /api/analysis/:id
// @desc    Delete a specific analysis report
// @access  Private
// =====================================================
router.delete('/:id', auth, async (req, res) => {
  try {
    const report = await AnalysisReport.findOneAndDelete({ _id: req.params.id, userId: req.user.id });
    if (!report) {
      return res.status(404).json({ message: 'Analysis report not found or not authorized.' });
    }
    res.json({ message: 'Analysis report deleted successfully.' });
  } catch (err) {
    logger.error(`[DELETE /api/analysis/:id] ${err.message}`, { stack: err.stack });
    res.status(500).send('Server Error');
  }
});

module.exports = router;
