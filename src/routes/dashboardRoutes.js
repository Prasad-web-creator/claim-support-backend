const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const logger = require('../utils/logger');
const Policy = require('../models/Policy');
const Prescription = require('../models/Prescription');
const AnalysisReport = require('../models/AnalysisReport');
const ActivityLog = require('../models/ActivityLog');

router.use(auth);

router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const baseQuery = { userId, isDeleted: false };

    const [
      totalPolicies,
      totalPrescriptions,
      totalAnalysisReports,
      recentActivities,
      recentAnalyses,
    ] = await Promise.all([
      Policy.countDocuments(baseQuery),
      Prescription.countDocuments(baseQuery),
      AnalysisReport.countDocuments(baseQuery),
      ActivityLog.find(baseQuery).sort({ createdAt: -1 }).select('action entityType entityId createdAt').limit(5),
      AnalysisReport.find(baseQuery).sort({ createdAt: -1 }).select('documentType status confidenceScore overallStatus processingTimeMs createdAt').limit(5),
    ]);

    res.json({
      totalPolicies,
      totalPrescriptions,
      totalAnalysisReports,
      recentActivities,
      recentAnalyses,
    });
  } catch (error) {
    logger.error(`[GET /api/dashboard] ${error.message}`, { stack: error.stack });
    res.status(500).json({ message: 'Error fetching dashboard stats' });
  }
});

module.exports = router;
