/**
 * @fileoverview S3StorageProvider
 * 
 * Stores uploaded files on Amazon S3.
 * Uses AWS SDK v3 with multipart upload, streaming, retry logic, and signed URLs.
 * 
 * Used for: Staging and Production environments.
 */

const { S3Client, GetObjectCommand, DeleteObjectCommand, HeadObjectCommand, CopyObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { Upload } = require('@aws-sdk/lib-storage');
const crypto = require('crypto');
const StorageProvider = require('./StorageProvider');
const { getStorageConfig } = require('../../config/storage.config');
const logger = require('../../utils/logger');


const MULTIPART_THRESHOLD_BYTES = 5 * 1024 * 1024; // 5MB
const MAX_RETRIES = 3;

class S3StorageProvider extends StorageProvider {
  constructor() {
    super();
    const config = getStorageConfig();
    const s3Config = config.s3;

    this._bucketName = s3Config.bucketName;
    this._signedUrlTtl = config.signedUrlTtl;

    const clientConfig = {
      region: s3Config.region,
      maxAttempts: MAX_RETRIES,
    };

    // Support optional credentials (IAM Role is preferred in production)
    if (s3Config.accessKeyId && s3Config.secretAccessKey) {
      clientConfig.credentials = {
        accessKeyId: s3Config.accessKeyId,
        secretAccessKey: s3Config.secretAccessKey,
      };
    }

    // Support custom endpoints (MinIO, Cloudflare R2)
    if (s3Config.endpoint) {
      clientConfig.endpoint = s3Config.endpoint;
      clientConfig.forcePathStyle = true;
    }

    this._client = new S3Client(clientConfig);


  }

  _detectContentType(buffer) {
    if (!buffer || buffer.length < 4) return 'application/octet-stream';
    // PDF magic bytes
    if (buffer.toString('utf8', 0, 4) === '%PDF') return 'application/pdf';
    // PNG
    if (buffer[0] === 0x89 && buffer[1] === 0x50) return 'image/png';
    // JPEG
    if (buffer[0] === 0xFF && buffer[1] === 0xD8) return 'image/jpeg';
    return 'application/octet-stream';
  }

  /**
   * Upload a file buffer to S3.
   * Automatically uses multipart upload for files > 5MB.
   */
  async uploadFile(buffer, key, options = {}) {
    const startTime = Date.now();
    const contentType = options.contentType || this._detectContentType(buffer);
    const sha256 = options.sha256 || crypto.createHash('sha256').update(buffer).digest('hex');


    const uploadParams = {
      Bucket: this._bucketName,
      Key: key,
      Body: buffer,
      ContentType: contentType,
      ServerSideEncryption: 'AES256',
      Metadata: {
        sha256,
        originalName: options.originalName || '',
        uploadedAt: new Date().toISOString(),
        ...options.metadata,
      },
    };

    // Use multipart upload via @aws-sdk/lib-storage for reliability on all sizes
    const upload = new Upload({
      client: this._client,
      params: uploadParams,
      queueSize: 4,         // 4 concurrent parts
      partSize: 5 * 1024 * 1024, // 5MB parts
      leavePartsOnError: false,
    });

    let retryCount = 0;
    let result;

    while (retryCount <= MAX_RETRIES) {
      try {
        result = await upload.done();
        break;
      } catch (err) {
        retryCount++;
        if (retryCount > MAX_RETRIES) {
          throw new Error(`[S3Storage] Upload failed after ${MAX_RETRIES} retries: ${err.message}`);
        }
        const delay = Math.pow(2, retryCount) * 1000;
        logger.warn(`[S3StorageProvider] ⚠️ Upload attempt ${retryCount} failed. Retrying in ${delay}ms... Error: ${err.message}`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }

    const duration = Date.now() - startTime;

    return { key, size: buffer.length, etag: result.ETag || '' };
  }

  /**
   * Download a file from S3 as a readable stream (no full buffer in memory).
   */
  async downloadFile(key) {

    const command = new GetObjectCommand({ Bucket: this._bucketName, Key: key });
    const response = await this._client.send(command);
    return response.Body; // This is a ReadableStream
  }

  /**
   * Delete a file from S3.
   */
  async deleteFile(key) {
    const command = new DeleteObjectCommand({ Bucket: this._bucketName, Key: key });
    await this._client.send(command);

  }

  /**
   * Generate a pre-signed URL for temporary private access.
   */
  async generateSignedUrl(key, expiresInSeconds) {
    const ttl = expiresInSeconds || this._signedUrlTtl;
    const command = new GetObjectCommand({ Bucket: this._bucketName, Key: key });
    const url = await getSignedUrl(this._client, command, { expiresIn: ttl });

    return url;
  }

  /**
   * Check if a file exists in S3.
   */
  async fileExists(key) {
    try {
      await this._client.send(new HeadObjectCommand({ Bucket: this._bucketName, Key: key }));
      return true;
    } catch (err) {
      if (err.name === 'NotFound' || err.$metadata?.httpStatusCode === 404) return false;
      throw err;
    }
  }

  /**
   * Get metadata from S3 HeadObject.
   */
  async getMetadata(key) {
    const response = await this._client.send(new HeadObjectCommand({ Bucket: this._bucketName, Key: key }));
    return {
      size: response.ContentLength,
      contentType: response.ContentType,
      etag: response.ETag,
      lastModified: response.LastModified,
    };
  }

  /**
   * Move a file within S3 (copy + delete).
   */
  async moveFile(sourceKey, destKey) {
    await this.copyFile(sourceKey, destKey);
    await this.deleteFile(sourceKey);

  }

  /**
   * Copy a file within the same S3 bucket.
   */
  async copyFile(sourceKey, destKey) {
    const command = new CopyObjectCommand({
      Bucket: this._bucketName,
      CopySource: `${this._bucketName}/${sourceKey}`,
      Key: destKey,
      ServerSideEncryption: 'AES256',
    });
    await this._client.send(command);

  }

  /**
   * List files under a S3 prefix.
   */
  async listFiles(prefix) {
    const results = [];
    let continuationToken;

    do {
      const command = new ListObjectsV2Command({
        Bucket: this._bucketName,
        Prefix: prefix,
        ContinuationToken: continuationToken,
      });
      const response = await this._client.send(command);
      for (const obj of response.Contents || []) {
        results.push({ key: obj.Key, size: obj.Size, lastModified: obj.LastModified });
      }
      continuationToken = response.NextContinuationToken;
    } while (continuationToken);

    return results;
  }
}

module.exports = S3StorageProvider;
