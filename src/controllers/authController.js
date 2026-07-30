const User = require('../models/User');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const logger = require('../utils/logger');

// Register a new user
exports.register = async (req, res) => {
  try {
    const { name, email, phone, otp } = req.body;

    if (!name || !email || !phone) {
      return res.status(400).json({ message: 'Name, email, and phone are required' });
    }

    const safePayload = { name, email, phone };

    if (String(otp) !== '1234') {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    // Check if user already exists
    let existingUser = await User.findOne({ $or: [{ phone }, { email }] });
    if (existingUser) {
      if (existingUser.email === email) {
        return res.status(400).json({ message: 'Email already exists' });
      }
      return res.status(400).json({ message: 'Phone number already registered' });
    }

    // Create new user
    let user = new User({
      name,
      email,
      phone,
    });

    await user.save();

    // Create JWT Payload
    const payload = {
      user: {
        id: user.id,
      },
    };

    // Sign Token
      const accessToken = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '15m' });
      const refreshToken = crypto.randomBytes(40).toString('hex');
      const refreshTokenExpiry = new Date();
      refreshTokenExpiry.setDate(refreshTokenExpiry.getDate() + 7); // 7 days
      
      user.refreshToken = refreshToken;
      user.refreshTokenExpiry = refreshTokenExpiry;
      await user.save();

      res.status(201).json({ 
        token: accessToken, 
        refreshToken,
        user: { id: user.id, name: user.name, email: user.email } 
      });
  } catch (err) {
    logger.error(`[authController.register] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server error' });
  }
};

// Login user
exports.login = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone) {
      return res.status(400).json({ message: 'Phone number is required' });
    }

    if (String(otp) !== '1234') {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    // Check if user exists
    let user = await User.findOne({ phone });

    if (!user) {
      return res.status(400).json({ message: 'User not found. Please register first.' });
    }

    // Create JWT Payload
    const payload = {
      user: {
        id: user.id,
      },
    };

    // Sign Token
    const accessToken = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '15m' });
    const refreshToken = crypto.randomBytes(40).toString('hex');
    const refreshTokenExpiry = new Date();
    refreshTokenExpiry.setDate(refreshTokenExpiry.getDate() + 7); // 7 days
    
    user.refreshToken = refreshToken;
    user.refreshTokenExpiry = refreshTokenExpiry;
    await user.save();

    res.json({ 
      token: accessToken, 
      refreshToken,
      user: { id: user.id, name: user.name, email: user.email } 
    });
  } catch (err) {
    logger.error(`[authController.login] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server error' });
  }
};

// Get current user
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (err) {
    logger.error(`[authController.getUser] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server Error' });
  }
};

// Refresh token
exports.refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(401).json({ message: 'Refresh token is required' });
    }

    const user = await User.findOne({ refreshToken });
    if (!user) {
      return res.status(403).json({ message: 'Invalid refresh token' });
    }

    if (user.refreshTokenExpiry && user.refreshTokenExpiry < new Date()) {
      user.refreshToken = null;
      user.refreshTokenExpiry = null;
      await user.save();
      return res.status(403).json({ message: 'Refresh token expired' });
    }

    const payload = { user: { id: user.id } };
    const accessToken = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '15m' });

    // Rotate refresh token
    const newRefreshToken = crypto.randomBytes(40).toString('hex');
    const newRefreshTokenExpiry = new Date();
    newRefreshTokenExpiry.setDate(newRefreshTokenExpiry.getDate() + 7);
    
    user.refreshToken = newRefreshToken;
    user.refreshTokenExpiry = newRefreshTokenExpiry;
    await user.save();

    res.json({ token: accessToken, refreshToken: newRefreshToken });
  } catch (err) {
    logger.error(`[authController.refreshToken] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server error' });
  }
};

// Logout user
exports.logout = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (user) {
      user.refreshToken = null;
      user.refreshTokenExpiry = null;
      await user.save();
    }
    res.json({ message: 'Logged out successfully' });
  } catch (err) {
    logger.error(`[authController.logout] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server error' });
  }
};
