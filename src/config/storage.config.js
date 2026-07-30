/**
 * @fileoverview Storage Configuration
 * Reads environment variables and exports a validated storage configuration object.
 * Business logic should import this instead of accessing process.env directly.
 */

const STORAGE_PROVIDERS = ['local', 's3'];

function getStorageConfig() {
  const provider = (process.env.STORAGE_PROVIDER || 'local').toLowerCase();

  if (!STORAGE_PROVIDERS.includes(provider)) {
    throw new Error(`[Storage Config] Invalid STORAGE_PROVIDER: "${provider}". Must be one of: ${STORAGE_PROVIDERS.join(', ')}`);
  }

  const config = {
    provider,
    maxFileSizeMb: parseInt(process.env.STORAGE_MAX_FILE_SIZE_MB || '50', 10),
    signedUrlTtl: parseInt(process.env.STORAGE_SIGNED_URL_TTL || '900', 10), // 15 minutes
    allowedMimeTypes: (process.env.STORAGE_ALLOWED_MIME_TYPES || 'application/pdf,image/png,image/jpeg,image/gif,application/vnd.openxmlformats-officedocument.wordprocessingml.document').split(',').map(m => m.trim()),
    uploadDir: process.env.LOCAL_UPLOAD_DIR || 'uploads', // Relative to backend root
    isProduction: process.env.NODE_ENV === 'production',
  };

  if (provider === 's3') {
    if (!process.env.AWS_REGION) throw new Error('[Storage Config] AWS_REGION is required when STORAGE_PROVIDER=s3');
    if (!process.env.S3_BUCKET_NAME) throw new Error('[Storage Config] S3_BUCKET_NAME is required when STORAGE_PROVIDER=s3');

    config.s3 = {
      region: process.env.AWS_REGION,
      bucketName: process.env.S3_BUCKET_NAME,
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      endpoint: process.env.S3_ENDPOINT || undefined, // Optional: for MinIO / Cloudflare R2
    };
  }

  return config;
}

module.exports = { getStorageConfig };
