// =============================================================================
// Payment Provider Interface
// =============================================================================
// Contract for all payment gateway integrations (Xendit, Fake, etc.).
// Defines methods for creating top-up intents, verifying webhooks, and parsing payloads.
// Payout methods (createPayout) will be added in Prompt 9.

class PaymentProvider {
  /**
   * Creates a payment intent with the external payment gateway.
   *
   * @param {Object} params
   * @param {string} params.referenceId - Unique reference ID (e.g. 'topup_xxx')
   * @param {number|bigint} params.amount - Top-up amount in IDR
   * @param {'QRIS'|'VIRTUAL_ACCOUNT'} params.method - Payment method
   * @param {string} [params.bankCode] - Bank code for Virtual Account (BCA, BNI, etc.)
   * @param {Object} [params.user] - User initiating the top-up ({ id, name, email })
   * @param {Date} params.expiresAt - Expiration timestamp
   * @returns {Promise<{
   *   providerRef: string,
   *   qrString?: string,
   *   vaNumber?: string,
   *   bankCode?: string,
   *   expiresAt: Date
   * }>}
   */
  async createTopUp(_params) {
    throw new Error('createTopUp() must be implemented by payment provider subclass.');
  }

  /**
   * Verifies the authenticity and signature/callback token of an incoming webhook.
   *
   * @param {Object} params
   * @param {Object} params.headers - HTTP request headers
   * @param {Buffer|string} params.rawBody - Raw unparsed HTTP body Buffer
   * @param {Object} [params.body] - Parsed body if available
   * @returns {boolean|Promise<boolean>} True if valid and authentic, false otherwise
   */
  verifyWebhook(_params) {
    throw new Error('verifyWebhook() must be implemented by payment provider subclass.');
  }

  /**
   * Parses and normalizes incoming webhook payload across payment channels.
   *
   * @param {Object} params
   * @param {Object} params.headers - HTTP request headers
   * @param {Buffer|string} params.rawBody - Raw unparsed HTTP body Buffer
   * @param {Object} [params.body] - Parsed body if available
   * @returns {{
   *   eventId: string,
   *   referenceId: string,
   *   amount: bigint,
   *   status: 'PAID'|'FAILED'|'EXPIRED'|'PENDING'|'COMPLETED',
   *   providerRef?: string,
   *   failureReason?: string,
   *   rawPayload: Object
   * }}
   */
  parseWebhook(_params) {
    throw new Error('parseWebhook() must be implemented by payment provider subclass.');
  }

  /**
   * Creates a payout / disbursement to a recipient's bank account.
   *
   * @param {Object} params
   * @param {string} params.referenceId - Unique withdrawal request ID
   * @param {number|bigint} params.amount - Amount in IDR
   * @param {string} params.bankCode - Destination bank code (BCA, BNI, etc.)
   * @param {string} params.accountNumber - Destination bank account number
   * @param {string} params.accountName - Destination account holder name
   * @param {string} [params.description] - Transfer description
   * @returns {Promise<{
   *   providerRef: string,
   *   status: 'PROCESSING'|'COMPLETED'|'PENDING'
   * }>}
   */
  async createPayout(_params) {
    throw new Error('createPayout() must be implemented by payment provider subclass.');
  }
}

module.exports = PaymentProvider;
