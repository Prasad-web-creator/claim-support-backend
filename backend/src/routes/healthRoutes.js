const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');

// @route   GET /api/health
// @desc    Liveness probe (Basic app health)
router.get('/', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date() });
});

// @route   GET /api/health/ready
// @desc    Readiness probe (Database health)
router.get('/ready', async (req, res) => {
  try {
    const mongoStatus = mongoose.connection.readyState === 1 ? 'UP' : 'DOWN';
    
    const isReady = mongoStatus === 'UP';

    res.status(isReady ? 200 : 503).json({
      status: isReady ? 'UP' : 'DOWN',
      checks: {
        mongodb: mongoStatus,
      },
      timestamp: new Date()
    });
  } catch (error) {
    res.status(503).json({ status: 'DOWN', error: error.message });
  }
});

// @route   GET /api/health/metrics
// @desc    Basic memory/uptime metrics
router.get('/metrics', (req, res) => {
  const memoryUsage = process.memoryUsage();
  res.status(200).json({
    uptime: process.uptime(),
    memory: {
      rss: `${Math.round(memoryUsage.rss / 1024 / 1024)} MB`,
      heapTotal: `${Math.round(memoryUsage.heapTotal / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(memoryUsage.heapUsed / 1024 / 1024)} MB`,
    },
    timestamp: new Date()
  });
});

module.exports = router;
