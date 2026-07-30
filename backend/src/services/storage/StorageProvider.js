/**
 * @fileoverview StorageProvider - Abstract Interface Contract
 *
 * All storage provider implementations MUST extend this class and implement
 * every method. This enforces the interface contract at runtime.
 *
 * Supported implementations:
 *   - LocalStorageProvider  (development)
 *   - S3StorageProvider     (production)
 *
 * Future implementations (drop-in replacements):
 *   - AzureBlobStorageProvider
 *   - GCSStorageProvider
 *   - CloudflareR2StorageProvider
 *   - MinIOStorageProvider
 */

class StorageProvider {
  /**
   * Upload a file buffer to storage.
   * @param {Buffer} buffer - The file content.
   * @param {string} key - The storage key / path (e.g., 'policies/userId/policyId/original/file.pdf').
   * @param {object} options - { contentType, metadata, sha256 }
   * @returns {Promise<{ key: string, size: number, etag: string }>}
   */
  async uploadFile(buffer, key, options = {}) {
    throw new Error('StorageProvider.uploadFile() must be implemented by the subclass.');
  }

  /**
   * Download a file as a readable stream.
   * @param {string} key - The storage key.
   * @returns {Promise<NodeJS.ReadableStream>}
   */
  async downloadFile(key) {
    throw new Error('StorageProvider.downloadFile() must be implemented by the subclass.');
  }

  /**
   * Delete a file from storage permanently.
   * @param {string} key - The storage key.
   * @returns {Promise<void>}
   */
  async deleteFile(key) {
    throw new Error('StorageProvider.deleteFile() must be implemented by the subclass.');
  }

  /**
   * Generate a temporary, pre-signed URL for private file access.
   * @param {string} key - The storage key.
   * @param {number} expiresInSeconds - TTL in seconds. Defaults to config value.
   * @returns {Promise<string>} - The signed URL.
   */
  async generateSignedUrl(key, expiresInSeconds) {
    throw new Error('StorageProvider.generateSignedUrl() must be implemented by the subclass.');
  }

  /**
   * Check if a file exists in storage.
   * @param {string} key - The storage key.
   * @returns {Promise<boolean>}
   */
  async fileExists(key) {
    throw new Error('StorageProvider.fileExists() must be implemented by the subclass.');
  }

  /**
   * Get file metadata from storage (size, content-type, ETag, last modified).
   * @param {string} key - The storage key.
   * @returns {Promise<{ size: number, contentType: string, etag: string, lastModified: Date }>}
   */
  async getMetadata(key) {
    throw new Error('StorageProvider.getMetadata() must be implemented by the subclass.');
  }

  /**
   * Move a file to a new key within the same storage.
   * @param {string} sourceKey - The current storage key.
   * @param {string} destKey - The destination storage key.
   * @returns {Promise<void>}
   */
  async moveFile(sourceKey, destKey) {
    throw new Error('StorageProvider.moveFile() must be implemented by the subclass.');
  }

  /**
   * Copy a file to a new key within the same storage.
   * @param {string} sourceKey - The source storage key.
   * @param {string} destKey - The destination storage key.
   * @returns {Promise<void>}
   */
  async copyFile(sourceKey, destKey) {
    throw new Error('StorageProvider.copyFile() must be implemented by the subclass.');
  }

  /**
   * List all files under a given prefix/directory.
   * @param {string} prefix - The path prefix to list.
   * @returns {Promise<Array<{ key: string, size: number, lastModified: Date }>>}
   */
  async listFiles(prefix) {
    throw new Error('StorageProvider.listFiles() must be implemented by the subclass.');
  }
}

module.exports = StorageProvider;
