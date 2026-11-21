// =============================================================================
// Local Storage Provider (Development / Self-Hosted)
// =============================================================================
// Stores files in a local directory outside web root and generates HMAC-signed URLs.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const StorageProvider = require('./storage.interface');
const config = require('../../config');

class LocalStorageProvider extends StorageProvider {
  /**
   * @param {Object} [options]
   * @param {string} [options.baseDir]
   * @param {string} [options.secret]
   */
  constructor(options = {}) {
    super();
    this.name = 'local';
    const configuredDir = options.baseDir || config.storage.localDir || 'storage_uploads';
    this.baseDir = path.isAbsolute(configuredDir)
      ? configuredDir
      : path.resolve(__dirname, '../../..', configuredDir);
    this.secret = options.secret || config.storage.localSecret || config.jwt.secret;

    // Ensure base directory exists
    if (!fs.existsSync(this.baseDir)) {
      fs.mkdirSync(this.baseDir, { recursive: true });
    }
  }

  /**
   * Safely resolves a storage key to an absolute path, preventing directory traversal.
   *
   * @param {string} key
   * @returns {string} Absolute file path
   */
  getFilePath(key) {
    const safeKey = path.normalize(key).replace(/^(\.\.(\/|\\|$))+/, '');
    const fullPath = path.resolve(this.baseDir, safeKey);
    if (!fullPath.startsWith(this.baseDir)) {
      throw new Error('Akses direktori tidak sah (Path Traversal detected).');
    }
    return fullPath;
  }

  /**
   * Persists file buffer to local disk.
   */
  async put({ key, buffer, mime: _mime }) {
    const fullPath = this.getFilePath(key);
    await fs.promises.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.promises.writeFile(fullPath, buffer);
    return {
      key,
      size: buffer.length,
    };
  }

  /**
   * Generates an HMAC-SHA256 signed URL valid for expiresInSeconds.
   */
  async getSignedUrl({ key, expiresInSeconds = 300 }) {
    const expires = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const signature = crypto
      .createHmac('sha256', this.secret)
      .update(`${key}:${expires}`)
      .digest('hex');

    return `/api/files/download/${encodeURIComponent(key)}?expires=${expires}&signature=${signature}`;
  }

  /**
   * Verifies an HMAC signature and checks expiration.
   *
   * @param {Object} params
   * @param {string} params.key
   * @param {number|string} params.expires
   * @param {string} params.signature
   * @returns {boolean} True if signature is authentic and not expired
   */
  verifySignature({ key, expires, signature }) {
    if (!key || !expires || !signature) return false;

    const expTime = parseInt(expires, 10);
    if (isNaN(expTime) || expTime < Math.floor(Date.now() / 1000)) {
      return false; // Expired
    }

    try {
      const expected = crypto
        .createHmac('sha256', this.secret)
        .update(`${key}:${expires}`)
        .digest('hex');

      const expectedBuf = Buffer.from(expected, 'hex');
      const incomingBuf = Buffer.from(signature, 'hex');

      if (expectedBuf.length !== incomingBuf.length) {
        return false;
      }

      return crypto.timingSafeEqual(expectedBuf, incomingBuf);
    } catch {
      return false;
    }
  }

  /**
   * Deletes a file from local disk.
   */
  async delete({ key }) {
    try {
      const fullPath = this.getFilePath(key);
      if (fs.existsSync(fullPath)) {
        await fs.promises.unlink(fullPath);
      }
      return true;
    } catch {
      return false;
    }
  }
}

module.exports = LocalStorageProvider;
