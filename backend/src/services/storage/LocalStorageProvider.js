/**
 * @fileoverview LocalStorageProvider
 * 
 * Stores uploaded files on the local filesystem under the `uploads/` directory.
 * Mirrors the exact S3 key structure so switching providers requires ZERO business logic changes.
 * 
 * Used for: Development and Testing environments.
 */

const fs = require('fs');
const fsPromises = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { Readable } = require('stream');
const StorageProvider = require('./StorageProvider');
const { getStorageConfig } = require('../../config/storage.config');



class LocalStorageProvider extends StorageProvider {
  constructor() {
    super();
    const config = getStorageConfig();
    // Resolve upload directory relative to the backend root
    this._baseDir = path.resolve(__dirname, '../../../', config.uploadDir);
    this._signedUrlTtl = config.signedUrlTtl;
    this._signedTokens = new Map(); // In-memory: { token -> { key, expiresAt } }

  }

  _resolvePath(key) {
    return path.join(this._baseDir, key);
  }

  async _ensureDir(filePath) {
    await fsPromises.mkdir(path.dirname(filePath), { recursive: true });
  }

  /**
   * Upload a file buffer to local disk.
   */
  async uploadFile(buffer, key, options = {}) {
    const startTime = Date.now();
    const filePath = this._resolvePath(key);
    await this._ensureDir(filePath);

    await fsPromises.writeFile(filePath, buffer);

    const stat = await fsPromises.stat(filePath);
    const etag = crypto.createHash('md5').update(buffer).digest('hex');

   

    return { key, size: stat.size, etag };
  }

  /**
   * Download a file as a readable stream.
   */
  async downloadFile(key) {
    const filePath = this._resolvePath(key);
    if (!fs.existsSync(filePath)) {
      throw new Error(`[LocalStorage] File not found: ${key}`);
    }

    return fs.createReadStream(filePath);
  }

  /**
   * Delete a file from local storage.
   */
  async deleteFile(key) {
    const filePath = this._resolvePath(key);
    try {
      await fsPromises.unlink(filePath);

    } catch (err) {
      if (err.code !== 'ENOENT') throw err; // Ignore "file not found" errors on delete
    }
  }

  /**
   * Generate a signed token URL for temporary local access.
   * The backend must expose a route at GET /api/files/signed/:token to serve these.
   */
  async generateSignedUrl(key, expiresInSeconds) {
    const ttl = expiresInSeconds || this._signedUrlTtl;
    const token = crypto.randomBytes(32).toString('hex');
    this._signedTokens.set(token, {
      key,
      expiresAt: Date.now() + (ttl * 1000),
    });

    const baseUrl = process.env.APP_BASE_URL || `http://localhost:${process.env.PORT || 3000}`;
    const signedUrl = `${baseUrl}/api/files/signed/${token}`;


    return signedUrl;
  }

  /**
   * Resolve a signed token to a file key (used by the signed URL route handler).
   * @param {string} token
   * @returns {string|null} storageKey or null if invalid/expired
   */
  resolveSignedToken(token) {
    const entry = this._signedTokens.get(token);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this._signedTokens.delete(token);
      return null;
    }
    return entry.key;
  }

  /**
   * Check if a file exists.
   */
  async fileExists(key) {
    return fs.existsSync(this._resolvePath(key));
  }

  /**
   * Get file metadata.
   */
  async getMetadata(key) {
    const filePath = this._resolvePath(key);
    const stat = await fsPromises.stat(filePath);
    return {
      size: stat.size,
      contentType: 'application/pdf', // Simple implementation
      etag: null,
      lastModified: stat.mtime,
    };
  }

  /**
   * Move a file to a new key.
   */
  async moveFile(sourceKey, destKey) {
    const src = this._resolvePath(sourceKey);
    const dest = this._resolvePath(destKey);
    await this._ensureDir(dest);
    await fsPromises.rename(src, dest);

  }

  /**
   * Copy a file to a new key.
   */
  async copyFile(sourceKey, destKey) {
    const src = this._resolvePath(sourceKey);
    const dest = this._resolvePath(destKey);
    await this._ensureDir(dest);
    await fsPromises.copyFile(src, dest);

  }

  /**
   * List all files under a prefix/directory.
   */
  async listFiles(prefix) {
    const dir = this._resolvePath(prefix);
    const results = [];

    const walk = async (currentDir) => {
      let entries;
      try {
        entries = await fsPromises.readdir(currentDir, { withFileTypes: true });
      } catch {
        return; // Directory does not exist
      }
      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        if (entry.isDirectory()) {
          await walk(fullPath);
        } else {
          const stat = await fsPromises.stat(fullPath);
          const key = path.relative(this._baseDir, fullPath).replace(/\\/g, '/');
          results.push({ key, size: stat.size, lastModified: stat.mtime });
        }
      }
    };

    await walk(dir);
    return results;
  }
}

module.exports = LocalStorageProvider;
