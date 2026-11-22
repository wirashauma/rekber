// =============================================================================
// FCM Provider Interface
// =============================================================================

class FcmProvider {
  /**
   * Send a push notification via FCM.
   *
   * @param {Object} _params
   * @param {string} _params.token - FCM device registration token
   * @param {string} _params.title - Notification title
   * @param {string} _params.body - Notification body text
   * @param {Object} [_params.data] - Key-value metadata
   * @returns {Promise<Object>}
   */
  async send(_params) {
    throw new Error('Method send() must be implemented by subclass.');
  }
}

module.exports = FcmProvider;
