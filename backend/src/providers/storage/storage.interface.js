// =============================================================================
// Storage Provider Interface
// =============================================================================
// Contract for all file storage providers (Local, S3-compatible, etc.).

class StorageProvider {
  /**
   * Uploads/persists a file buffer with a given key and MIME type.
   *
   * @param {Object} params
   * @param {string} params.key - Unique storage path/key (e.g. 'shipment_proof/xxx.jpg')
   * @param {Buffer} params.buffer - Processed file buffer
   * @param {string} params.mime - MIME type (e.g. 'image/jpeg')
   * @returns {Promise<{ key: string, size: number }>}
   */
  async put(_params) {
    throw new Error('put() must be implemented by storage provider subclass.');
  }

  /**
   * Generates a short-lived signed URL for downloading/viewing the file.
   *
   * @param {Object} params
   * @param {string} params.key - Storage path/key
   * @param {number} [params.expiresInSeconds=300] - Expiration duration in seconds
   * @returns {Promise<string>|string} Signed URL string
   */
  async getSignedUrl(_params) {
    throw new Error('getSignedUrl() must be implemented by storage provider subclass.');
  }

  /**
   * Deletes a file by its storage key.
   *
   * @param {Object} params
   * @param {string} params.key - Storage path/key
   * @returns {Promise<boolean>}
   */
  async delete(_params) {
    throw new Error('delete() must be implemented by storage provider subclass.');
  }
}

module.exports = StorageProvider;
