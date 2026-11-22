// =============================================================================
// FCM Provider Registry & Factory
// =============================================================================

const FakeFcmProvider = require('./fake.fcm.provider');
const FirebaseFcmProvider = require('./firebase.fcm.provider');
const config = require('../../config');

let currentProvider = null;

/**
 * Returns the active FCM provider instance.
 * Defaults to FakeFcmProvider in test environment or when credentials are not configured.
 *
 * @returns {import('./fcm.interface')}
 */
const getFcmProvider = () => {
  if (!currentProvider) {
    const creds = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (creds && !config.isTest) {
      currentProvider = new FirebaseFcmProvider(creds);
    } else {
      currentProvider = new FakeFcmProvider();
    }
  }
  return currentProvider;
};

/**
 * Override the active provider (used in testing).
 *
 * @param {import('./fcm.interface')} provider
 */
const setFcmProvider = (provider) => {
  currentProvider = provider;
};

module.exports = {
  getFcmProvider,
  setFcmProvider,
  FakeFcmProvider,
  FirebaseFcmProvider,
};
