// =============================================================================
// Fake FCM Provider - In-Memory Testing & Local Development
// =============================================================================

const FcmProvider = require('./fcm.interface');

class FakeFcmProvider extends FcmProvider {
  constructor() {
    super();
    this.sentMessages = [];
  }

  async send({ token, title, body, data }) {
    // Simulate invalid registration token error for testing
    if (token === 'invalid_fcm_token' || token === 'unregistered_token') {
      const error = new Error('The registration token is not registered or invalid.');
      error.code = 'messaging/registration-token-not-registered';
      throw error;
    }

    const message = {
      token,
      title,
      body,
      data: data || {},
      sentAt: new Date(),
    };

    this.sentMessages.push(message);

    return {
      success: true,
      messageId: `fake-fcm-${Date.now()}-${this.sentMessages.length}`,
    };
  }

  getSentMessages() {
    return this.sentMessages;
  }

  clear() {
    this.sentMessages = [];
  }
}

module.exports = FakeFcmProvider;
