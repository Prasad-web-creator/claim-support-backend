/**
 * @fileoverview StoredFile - MongoDB Metadata Model
 *
 * Stores metadata for ALL uploaded documents.
 * Binary file data is NEVER stored in MongoDB — only metadata and storage references.
 *
 * Replaces the `gridFsFileId` references in Policy and Prescription models.
 */

const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');

const DOCUMENT_TYPES = [
  'policy',
  'prescription',
  'medical-report',
  'discharge-summary',
  'hospital-bill',
  'lab-report',
  'claim-document',
];

const PROCESSING_STATUSES = ['pending', 'processing', 'completed', 'failed'];
const ANALYSIS_STATUSES   = ['pending', 'processing', 'completed', 'failed', 'skipped'];
const STORAGE_PROVIDERS   = ['local', 's3'];

const storedFileSchema = new mongoose.Schema(
  {
    // --- Ownership ---
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    // --- Document Reference ---
    documentId: {
      type: mongoose.Schema.Types.ObjectId,
      index: true,
      // References the Policy or Prescription _id this file belongs to
    },
    documentType: {
      type: String,
      enum: DOCUMENT_TYPES,
      required: true,
      index: true,
    },

    // --- File Identity ---
    originalFilename: { type: String, required: true },  // User-provided name
    storedFilename:   { type: String, required: true },  // UUID-based name, e.g. policy_8e4af7c9.pdf
    storageKey:       { type: String, required: true, unique: true }, // Full storage path/key
    bucketName:       { type: String },                  // S3 bucket name (null for local)
    storageProvider:  { type: String, enum: STORAGE_PROVIDERS, required: true },

    // --- File Properties ---
    mimeType:         { type: String, required: true },
    fileSize:         { type: Number, required: true },  // Bytes
    sha256Hash:       { type: String, required: true },  // Integrity check

    // --- Processing State ---
    processingStatus: { type: String, enum: PROCESSING_STATUSES, default: 'pending' },
    analysisStatus:   { type: String, enum: ANALYSIS_STATUSES,   default: 'pending' },
    documentVersion:  { type: Number, default: 1 },
    processingErrors: [{ type: String }],

    // --- Soft Delete ---
    isDeleted:   { type: Boolean, default: false, index: true },
    deletedAt:   { type: Date },
    deletedBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  {
    timestamps: true,
    strict: true,
  }
);

// Compound index for optimizing file retrieval and deletion cascades
storedFileSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });
// Index for Duplicate Upload Prevention
storedFileSchema.index({ userId: 1, sha256Hash: 1, isDeleted: 1 });
// Compound index for fast user + type lookups
storedFileSchema.index({ userId: 1, documentType: 1, isDeleted: 1 });
storedFileSchema.index({ userId: 1, sha256Hash: 1 });

storedFileSchema.plugin(mongoosePaginate);

module.exports = mongoose.model('StoredFile', storedFileSchema);
