// =============================================================================
// Top-Up & Payment Intent Service
// =============================================================================
// Manages top-up payment intents, webhook event processing, and atomic ledger integration.

const crypto = require('crypto');
const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { parseInteger } = require('../utils/money');
const { logger } = require('../config/logger');
const ledgerService = require('./ledger.service');
const { getPaymentProvider } = require('../providers/payment');

/**
 * Creates a top-up payment intent and requests credentials from the payment provider.
 *
 * @param {Object} params
 * @param {string} params.userId
 * @param {number|string|bigint} params.amount
 * @param {'QRIS'|'VIRTUAL_ACCOUNT'} params.method
 * @param {string} [params.bankCode]
 * @returns {Promise<Object>} Created PaymentIntent
 */
const createTopUpIntent = async ({ userId, amount, method, bankCode = null }) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, email: true, isActive: true },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  if (!user.isActive) {
    throw new ApiError(403, 'Akun Anda telah dinonaktifkan.');
  }

  const parsedAmount = parseInteger(amount, { min: 10000, max: 20000000 });
  const referenceId = `topup_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24-hour expiration

  const provider = getPaymentProvider();

  // Call provider to create external top-up
  const providerResult = await provider.createTopUp({
    referenceId,
    amount: parsedAmount,
    method,
    bankCode,
    user,
    expiresAt,
  });

  // Persist PaymentIntent in database
  const intent = await prisma.paymentIntent.create({
    data: {
      userId,
      provider: provider.name,
      referenceId,
      providerRef: providerResult.providerRef || null,
      amount: parsedAmount,
      method,
      status: 'PENDING',
      qrString: providerResult.qrString || null,
      vaNumber: providerResult.vaNumber || null,
      bankCode: providerResult.bankCode || bankCode || null,
      expiresAt: providerResult.expiresAt || expiresAt,
    },
  });

  return intent;
};

/**
 * Retrieves a single payment intent by ID.
 * Returns 404 if not found or if user is not the owner (IDOR protection).
 *
 * @param {string} id - Payment intent ID
 * @param {string} userId - Requesting user ID
 * @returns {Promise<Object>}
 */
const getTopUpById = async (id, userId) => {
  const intent = await prisma.paymentIntent.findUnique({
    where: { id },
  });

  if (!intent || intent.userId !== userId) {
    throw new ApiError(404, 'Top-up tidak ditemukan.');
  }

  return intent;
};

/**
 * Retrieves cursor-paginated payment intents for a user.
 *
 * @param {string} userId
 * @param {Object} options - { cursor, limit }
 * @returns {Promise<{ items: Array, nextCursor: string|null }>}
 */
const getTopUps = async (userId, { cursor = null, limit = 20 } = {}) => {
  const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);

  const queryArgs = {
    where: { userId },
    take: safeLimit + 1,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  };

  if (cursor) {
    queryArgs.cursor = { id: cursor };
    queryArgs.skip = 1;
  }

  const items = await prisma.paymentIntent.findMany(queryArgs);

  let nextCursor = null;
  if (items.length > safeLimit) {
    items.pop();
    nextCursor = items[items.length - 1].id;
  }

  return {
    items,
    nextCursor,
  };
};

/**
 * Processes incoming payment gateway webhook notification.
 * Verifies authenticity, guarantees idempotency, checks amount accuracy,
 * and atomically credits user wallet via ledger.
 *
 * @param {Object} params
 * @param {string} params.providerName - e.g. 'xendit', 'fake'
 * @param {Object} params.headers - HTTP request headers
 * @param {Buffer|string} params.rawBody - Unparsed request body
 * @returns {Promise<{ success: boolean, message: string }>}
 */
const processWebhook = async ({ providerName, headers, rawBody }) => {
  const provider = getPaymentProvider(providerName);

  // 1. Verify signature or callback token
  const isValid = provider.verifyWebhook({ headers, rawBody });
  if (!isValid) {
    // Reject without exposing security details
    throw new ApiError(401, 'Unauthorized');
  }

  // 2. Parse and normalize payload
  const { eventId, referenceId, amount, status, providerRef, failureReason, rawPayload } =
    provider.parseWebhook({
      headers,
      rawBody,
    });

  // 3. Check WebhookEvent for deduplication (idempotent replay)
  const existingEvent = await prisma.webhookEvent.findUnique({
    where: { eventId },
  });

  if (existingEvent) {
    // Valid event already processed or currently recorded: return 200 OK immediately
    return { success: true, message: 'Event webhook telah diproses sebelumnya.' };
  }

  // Create WebhookEvent audit record
  try {
    await prisma.webhookEvent.create({
      data: {
        provider: provider.name,
        eventId,
        payload: rawPayload,
        status: 'RECEIVED',
      },
    });
  } catch (err) {
    if (err.code === 'P2002' && err.meta?.target?.includes('event_id')) {
      return { success: true, message: 'Event webhook telah diproses sebelumnya.' };
    }
    throw err;
  }

  // 4. Atomic processing within database transaction
  return await prisma.$transaction(async (tx) => {
    // Check if webhook is for a withdrawal payout
    const withdrawal = await tx.withdrawalRequest.findUnique({
      where: { id: referenceId },
    });

    if (withdrawal) {
      const withdrawalService = require('./withdrawal.service');
      const result = await withdrawalService.handlePayoutWebhook(tx, {
        withdrawal,
        status,
        failureReason,
        eventId,
      });

      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: `WITHDRAWAL_${status}`, processedAt: new Date() },
      });

      return result;
    }

    const intent = await tx.paymentIntent.findUnique({
      where: { referenceId },
    });

    if (!intent) {
      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: 'INTENT_NOT_FOUND', processedAt: new Date() },
      });
      return { success: true, message: 'Payment intent tidak ditemukan.' };
    }

    if (intent.status === 'PAID') {
      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: 'ALREADY_PAID', processedAt: new Date() },
      });
      return { success: true, message: 'Top-up sudah berstatus PAID.' };
    }

    // Only process if currently PENDING
    if (intent.status !== 'PENDING') {
      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: `IGNORED_STATUS_${intent.status}`, processedAt: new Date() },
      });
      return { success: true, message: `Intent status bukan PENDING (${intent.status}).` };
    }

    // Check if status is PAID / SUCCEEDED
    if (status === 'PAID') {
      const parsedPaidAmount = BigInt(amount);

      // Verify amount matches requested intent amount
      if (parsedPaidAmount !== intent.amount) {
        logger.warn(
          {
            referenceId,
            intentAmount: intent.amount.toString(),
            paidAmount: parsedPaidAmount.toString(),
            eventId,
          },
          'Nominal webhook tidak cocok dengan PaymentIntent! Menandai intent FAILED tanpa kredit saldo.'
        );

        // Mark intent as FAILED, DO NOT CREDIT WALLET
        await tx.paymentIntent.update({
          where: { id: intent.id },
          data: { status: 'FAILED' },
        });

        await tx.webhookEvent.update({
          where: { eventId },
          data: { status: 'AMOUNT_MISMATCH', processedAt: new Date() },
        });

        return { success: true, message: 'Nominal pembayaran tidak sesuai.' };
      }

      // CAS update status PENDING → PAID
      const updateResult = await tx.paymentIntent.updateMany({
        where: { id: intent.id, status: 'PENDING' },
        data: {
          status: 'PAID',
          paidAt: new Date(),
          providerRef: providerRef || intent.providerRef,
        },
      });

      if (updateResult.count === 1) {
        // Atomically credit user balance via ledger.service
        await ledgerService.credit(tx, {
          userId: intent.userId,
          amount: intent.amount,
          type: 'TOPUP',
          idempotencyKey: `topup:${intent.id}`,
          referenceType: 'PAYMENT_INTENT',
          referenceId: intent.id,
          metadata: {
            provider: provider.name,
            eventId,
            referenceId,
            method: intent.method,
          },
        });

        await tx.webhookEvent.update({
          where: { eventId },
          data: { status: 'PROCESSED', processedAt: new Date() },
        });
      }

      return { success: true, message: 'Top-up berhasil diselesaikan.' };
    }

    if (status === 'FAILED') {
      await tx.paymentIntent.updateMany({
        where: { id: intent.id, status: 'PENDING' },
        data: { status: 'FAILED' },
      });

      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: 'PROCESSED_FAILED', processedAt: new Date() },
      });

      return { success: true, message: 'Top-up ditandai FAILED.' };
    }

    if (status === 'EXPIRED') {
      await tx.paymentIntent.updateMany({
        where: { id: intent.id, status: 'PENDING' },
        data: { status: 'EXPIRED' },
      });

      await tx.webhookEvent.update({
        where: { eventId },
        data: { status: 'PROCESSED_EXPIRED', processedAt: new Date() },
      });

      return { success: true, message: 'Top-up ditandai EXPIRED.' };
    }

    return { success: true, message: `Status event tidak diproses: ${status}` };
  });
};

/**
 * Marks expired PENDING intents as EXPIRED.
 * Designed to be called by background schedulers (scheduled in Prompt 12).
 *
 * @returns {Promise<{ count: number }>}
 */
const expireStaleIntents = async () => {
  const result = await prisma.paymentIntent.updateMany({
    where: {
      status: 'PENDING',
      expiresAt: { lt: new Date() },
    },
    data: {
      status: 'EXPIRED',
    },
  });

  return { count: result.count };
};

module.exports = {
  createTopUpIntent,
  getTopUpById,
  getTopUps,
  processWebhook,
  expireStaleIntents,
};
