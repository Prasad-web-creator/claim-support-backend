const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // Limit each IP to 20 auth requests per window
  message: { message: 'Too many authentication attempts, please try again later.' }
});

// @route   POST /api/auth/register
// @desc    Register a user
// @access  Public
router.post('/register', authLimiter, authController.register);

// @route   POST /api/auth/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', authLimiter, authController.login);

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
const auth = require('../middleware/authMiddleware');
router.get('/me', auth, authController.getMe);

// @route   POST /api/auth/refresh-token
// @desc    Refresh access token
// @access  Public
router.post('/refresh-token', authLimiter, authController.refresh);

// @route   POST /api/auth/logout
// @desc    Logout user (invalidate refresh token)
// @access  Private
router.post('/logout', auth, authController.logout);

module.exports = router;
