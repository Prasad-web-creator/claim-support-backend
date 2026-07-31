require('dotenv').config();
const logger = require('./src/utils/logger');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { GridFSBucket } = require('mongodb');
const authMiddleware = require('./src/middleware/authMiddleware');

const requiredEnvVars = ['JWT_SECRET', 'GROQ_API_KEY', 'GEMINI_API_KEY', 'MONGODB_URI'];
if (process.env.NODE_ENV === 'production') {
  requiredEnvVars.push('ALLOWED_ORIGINS');
}

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    logger.error(`[FATAL] Missing required environment variable: ${envVar}`);
    process.exit(1);
  }
}
// Prevent Node.js from crashing ungracefully without logs
process.on('uncaughtException', (err) => {
  logger.error(`[FATAL] Uncaught Exception: ${err.message}`, { stack: err.stack });
  process.exit(1); 
});

// Prevent Node.js from crashing on unhandled async rejections (e.g. pdf-parse internals)
process.on('unhandledRejection', (reason, promise) => {
  logger.error(`⚠️ Unhandled Promise Rejection (caught globally): ${reason?.message || reason}`);
});

const app = express();
const PORT = process.env.PORT;
const helmet = require('helmet');
const compression = require('compression');

// Trust Proxy for Rate Limiter
app.set('trust proxy', 1);

// Security Headers
app.use(helmet());

// Compress Responses
app.use(compression());

const rateLimit = require('express-rate-limit');

// Global Rate Limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per `window`
  message: { message: 'Too many requests from this IP, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(globalLimiter);

const allowedOrigins = process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['http://localhost:3000'];

const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    if (process.env.NODE_ENV !== 'production') return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
};
app.use(cors(corsOptions));
// Limit JSON payloads and urlencoded payloads to 1MB to prevent DoS
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ limit: '1mb', extended: true }));


let gfsBucket;

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/claimsupport')
  .then(() => {
    gfsBucket = new GridFSBucket(mongoose.connection.db, {
      bucketName: 'fs'
    });
    logger.info('MongoDB connected');
  })
  .catch((err) => logger.error(`MongoDB connection error: ${err.message}`, { stack: err.stack }));

// Routes
const authRoutes = require('./src/routes/authRoutes');
const uploadRoutes = require('./src/routes/uploadRoutes');
const analysisRoutes = require('./src/routes/analysisRoutes');
const policyRoutes = require('./src/routes/policyRoutes');
const prescriptionRoutes = require('./src/routes/prescriptionRoutes');
const dashboardRoutes = require('./src/routes/dashboardRoutes');
const activityLogRoutes = require('./src/routes/activityLogRoutes');
const documentRoutes = require('./src/routes/documentRoutes');

const healthRoutes = require('./src/routes/healthRoutes');

app.use('/api/auth', authRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/analysis', analysisRoutes);
app.use('/api/policies', policyRoutes);
app.use('/api/prescriptions', prescriptionRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/logs', activityLogRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/health', healthRoutes);

// Fetch files from GridFS
app.get('/api/files/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid File ID' });
    }
    const fileId = new mongoose.Types.ObjectId(req.params.id);
    const files = await mongoose.connection.db.collection('fs.files').find({ _id: fileId }).toArray();
    if (!files || files.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    const file = files[0];
    res.set('Content-Type', file.contentType || 'application/octet-stream');
    const readStream = gfsBucket.openDownloadStream(fileId);
    readStream.pipe(res);
  } catch (error) {
    logger.error(`Error retrieving file: ${error.message}`, { stack: error.stack });
    res.status(500).json({ message: 'Error retrieving file' });
  }
});

app.get('/', (req, res) => {
  res.send('Claim Support API is running');
});

// Ignore favicon requests from browsers to prevent 404 errors in logs
app.get('/favicon.ico', (req, res) => res.status(204).end());

// Global Express Error Handler
app.use((err, req, res, next) => {
  logger.error(`[Express Error] ${err.message}`, { stack: err.stack });
  res.status(err.status || 500).json({ 
    success: false, 
    message: process.env.NODE_ENV === 'production' ? 'Internal Server Error' : err.message 
  });
});

const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server is running on ${PORT}`);
});
server.timeout = 180000; // 3 minutes for multi-stage AI processing
server.headersTimeout = 190000;
