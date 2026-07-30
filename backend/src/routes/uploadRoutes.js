const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const multer = require('multer');
const path = require('path');
const auth = require('../middleware/authMiddleware');
const mongoose = require('mongoose');
const { GridFSBucket } = require('mongodb');
const crypto = require('crypto');

const { validateUpload } = require('../middleware/uploadValidation');
const fs = require('fs');

const TempDiskAndHashStorage = require('../middleware/TempDiskAndHashStorage');
const { validateFileStructure } = require('../middleware/advancedFileValidator');
const ScannerService = require('../services/ScannerService');

const uploadDir = path.join(__dirname, '../../uploads/');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Use custom storage engine that hashes while streaming to disk
const storage = TempDiskAndHashStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  }
});
const upload = multer({ 
  storage: storage,
  limits: { fileSize: 20 * 1024 * 1024 } // 20MB limit for multipart uploads
});

// Timeout Middleware (60 seconds)
const uploadTimeout = (req, res, next) => {
  req.setTimeout(60000, () => {
    req.destroy(new Error('Upload timeout'));
  });
  next();
};

// @route   POST /api/upload
// @desc    Upload a file
// @access  Private
router.post('/', auth, uploadTimeout, upload.single('file'), validateUpload, async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No file uploaded' });
  }

  const { size, path: filePath, sha256, originalname, mimetype } = req.file;
  
  // Cleanup helper
  const cleanupTempFile = () => {
    try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (e) {}
  };

  try {
    // 1. Virus Scan Abstraction
    await ScannerService.scanUploadedFile(filePath);

    // 2. Advanced Structural Validation
    await validateFileStructure(filePath, mimetype);

    // 3. GridFS Duplicate Detection
    const gfsBucket = new GridFSBucket(mongoose.connection.db, { bucketName: 'fs' });
    const existingFile = await gfsBucket.find({ 'metadata.sha256': sha256, 'metadata.userId': req.user.id }).toArray();
    
    if (existingFile && existingFile.length > 0) {
      cleanupTempFile();
      return res.status(200).json({
        message: 'File already exists',
        fileId: existingFile[0]._id,
        filename: existingFile[0].filename,
        originalName: existingFile[0].metadata.originalName,
        contentType: existingFile[0].metadata.mimeType,
        size: existingFile[0].metadata.uploadedLength
      });
    }

    // 4. Stream to GridFS
    const filename = req.file.filename;
    const uploadStream = gfsBucket.openUploadStream(filename, {
      contentType: mimetype,
      metadata: {
        originalName: originalname,
        mimeType: mimetype,
        sha256: sha256,
        uploadedLength: size,
        uploadDate: new Date(),
        userId: req.user.id
      }
    });

    const uploadRs = fs.createReadStream(filePath);
    
    // Robust Error Handling for Client Disconnect or Network Failures
    const abortUpload = async () => {
      uploadRs.destroy();
      uploadStream.destroy(new Error('Upload aborted'));
      cleanupTempFile();
      try { await gfsBucket.delete(uploadStream.id); } catch(e) {}
    };

    req.on('aborted', abortUpload);
    req.on('close', () => {
      if (!uploadStream.destroyed && !uploadStream.writableEnded) {
        abortUpload();
      }
    });

    uploadRs.pipe(uploadStream);

    uploadStream.on('finish', async () => {
      try {
        try {
          cleanupTempFile();
        } catch (cleanupErr) {
           logger.warn(`[Upload Cleanup Warning] Failed to delete temp file ${filePath}: ${cleanupErr.message}`);
        }

        const storedFiles = await gfsBucket.find({ _id: uploadStream.id }).toArray();
        if (!storedFiles || storedFiles.length === 0 || storedFiles[0].length !== size) {
          try { await gfsBucket.delete(uploadStream.id); } catch(e) {}
          return res.status(500).json({ message: 'STORAGE_CORRUPTION_DETECTED' });
        }

        res.status(200).json({
            message: 'File uploaded successfully',
            fileId: uploadStream.id,
            filename: filename,
            originalName: originalname,
            contentType: mimetype,
            size: size
        });
      } catch (verifyErr) {
          logger.error(`[Upload Verification Error] FileID: ${uploadStream.id} - ${verifyErr.message}`, { stack: verifyErr.stack });
          try { await gfsBucket.delete(uploadStream.id); } catch(e) {}
          if (!res.headersSent) res.status(500).json({ message: 'Error verifying file in GridFS' });
      }
    });

    uploadStream.on('error', async (error) => {
      logger.error(`[Upload Error] ${error.message}`, { stack: error.stack });
      await abortUpload();
      if (!res.headersSent) res.status(500).json({ message: 'Error uploading file to storage' });
    });

  } catch (err) {
    logger.error(`[Unhandled Upload Error] ${err.message}`, { stack: err.stack });
    cleanupTempFile();
    
    // Convert known errors to proper status codes
    if (err.message.includes('timeout')) return res.status(408).json({ message: 'Request Timeout' });
    if (err.message.includes('Structural validation failed')) return res.status(422).json({ message: err.message });
    if (err.message.includes('Infected')) return res.status(403).json({ message: 'Malware detected' });
    
    if (!res.headersSent) res.status(500).json({ message: 'Server error during upload process' });
  }
});

// @route   GET /api/upload/:id
// @desc    Get file stream
// @access  Private
router.get('/:id', auth, async (req, res) => {
  try {
    const gfsBucket = new GridFSBucket(mongoose.connection.db, {
      bucketName: 'fs'
    });
    const _id = new mongoose.Types.ObjectId(req.params.id);
    const files = await gfsBucket.find({ _id }).toArray();
    if (!files || files.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    const file = files[0];

    // Authorize
    if (file.metadata && file.metadata.userId && file.metadata.userId !== req.user.id) {
      return res.status(404).json({ message: 'File not found' }); // Prevent enumeration
    }

    res.set('Content-Type', file.contentType || 'application/pdf');
    const readStream = gfsBucket.openDownloadStream(_id);
    readStream.on('error', (err) => {
      logger.error(`[GET /api/upload/:id] ${err.message}`, { stack: err.stack });
      res.status(500).json({ message: 'Error streaming file' });
    });
    readStream.pipe(res);
  } catch (err) {
    logger.error(`[GET /api/upload/:id] ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Server Error' });
  }
});

// @route   DELETE /api/upload/:id
// @desc    Delete a file from GridFS
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const gfsBucket = new GridFSBucket(mongoose.connection.db, {
      bucketName: 'fs'
    });
    const fileId = new mongoose.Types.ObjectId(req.params.id);

    // Verify ownership
    const files = await gfsBucket.find({ _id: fileId }).toArray();
    if (!files || files.length === 0) {
      return res.status(404).json({ message: 'File not found' });
    }
    const file = files[0];
    if (file.metadata && file.metadata.userId && file.metadata.userId !== req.user.id) {
      return res.status(404).json({ message: 'File not found' }); // Prevent enumeration
    }

    await gfsBucket.delete(fileId);
    res.json({ message: 'File deleted successfully' });
  } catch (err) {
    logger.error(`[DELETE /api/upload/:id] Error deleting file: ${err.message}`, { stack: err.stack });
    res.status(500).json({ message: 'Error deleting file' });
  }
});

module.exports = router;
