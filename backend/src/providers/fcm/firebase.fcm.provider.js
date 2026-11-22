// =============================================================================
// Firebase Admin FCM Provider - Production Push Notification Service
// =============================================================================

const admin = require('firebase-admin');
const FcmProvider = require('./fcm.interface');
const { logger } = require('../../config/logger');

class FirebaseFcmProvider extends FcmProvider {
  /**
   * @param {string} serviceAccountBase64 - Base64 encoded service account JSON
   */
  constructor(serviceAccountBase64) {
    super();
    this.initialized = false;

    if (!serviceAccountBase64) {
      logger.warn('FIREBASE_SERVICE_ACCOUNT_JSON tidak diset; Firebase FCM dinonaktifkan.');
      return;
    }

    try {
      const decodedJson = Buffer.from(serviceAccountBase64, 'base64').toString('utf8');
      const serviceAccount = JSON.parse(decodedJson);

      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }
      this.initialized = true;
      logger.info('Firebase Admin SDK berhasil diinisialisasi untuk FCM.');
    } catch (err) {
      logger.warn(
        { error: err.message },
        'Gagal menginisialisasi firebase-admin dari FIREBASE_SERVICE_ACCOUNT_JSON.'
      );
    }
  }

  async send({ token, title, body, data }) {
    if (!this.initialized) {
      logger.warn('Firebase FCM belum siap; pesan push notification dilewati.');
      return { skipped: true, reason: 'NOT_INITIALIZED' };
    }

    const payload = {
      token,
      notification: {
        title,
        body,
      },
      data: Object.fromEntries(
        Object.entries(data || {}).map(([key, value]) => [key, String(value)])
      ),
    };

    return await admin.messaging().send(payload);
  }
}

module.exports = FirebaseFcmProvider;
