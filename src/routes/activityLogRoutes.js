const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const auth = require('../middleware/authMiddleware');
const ActivityLog = require('../models/ActivityLog');

router.use(auth);

// @route   GET /api/logs
// @desc    Get all activity logs for a user (paginated)
// @access  Private
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const parsedLimit = parseInt(req.query.limit, 10) || 20;
    const limit = Math.min(Math.max(parsedLimit, 1), 100);
    const search = req.query.search || '';

    const escapeRegex = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const safeSearch = search ? escapeRegex(search) : '';

    const query = { userId: req.user.id };

    if (safeSearch) {
      const orConditions = [
        { action: { $regex: safeSearch, $options: 'i' } },
        { entityType: { $regex: safeSearch, $options: 'i' } },
      ];

      const mongoose = require('mongoose');
      if (mongoose.Types.ObjectId.isValid(search)) {
        orConditions.push({ _id: search });
        orConditions.push({ entityId: search });
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

    const options = {
      page,
      limit,
      sort: { createdAt: -1 },
    };

    const result = await ActivityLog.paginate(query, options);

    res.json(result);
  } catch (error) {
    logger.error(`[GET /api/activity] ${error.message}`, { stack: error.stack });
    res.status(500).json({ message: 'Error fetching activity logs' });
  }
});

module.exports = router;
