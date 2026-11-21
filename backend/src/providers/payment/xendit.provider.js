// =============================================================================
// Xendit Payment Gateway Provider (Official API Implementation)
// =============================================================================

const { Buffer } = require('buffer');
const crypto = require('crypto');
const PaymentProvider = require('./payment.interface');
const config = require('../../config');
const { parseInteger } = require('../../utils/money');

class XenditPaymentProvider extends PaymentProvider {
  constructor(options = {}) {
    super();
    this.name = 'XENDIT';
    this.secretKey = options.secretKey || config.payment.xenditSecretKey;
    this.webhookToken = options.webhookToken || config.payment.webhookToken;
    this.baseUrl = options.baseUrl || 'https://api.xendit.co';
  }

  /**
   * Helper to execute authenticated requests to Xendit API.
   */
  async _request(path, method = 'GET', body = null) {
    if (!this.secretKey) {
      throw new Error('XENDIT_SECRET_KEY belum dikonfigurasi di environment.');
    }

    const authHeader = `Basic ${Buffer.from(`${this.secretKey}:`).toString('base64')}`;
    const headers = {
      Authorization: authHeader,
      'Content-Type': 'application/json',
      'api-version': '2022-07-31',
    };

    const url = `${this.baseUrl}${path}`;
    const options = {
      method,
      headers,
    };

    if (body) {
      options.body = JSON.stringify(body);
    }

    const response = await fetch(url, options);
    const data = await response.json();

    if (!response.ok) {
      const errorMsg = data.message || data.error_code || 'Gagal memproses pembayaran ke Xendit.';
      throw new Error(`Xendit API Error (${response.status}): ${errorMsg}`);
    }

    return data;
  }

  /**
   * Creates a dynamic QRIS or Callback Virtual Account via Xendit API.
   */
  async createTopUp({ referenceId, amount, method, bankCode, user, expiresAt }) {
    const parsedAmount = parseInteger(amount, { min: 10000, max: 20000000 });
    const expiry = expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000);

    if (method === 'QRIS') {
      const response = await this._request('/qr_codes', 'POST', {
        reference_id: referenceId,
        type: 'DYNAMIC',
        currency: 'IDR',
        amount: Number(parsedAmount),
        expires_at: expiry.toISOString(),
      });

      return {
        providerRef: response.id,
        qrString: response.qr_string,
        expiresAt: new Date(response.expires_at || expiry),
      };
    }

    if (method === 'VIRTUAL_ACCOUNT') {
      const resolvedBank = (bankCode || 'BCA').toUpperCase();
      const response = await this._request('/callback_virtual_accounts', 'POST', {
        external_id: referenceId,
        bank_code: resolvedBank,
        name: user?.name ? user.name.substring(0, 50) : 'Pengguna Rekber',
        expected_amount: Number(parsedAmount),
        is_closed: true,
        expiration_date: expiry.toISOString(),
      });

      return {
        providerRef: response.id,
        vaNumber: response.account_number,
        bankCode: response.bank_code || resolvedBank,
        expiresAt: new Date(response.expiration_date || expiry),
      };
    }

    throw new Error(`Metode pembayaran ${method} tidak didukung oleh XenditPaymentProvider.`);
  }

  /**
   * Creates a payout / disbursement via Xendit API.
   */
  async createPayout({ referenceId, amount, bankCode, accountNumber, accountName, description }) {
    const parsedAmount = parseInteger(amount, { min: 10000 });
    const response = await this._request('/disbursements', 'POST', {
      external_id: referenceId,
      bank_code: bankCode.toUpperCase(),
      account_holder_name: accountName,
      account_number: accountNumber,
      description: description || 'Penarikan Dana Rekber',
      amount: Number(parsedAmount),
    });

    return {
      providerRef: response.id,
      status: response.status === 'COMPLETED' ? 'COMPLETED' : 'PROCESSING',
    };
  }

  /**
   * Verifies the authenticity of incoming Xendit webhooks using x-callback-token.
   */
  verifyWebhook({ headers = {} }) {
    const incomingToken = headers['x-callback-token'];
    if (!incomingToken || !this.webhookToken) {
      return false;
    }

    try {
      const expectedBuffer = Buffer.from(this.webhookToken);
      const incomingBuffer = Buffer.from(incomingToken);

      if (expectedBuffer.length !== incomingBuffer.length) {
        return false;
      }

      return crypto.timingSafeEqual(expectedBuffer, incomingBuffer);
    } catch {
      return false;
    }
  }

  /**
   * Normalizes Xendit callback payload (supports QR, FVA, and Payments v3 formats).
   */
  parseWebhook({ rawBody, body }) {
    let payload = body;
    if (!payload && rawBody) {
      const rawStr = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody);
      try {
        payload = JSON.parse(rawStr);
      } catch (err) {
        throw new Error('Payload webhook bukan format JSON yang valid.', { cause: err });
      }
    }

    if (payload && payload.type === 'Buffer' && Array.isArray(payload.data)) {
      try {
        payload = JSON.parse(Buffer.from(payload.data).toString('utf8'));
      } catch {
        // ignore
      }
    }

    if (!payload || typeof payload !== 'object') {
      throw new Error('Payload webhook kosong atau tidak valid.');
    }

    // Reference ID extraction
    const referenceId =
      payload.external_id ||
      payload.reference_id ||
      payload.data?.reference_id ||
      payload.referenceId;

    if (!referenceId) {
      throw new Error('Payload webhook tidak memiliki external_id / reference_id.');
    }

    // Event ID extraction
    const eventId =
      payload.id ||
      payload.payment_id ||
      payload.data?.payment_id ||
      payload.data?.capture_id ||
      `xendit_${referenceId}_${Date.now()}`;

    // Status normalization
    const rawStatus = (payload.status || payload.data?.status || 'COMPLETED').toUpperCase();
    let status = 'PENDING';
    if (['COMPLETED', 'PAID', 'SETTLED', 'SUCCEEDED'].includes(rawStatus)) {
      status = 'PAID';
    } else if (
      ['FAILED', 'CANCELLED', 'REJECTED'].includes(rawStatus) ||
      (payload.event || '').includes('failed')
    ) {
      status = 'FAILED';
    } else if (['EXPIRED'].includes(rawStatus)) {
      status = 'EXPIRED';
    }

    // Amount extraction
    const rawAmount =
      payload.amount !== undefined
        ? payload.amount
        : payload.data?.amount !== undefined
          ? payload.data.amount
          : payload.data?.request_amount !== undefined
            ? payload.data.request_amount
            : 0;

    const amount = BigInt(Math.round(Number(rawAmount)));

    const providerRef =
      payload.payment_id ||
      payload.id ||
      payload.data?.payment_id ||
      payload.callback_virtual_account_id ||
      String(eventId);

    const failureReason = payload.failure_code || payload.failure_reason || null;

    return {
      eventId: String(eventId),
      referenceId: String(referenceId),
      amount,
      status,
      providerRef,
      failureReason,
      rawPayload: payload,
    };
  }
}

module.exports = XenditPaymentProvider;
