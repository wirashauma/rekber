// =============================================================================
// Storage Provider Factory
// =============================================================================

const config = require('../../config');
const StorageProvider = require('./storage.interface');
const LocalStorageProvider = require('./local.provider');
const S3StorageProvider = require('./s3.provider');

let activeProvider = null;

/**
 * Returns the configured storage provider instance.
 *
 * @param {string} [providerName]
 * @returns {StorageProvider}
 */
const getStorageProvider = (providerName = null) => {
  const selectedName = (providerName || config.storage.provider || 'local').toLowerCase();

  if (activeProvider && activeProvider.name === selectedName && !providerName) {
    return activeProvider;
  }

  let providerInstance;
  switch (selectedName) {
    case 's3':
      providerInstance = new S3StorageProvider();
      break;
    case 'local':
    default:
      providerInstance = new LocalStorageProvider();
      break;
  }

  if (!providerName) {
    activeProvider = providerInstance;
  }

  return providerInstance;
};

module.exports = {
  getStorageProvider,
  StorageProvider,
  LocalStorageProvider,
  S3StorageProvider,
};
