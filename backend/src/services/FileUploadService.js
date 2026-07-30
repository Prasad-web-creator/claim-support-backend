/**
 * @fileoverview FileUploadService - Upload Orchestrator
 *
 * Coordinates the full upload workflow:
 *   1. Compute SHA256 hash for integrity
 *   2. Generate UUID-based storage key
 *   3. Call StorageProvider.uploadFile()
 *   4. Save metadata record to MongoDB (StoredFile)
 *   5. Emit event hooks (afterUpload, afterMetadataSaved, etc.)
 *   6. Return storedFileId and storageKey to caller
 *
 * Business logic (routes, controllers) should ONLY call this service.
 * Never call StorageProvider directly from routes.
 */

const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const EventEmitter = require('events');
const StorageFactory = require('./storage/StorageFactory');
const StoredFile = require('../models/StoredFile');
const { getStorageConfig } = require('../config/storage.config');

/**
 * Builds the storage key following the bucket structure convention:
 *   {documentType}/{userId}/{documentId}/original/{storedFilename}
 */
function buildStorageKey(documentType, userId, documentId, storedFilename) {
  return `${documentType}s/${userId}/${documentId}/original/${storedFilename}`;
}

class FileUploadService extends EventEmitter {
  constructor() {
    super();
    this._config = getStorageConfig();
  }

  /**
   * Upload a file and persist metadata to MongoDB.
   *
   * @param {object} params
   * @param {Buffer}   params.buffer          - The raw file buffer from multer
   * @param {string}   params.originalFilename - User's original file name
   * @param {string}   params.mimeType         - MIME type (e.g., 'application/pdf')
   * @param {string}   params.documentType     - 'policy' | 'prescription' | etc.
   * @param {string}   params.userId           - MongoDB ObjectId string
   * @param {string}   params.documentId       - MongoDB ObjectId of the Policy / Prescription
   *
   * @returns {Promise<{ storedFileId: string, storageKey: string, storedFilename: string }>}
   */
  async uploadFile({ buffer, originalFilename, mimeType, documentType, userId, documentId }) {
    const startTime = Date.now();

    // --- 1. Compute SHA256 ---
    const sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
    const fileSize = buffer.length;



    // --- 2. Generate UUID-based filename and storage key ---
    const ext = path.extname(originalFilename).toLowerCase() || '.pdf';
    const storedFilename = `${documentType}_${uuidv4().replace(/-/g, '').substring(0, 8)}${ext}`;
    const storageKey = buildStorageKey(documentType, userId, documentId, storedFilename);

    // --- 2.5 Duplicate Upload Prevention ---
    const existingFile = await StoredFile.findOne({ userId, sha256Hash: sha256, isDeleted: false });
    if (existingFile) {

      return {
        storedFileId: existingFile._id.toString(),
        storageKey: existingFile.storageKey,
        storedFilename: existingFile.storedFilename,
      };
    }

    // --- 3. Upload to storage provider ---
    const provider = StorageFactory.getProvider();
    const uploadResult = await provider.uploadFile(buffer, storageKey, {
      contentType: mimeType,
      sha256,
      originalName: originalFilename,
    });

    this.emit('afterUpload', { storageKey, documentType, userId, documentId, size: fileSize });

    // --- 4. Save metadata to MongoDB ---
    const storedFile = new StoredFile({
      userId,
      documentId,
      documentType,
      originalFilename,
      storedFilename,
      storageKey,
      bucketName: this._config.provider === 's3' ? this._config.s3?.bucketName : null,
      storageProvider: this._config.provider,
      mimeType,
      fileSize,
      sha256Hash: sha256,
      processingStatus: 'pending',
      analysisStatus: 'pending',
    });

    await storedFile.save();
    this.emit('afterMetadataSaved', { storedFileId: storedFile._id.toString(), storageKey });

    const duration = Date.now() - startTime;


    return {
      storedFileId: storedFile._id.toString(),
      storageKey,
      storedFilename,
    };
  }

  /**
   * Delete a file from storage and mark its metadata record as deleted (soft delete).
   * @param {string} storedFileId - The MongoDB _id of the StoredFile record.
   * @param {string} deletedByUserId - The user performing the delete.
   */
  async deleteFile(storedFileId, deletedByUserId) {
    const record = await StoredFile.findById(storedFileId);
    if (!record) throw new Error(`StoredFile not found: ${storedFileId}`);

    const provider = StorageFactory.getProvider();
    await provider.deleteFile(record.storageKey);

    await StoredFile.findByIdAndUpdate(storedFileId, {
      isDeleted: true,
      deletedAt: new Date(),
      deletedBy: deletedByUserId,
    });

    this.emit('afterDelete', { storedFileId, storageKey: record.storageKey });

  }

  /**
   * Generate a temporary signed URL for file preview or download.
   * @param {string} storedFileId
   * @param {number} [expiresInSeconds]
   * @returns {Promise<string>} Signed URL
   */
  async generateSignedUrl(storedFileId, expiresInSeconds) {
    const record = await StoredFile.findById(storedFileId);
    if (!record) throw new Error(`StoredFile not found: ${storedFileId}`);
    if (record.isDeleted) throw new Error(`File has been deleted: ${storedFileId}`);

    const provider = StorageFactory.getProvider();
    return provider.generateSignedUrl(record.storageKey, expiresInSeconds);
  }

  /**
   * Stream a file directly to an HTTP response.
   * @param {string} storageKey
   * @param {object} res - Express response object
   * @param {string} [contentType]
   */
  async streamFile(storageKey, res, contentType = 'application/pdf') {
    const provider = StorageFactory.getProvider();
    const stream = await provider.downloadFile(storageKey);
    res.set('Content-Type', contentType);
    stream.pipe(res);
  }
}

// Export a singleton instance
module.exports = new FileUploadService();
