const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const IORedis = require('ioredis');

const redisClient = new IORedis(process.env.REDIS_URL || 'redis://127.0.0.1:6379', {
  maxRetriesPerRequest: 1, // Don't hang health checks
});

// @route   GET /api/health
// @desc    Liveness probe (Basic app health)
router.get('/', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date() });
});

// @route   GET /api/health/ready
// @desc    Readiness probe (Database & Redis health)
router.get('/ready', async (req, res) => {
  try {
    const mongoStatus = mongoose.connection.readyState === 1 ? 'UP' : 'DOWN';
    
    let redisStatus = 'DOWN';
    try {
      await redisClient.ping();
      redisStatus = 'UP';
    } catch (err) {
      redisStatus = 'DOWN';
    }

    const isReady = mongoStatus === 'UP' && redisStatus === 'UP';

    res.status(isReady ? 200 : 503).json({
      status: isReady ? 'UP' : 'DOWN',
      checks: {
        mongodb: mongoStatus,
        redis: redisStatus,
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
