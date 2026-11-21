// =============================================================================
// S3 Storage Provider (Production / S3-Compatible Object Storage)
// =============================================================================
// Works with AWS S3, Cloudflare R2, MinIO, Wasabi, DigitalOcean Spaces, etc.

const {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const StorageProvider = require('./storage.interface');
const config = require('../../config');

class S3StorageProvider extends StorageProvider {
  /**
   * @param {Object} [options]
   */
  constructor(options = {}) {
    super();
    this.name = 's3';
    const s3Config = { ...config.storage.s3, ...options };

    this.bucket = s3Config.bucket;
    if (!this.bucket && config.isProd) {
      throw new Error('S3_BUCKET wajib diisi saat menggunakan S3StorageProvider.');
    }

    const clientParams = {
      region: s3Config.region || 'ap-southeast-1',
      credentials: {
        accessKeyId: s3Config.accessKeyId || '',
        secretAccessKey: s3Config.secretAccessKey || '',
      },
    };

    if (s3Config.endpoint) {
      clientParams.endpoint = s3Config.endpoint;
    }

    if (s3Config.forcePathStyle) {
      clientParams.forcePathStyle = true;
    }

    this.client = new S3Client(clientParams);
  }

  /**
   * Uploads file buffer to S3 bucket.
   */
  async put({ key, buffer, mime }) {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: buffer,
      ContentType: mime,
    });

    await this.client.send(command);

    return {
      key,
      size: buffer.length,
    };
  }

  /**
   * Generates a presigned GET URL valid for expiresInSeconds.
   */
  async getSignedUrl({ key, expiresInSeconds = 300 }) {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    return await getSignedUrl(this.client, command, {
      expiresIn: expiresInSeconds,
    });
  }

  /**
   * Deletes a file from S3 bucket.
   */
  async delete({ key }) {
    const command = new DeleteObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    await this.client.send(command);
    return true;
  }
}

module.exports = S3StorageProvider;
