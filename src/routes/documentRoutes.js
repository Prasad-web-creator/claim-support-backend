/**
 * @fileoverview Document Processing Route
 *
 * POST /api/documents/process
 *
 * A new unified endpoint for multi-format intelligent document processing.
 * Supports: PDF, PNG, JPG, JPEG, DOCX
 *
 * This endpoint is completely independent of the existing /api/analysis/start pipeline.
 *
 * Flow:
 *   1. Accept file upload (multer memory storage)
 *   2. Validate file type and size
 *   3. Process document (OCR, classification, structured extraction)
 *   4. Return structured JSON
 */

const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const multer = require('multer');
const auth = require('../middleware/authMiddleware');
const { processDocument, ALLOWED_EXTENSIONS } = require('../services/MultiFormatExtractionService');

// ─── Multer Configuration ─────────────────────────────────────────────────────

const MAX_FILE_SIZE_MB = 20;
const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;

const path = require('path');
const fs = require('fs');
const TempDiskAndHashStorage = require('../middleware/TempDiskAndHashStorage');

const upload = multer({
  storage: TempDiskAndHashStorage({}),
  limits: {
    fileSize: MAX_FILE_SIZE_BYTES,
  },
  fileFilter: (req, file, cb) => {
    const path = require('path');
    const ext = path.extname(file.originalname).toLowerCase();
    if (ALLOWED_EXTENSIONS.has(ext)) {
      cb(null, true);
    } else {
      cb(
        new Error(
          `Unsupported file type "${ext}". Allowed: ${[...ALLOWED_EXTENSIONS].join(', ')}`
        ),
        false
      );
    }
  },
});

// ─── Route ────────────────────────────────────────────────────────────────────

/**
 * POST /api/documents/process
 *
 * Request: multipart/form-data
 *   - file: required (PDF, PNG, JPG, JPEG, DOCX)
 *
 * Response: JSON
 *   {
 *     success: true,
 *     documentType, confidence, metadata,
 *     extractedData, rawText, warnings, missingFields
 *   }
 */
router.post('/process', auth, (req, res, next) => {
  upload.single('file')(req, res, (uploadErr) => {
    if (uploadErr) {
      if (uploadErr.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          success: false,
          message: `File too large. Maximum allowed size is ${MAX_FILE_SIZE_MB}MB.`,
        });
      }
      return res.status(400).json({
        success: false,
        message: uploadErr.message || 'File upload failed.',
      });
    }
    next();
  });
}, async (req, res) => {
  const requestStart = Date.now();

  try {
    // ── Validate Request ───────────────────────────────────────────────────
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded. Please attach a file with the key "file".',
      });
    }

    const { path: filePath, originalname, mimetype } = req.file;

    if (!filePath || !fs.existsSync(filePath)) {
      return res.status(400).json({
        success: false,
        message: 'Uploaded file is empty or corrupted.',
      });
    }
    
    // Read buffer for processing (this could be optimized later, but upload is now memory-safe)
    const buffer = fs.readFileSync(filePath);



    // ── Process Document ───────────────────────────────────────────────────
    const result = await processDocument(buffer, originalname, mimetype);

    const totalTimeMs = Date.now() - requestStart;



    if (req.file && req.file.path) {
      try { fs.unlinkSync(req.file.path); } catch(e) {}
    }

    return res.status(200).json({
      success: true,
      ...result,
    });

  } catch (error) {
    if (req.file && req.file.path) {
      try { fs.unlinkSync(req.file.path); } catch(e) {}
    }
    const totalTimeMs = Date.now() - requestStart;
    logger.error(`[POST /api/documents/process] FAILED after ${totalTimeMs}ms: ${error.message}`, { stack: error.stack });

    // Handle known error types with friendly messages
    if (error.message.startsWith('VALIDATION_ERROR:')) {
      return res.status(400).json({
        success: false,
        message: error.message.replace('VALIDATION_ERROR: ', ''),
      });
    }

    if (error.message.startsWith('DOCX_EXTRACTION_FAILED:')) {
      return res.status(422).json({
        success: false,
        message: 'Failed to extract content from the DOCX file. The file may be corrupted or password-protected.',
        detail: error.message.replace('DOCX_EXTRACTION_FAILED: ', ''),
      });
    }

    if (error.message.includes('password') || error.message.toLowerCase().includes('encrypted')) {
      return res.status(422).json({
        success: false,
        message: 'The document appears to be password-protected. Please remove the password and try again.',
      });
    }

    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while processing the document.',
      detail: process.env.NODE_ENV !== 'production' ? error.message : undefined,
    });
  }
});

module.exports = router;
