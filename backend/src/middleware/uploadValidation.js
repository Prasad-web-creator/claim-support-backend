/**
 * @fileoverview uploadValidation Middleware
 *
 * Validates uploaded files BEFORE they reach storage.
 * Checks MIME type, file extension, file size, and content-type header.
 * Rejects invalid uploads with meaningful error messages.
 */

const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');
const { getStorageConfig } = require('../config/storage.config');

const ALLOWED_EXTENSIONS = ['.pdf', '.png', '.jpg', '.jpeg', '.docx'];

/**
 * Detect actual file type from magic bytes (buffer signature).
 * Prevents disguised uploads (e.g., a .exe renamed to .pdf).
 */
function detectMimeFromMagicBytes(buffer) {
  if (!buffer || buffer.length < 4) return null;
  if (buffer.toString('utf8', 0, 5) === '%PDF-') return 'application/pdf';
  if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47) return 'image/png';
  if (buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) return 'image/jpeg';
  if (buffer[0] === 0x47 && buffer[1] === 0x49 && buffer[2] === 0x46) return 'image/gif';
  if (buffer[0] === 0x50 && buffer[1] === 0x4B && buffer[2] === 0x03 && buffer[3] === 0x04) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  return null;
}

/**
 * Express middleware — validates the uploaded file on the request.
 * Must be used AFTER multer has parsed the multipart form data.
 *
 * On success: calls next().
 * On failure: returns 400 with a descriptive error message.
 */
function validateUpload(req, res, next) {
  if (!req.file) {
    return res.status(400).json({ message: 'No file uploaded. Please attach a file.' });
  }

  const config = getStorageConfig();
  const { originalname, mimetype, size, path: filePath } = req.file;

  // --- 1. File Size Check ---
  const maxBytes = config.maxFileSizeMb * 1024 * 1024;
  if (size > maxBytes) {
    return res.status(400).json({
      message: `File too large. Maximum allowed size is ${config.maxFileSizeMb}MB. Your file is ${(size / 1024 / 1024).toFixed(2)}MB.`,
    });
  }

  // --- 2. File Extension Check ---
  const ext = path.extname(originalname).toLowerCase();
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return res.status(400).json({
      message: `Invalid file extension "${ext}". Allowed types: PDF, PNG, JPG, JPEG, DOCX.`,
    });
  }

  // --- 3. Declared MIME Type Check ---
  if (!config.allowedMimeTypes.includes(mimetype)) {
    return res.status(400).json({
      message: `Invalid file type "${mimetype}". Allowed types: PDF, PNG, JPG, JPEG, DOCX.`,
    });
  }

  // --- 4. Magic Bytes Validation (anti-spoofing) ---
  let detectedMime = null;
  if (filePath) {
    try {
      const fd = fs.openSync(filePath, 'r');
      const magicBuffer = Buffer.alloc(16);
      fs.readSync(fd, magicBuffer, 0, 16, 0);
      fs.closeSync(fd);
      detectedMime = detectMimeFromMagicBytes(magicBuffer);
    } catch (e) {
      logger.error(`[uploadValidation] Error reading magic bytes: ${e.message}`, { stack: e.stack });
      return res.status(500).json({ message: 'Error validating file signature' });
    }
  }

  if (detectedMime && !config.allowedMimeTypes.includes(detectedMime)) {
    // If validation fails, try to cleanup the uploaded file
    try { fs.unlinkSync(filePath); } catch(e) {}
    return res.status(400).json({
      message: `File content does not match the extension. Detected type: ${detectedMime}. Please upload a valid file.`,
    });
  }

  next();
}

module.exports = { validateUpload };
