/**
 * @fileoverview StorageFactory - Dependency Injection
 *
 * Reads the STORAGE_PROVIDER environment variable and returns the correct
 * StorageProvider implementation as a singleton.
 *
 * Business logic must ONLY use this factory to obtain a storage provider.
 * Direct imports of LocalStorageProvider or S3StorageProvider are NOT allowed
 * outside of this file.
 *
 * Switching environments: change STORAGE_PROVIDER in .env — no code changes needed.
 */

const { getStorageConfig } = require('../../config/storage.config');

let _instance = null;

const StorageFactory = {
  /**
   * Returns the configured StorageProvider singleton instance.
   * @returns {import('./StorageProvider')} The active storage provider.
   */
  getProvider() {
    if (_instance) return _instance;

    const config = getStorageConfig();

    if (config.provider === 's3') {
      const S3StorageProvider = require('./S3StorageProvider');
      _instance = new S3StorageProvider();

    } else {
      const LocalStorageProvider = require('./LocalStorageProvider');
      _instance = new LocalStorageProvider();

    }

    return _instance;
  },

  /**
   * Reset the singleton (useful for testing to swap providers mid-run).
   */
  reset() {
    _instance = null;
  },
};

module.exports = StorageFactory;
