// =============================================================================
// Fake Payment Provider (Development & Testing)
// =============================================================================

const { Buffer } = require('buffer');
const PaymentProvider = require('./payment.interface');
const config = require('../../config');
const { parseInteger } = require('../../utils/money');

class FakePaymentProvider extends PaymentProvider {
  constructor(options = {}) {
    super();
    this.name = 'FAKE';
    this.webhookToken =
      options.webhookToken || config.payment.webhookToken || 'test_webhook_verification_token';
  }

  /**
   * Generates mock top-up payment credentials for QRIS or Virtual Account.
   */
  async createTopUp({ referenceId, amount, method, bankCode, expiresAt }) {
    const parsedAmount = parseInteger(amount, { min: 10000, max: 20000000 });
    const expiry = expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000);

    if (method === 'QRIS') {
      return {
        providerRef: `fake_qr_${referenceId}`,
        qrString: `00020101021226540014ID.LINKAJA.01189360091100222019990215${referenceId}520458125303360540${parsedAmount}5802ID5911REKBER MOCK6007JAKARTA6304ABCD`,
        expiresAt: expiry,
      };
    }

    if (method === 'VIRTUAL_ACCOUNT') {
      const resolvedBank = (bankCode || 'BCA').toUpperCase();
      // Generate a mock 16-digit virtual account number
      const bankPrefixes = {
        BCA: '8800',
        BNI: '8810',
        BRI: '8820',
        MANDIRI: '8830',
        PERMATA: '8840',
      };
      const prefix = bankPrefixes[resolvedBank] || '8888';
      const randomSuffix = Math.floor(100000000000 + Math.random() * 900000000000);
      const vaNumber = `${prefix}${randomSuffix}`;

      return {
        providerRef: `fake_va_${referenceId}`,
        vaNumber,
        bankCode: resolvedBank,
        expiresAt: expiry,
      };
    }

    throw new Error(`Metode pembayaran ${method} tidak didukung oleh FakePaymentProvider.`);
  }

  /**
   * Mock payout/disbursement creation.
   */
  async createPayout({
    referenceId,
    amount: _amount,
    bankCode: _bankCode,
    accountNumber: _accountNumber,
  }) {
    return {
      providerRef: `fake_disb_${referenceId}`,
      status: 'PROCESSING',
    };
  }

  /**
   * Verifies callback token from headers.
   */
  verifyWebhook({ headers = {} }) {
    const token =
      headers['x-callback-token'] || headers['x-fake-token'] || headers['authorization'];
    if (!token) return false;
    return token === this.webhookToken;
  }

  /**
   * Parses webhook payload.
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

    const referenceId = payload.referenceId || payload.reference_id || payload.external_id;
    if (!referenceId) {
      throw new Error('Payload webhook tidak memiliki referenceId / external_id.');
    }

    const rawStatus = (payload.status || 'PAID').toUpperCase();
    let status = 'PENDING';
    if (['PAID', 'SUCCEEDED'].includes(rawStatus)) {
      status = 'PAID';
    } else if (rawStatus === 'COMPLETED') {
      status = 'COMPLETED';
    } else if (['FAILED', 'CANCELLED'].includes(rawStatus)) {
      status = 'FAILED';
    } else if (['EXPIRED'].includes(rawStatus)) {
      status = 'EXPIRED';
    }

    const eventId =
      payload.id || payload.eventId || payload.event_id || `fake_evt_${referenceId}_${Date.now()}`;
    const amount = payload.amount !== undefined ? BigInt(payload.amount) : 0n;
    const failureReason = payload.failure_code || payload.failure_reason || null;

    return {
      eventId: String(eventId),
      referenceId: String(referenceId),
      amount,
      status,
      providerRef:
        payload.providerRef || payload.paymentId || payload.payment_id || String(eventId),
      failureReason,
      rawPayload: payload,
    };
  }

  /**
   * Helper utility for manual simulation or integration testing.
   */
  simulateWebhook({ referenceId, amount, status = 'PAID', eventId = null, bankCode = 'BCA' }) {
    const id = eventId || `sim_evt_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const payload = {
      id,
      event: 'payment.succeeded',
      external_id: referenceId,
      reference_id: referenceId,
      amount: typeof amount === 'bigint' ? Number(amount) : amount,
      status,
      bank_code: bankCode,
      paid_at: new Date().toISOString(),
    };

    return {
      headers: {
        'content-type': 'application/json',
        'x-callback-token': this.webhookToken,
      },
      rawBody: JSON.stringify(payload),
      body: payload,
    };
  }

  /**
   * Helper utility for payout webhook simulation.
   */
  simulatePayoutWebhook({
    referenceId,
    amount,
    status = 'COMPLETED',
    failureReason = null,
    eventId = null,
  }) {
    const id = eventId || `sim_payout_evt_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const payload = {
      id,
      event: status === 'COMPLETED' ? 'disbursement.succeeded' : 'disbursement.failed',
      external_id: referenceId,
      reference_id: referenceId,
      amount: typeof amount === 'bigint' ? Number(amount) : amount,
      status,
      failure_code: failureReason || (status === 'FAILED' ? 'ACCOUNT_INACTIVE' : null),
      failure_reason: failureReason,
      created: new Date().toISOString(),
    };

    return {
      headers: {
        'content-type': 'application/json',
        'x-callback-token': this.webhookToken,
      },
      rawBody: JSON.stringify(payload),
      body: payload,
    };
  }
}

module.exports = FakePaymentProvider;
