// =============================================================================
// Withdrawal Service - Balance Withdrawal & Payout Workflow
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { parseInteger } = require('../utils/money');
const { decrypt, maskAccountNumber } = require('../utils/encryption');
const { calculateNameMatch } = require('../utils/stringSimilarity');
const settingsService = require('./settings.service');
const ledgerService = require('./ledger.service');
const { getPaymentProvider } = require('../providers/payment');

/**
 * Checks whether user is eligible for withdrawal.
 * Currently validates isActive. (KYC validation added in Prompt 14).
 *
 * @param {Object} user - User record
 */
const assertCanWithdraw = (user) => {
  if (!user.isActive) {
    throw new ApiError(403, 'Akun Anda dinonaktifkan.');
  }
};

/**
 * Initiates a new withdrawal request and reserves balance atomically.
 *
 * @param {string} userId
 * @param {Object} params
 * @param {string} params.bankAccountId
 * @param {number|string|bigint} params.amount
 * @param {string} params.idempotencyKey - Mandatory idempotency key
 * @returns {Promise<Object>} Created WithdrawalRequest
 */
const createWithdrawal = async (userId, { bankAccountId, amount, idempotencyKey }) => {
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.trim() === '') {
    throw new ApiError(400, 'Header Idempotency-Key wajib disertakan.');
  }

  // Idempotent check
  const existing = await prisma.withdrawalRequest.findUnique({
    where: { idempotencyKey },
    include: {
      bankAccount: true,
    },
  });

  if (existing) {
    let plainNumber;
    try {
      plainNumber = decrypt(existing.bankAccount.accountNumberEnc);
    } catch {
      plainNumber = `••••••••${existing.bankAccount.accountLast4}`;
    }

    return {
      id: existing.id,
      userId: existing.userId,
      amount: existing.amount,
      fee: existing.fee,
      status: existing.status,
      bankAccount: {
        id: existing.bankAccount.id,
        bankCode: existing.bankAccount.bankCode,
        accountNumberMasked: maskAccountNumber(plainNumber),
        accountLast4: existing.bankAccount.accountLast4,
        accountName: existing.bankAccount.accountName,
      },
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    };
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  assertCanWithdraw(user);

  const bankAccount = await prisma.bankAccount.findFirst({
    where: { id: bankAccountId, userId, deletedAt: null },
  });

  if (!bankAccount) {
    throw new ApiError(404, 'Rekening bank tujuan tidak ditemukan atau sudah dihapus.');
  }

  const parsedAmount = parseInteger(amount, { min: 1000 });
  const withdrawMin = await settingsService.getNumber('withdraw_min');
  if (parsedAmount < BigInt(withdrawMin)) {
    throw new ApiError(400, `Jumlah penarikan minimal Rp ${withdrawMin.toLocaleString('id-ID')}.`);
  }

  const withdrawFee = await settingsService.getNumber('withdraw_fee');
  const parsedFee = BigInt(withdrawFee);
  const totalDebit = parsedAmount + parsedFee;

  // Daily limit check (PlatformSetting: withdraw_daily_limit, default 10.000.000)
  const dailyLimit = await settingsService.getNumber('withdraw_daily_limit');
  const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const recentWithdrawals = await prisma.withdrawalRequest.findMany({
    where: {
      userId,
      createdAt: { gte: twentyFourHoursAgo },
      status: { in: ['PENDING_REVIEW', 'APPROVED', 'PROCESSING', 'COMPLETED'] },
    },
    select: { amount: true },
  });

  const currentDailyTotal = recentWithdrawals.reduce((sum, w) => sum + w.amount, 0n);
  if (currentDailyTotal + parsedAmount > BigInt(dailyLimit)) {
    throw new ApiError(
      400,
      `Jumlah penarikan melebihi batas harian platform (Rp ${dailyLimit.toLocaleString('id-ID')}).`
    );
  }

  return await prisma.$transaction(async (tx) => {
    // 1. Create withdrawal request in PENDING_REVIEW status
    const withdrawal = await tx.withdrawalRequest.create({
      data: {
        userId,
        bankAccountId,
        amount: parsedAmount,
        fee: parsedFee,
        status: 'PENDING_REVIEW',
        idempotencyKey,
      },
    });

    // 2. Atomically reserve balance (debit WITHDRAWAL_RESERVE)
    await ledgerService.debit(tx, {
      userId,
      amount: totalDebit,
      type: 'WITHDRAWAL_RESERVE',
      idempotencyKey: `withdrawal:${withdrawal.id}:reserve`,
      referenceType: 'WITHDRAWAL',
      referenceId: withdrawal.id,
      metadata: {
        bankCode: bankAccount.bankCode,
        accountLast4: bankAccount.accountLast4,
        amount: parsedAmount.toString(),
        fee: parsedFee.toString(),
      },
    });

    let plainNumber;
    try {
      plainNumber = decrypt(bankAccount.accountNumberEnc);
    } catch {
      plainNumber = `••••••••${bankAccount.accountLast4}`;
    }

    return {
      id: withdrawal.id,
      userId: withdrawal.userId,
      amount: withdrawal.amount,
      fee: withdrawal.fee,
      status: withdrawal.status,
      bankAccount: {
        id: bankAccount.id,
        bankCode: bankAccount.bankCode,
        accountNumberMasked: maskAccountNumber(plainNumber),
        accountLast4: bankAccount.accountLast4,
        accountName: bankAccount.accountName,
      },
      createdAt: withdrawal.createdAt,
      updatedAt: withdrawal.updatedAt,
    };
  });
};

/**
 * Retrieves paginated list of user's withdrawal requests.
 *
 * @param {string} userId
 * @param {Object} options - { cursor, limit }
 * @returns {Promise<{ items: Array, nextCursor: string|null }>}
 */
const getUserWithdrawals = async (userId, { cursor = null, limit = 20 } = {}) => {
  const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);

  const queryArgs = {
    where: { userId },
    take: safeLimit + 1,
    include: {
      bankAccount: true,
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  };

  if (cursor) {
    queryArgs.cursor = { id: cursor };
    queryArgs.skip = 1;
  }

  const items = await prisma.withdrawalRequest.findMany(queryArgs);

  let nextCursor = null;
  if (items.length > safeLimit) {
    items.pop();
    nextCursor = items[items.length - 1].id;
  }

  const formattedItems = items.map((w) => {
    let plainNumber;
    try {
      plainNumber = decrypt(w.bankAccount.accountNumberEnc);
    } catch {
      plainNumber = `••••••••${w.bankAccount.accountLast4}`;
    }

    return {
      id: w.id,
      userId: w.userId,
      amount: w.amount,
      fee: w.fee,
      status: w.status,
      failureReason: w.failureReason,
      bankAccount: {
        id: w.bankAccount.id,
        bankCode: w.bankAccount.bankCode,
        accountNumberMasked: maskAccountNumber(plainNumber),
        accountLast4: w.bankAccount.accountLast4,
        accountName: w.bankAccount.accountName,
      },
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
    };
  });

  return {
    items: formattedItems,
    nextCursor,
  };
};

/**
 * Cancels a withdrawal request (user initiator).
 * Only permitted when status is PENDING_REVIEW.
 * Releases reserved funds back to user wallet.
 *
 * @param {string} id - Withdrawal ID
 * @param {string} userId - Requesting user ID
 * @returns {Promise<Object>}
 */
const cancelWithdrawal = async (id, userId) => {
  const withdrawal = await prisma.withdrawalRequest.findFirst({
    where: { id, userId },
  });

  if (!withdrawal) {
    throw new ApiError(404, 'Permintaan penarikan tidak ditemukan.');
  }

  if (withdrawal.status !== 'PENDING_REVIEW') {
    throw new ApiError(400, 'Hanya penarikan dengan status PENDING_REVIEW yang dapat dibatalkan.');
  }

  return await prisma.$transaction(async (tx) => {
    // 1. CAS status update PENDING_REVIEW → CANCELLED
    const updateResult = await tx.withdrawalRequest.updateMany({
      where: { id, userId, status: 'PENDING_REVIEW' },
      data: {
        status: 'CANCELLED',
        failureReason: 'Dibatalkan oleh pengguna.',
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status penarikan sudah berubah.');
    }

    // 2. Release reserved balance (credit WITHDRAWAL_RELEASE)
    await ledgerService.credit(tx, {
      userId,
      amount: withdrawal.amount + withdrawal.fee,
      type: 'WITHDRAWAL_RELEASE',
      idempotencyKey: `withdrawal:${withdrawal.id}:release`,
      referenceType: 'WITHDRAWAL',
      referenceId: withdrawal.id,
      metadata: { reason: 'USER_CANCELLED' },
    });

    return await tx.withdrawalRequest.findUnique({
      where: { id },
    });
  });
};

/**
 * Retrieves withdrawal list for admin review with nameMatch score.
 *
 * @param {Object} options - { status, cursor, limit }
 * @returns {Promise<{ items: Array, nextCursor: string|null }>}
 */
const getAdminWithdrawals = async ({ status = null, cursor = null, limit = 20 } = {}) => {
  const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);

  const queryArgs = {
    where: status ? { status } : {},
    take: safeLimit + 1,
    include: {
      user: { select: { id: true, name: true, email: true } },
      bankAccount: true,
      reviewedBy: { select: { id: true, name: true } },
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  };

  if (cursor) {
    queryArgs.cursor = { id: cursor };
    queryArgs.skip = 1;
  }

  const items = await prisma.withdrawalRequest.findMany(queryArgs);

  let nextCursor = null;
  if (items.length > safeLimit) {
    items.pop();
    nextCursor = items[items.length - 1].id;
  }

  const formattedItems = items.map((w) => {
    let plainNumber;
    try {
      plainNumber = decrypt(w.bankAccount.accountNumberEnc);
    } catch {
      plainNumber = `••••••••${w.bankAccount.accountLast4}`;
    }

    return {
      id: w.id,
      userId: w.userId,
      user: w.user,
      amount: w.amount,
      fee: w.fee,
      status: w.status,
      providerRef: w.providerRef,
      failureReason: w.failureReason,
      reviewedBy: w.reviewedBy,
      reviewedAt: w.reviewedAt,
      nameMatch: calculateNameMatch(w.user.name, w.bankAccount.accountName),
      bankAccount: {
        id: w.bankAccount.id,
        bankCode: w.bankAccount.bankCode,
        accountNumberMasked: maskAccountNumber(plainNumber),
        accountLast4: w.bankAccount.accountLast4,
        accountName: w.bankAccount.accountName,
      },
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
    };
  });

  return {
    items: formattedItems,
    nextCursor,
  };
};

/**
 * Approves a withdrawal request (Admin only).
 * Sets status to PROCESSING and dispatches payout to payment provider.
 *
 * @param {string} id - Withdrawal ID
 * @param {string} adminId - Approving admin ID
 * @returns {Promise<Object>}
 */
const approveWithdrawal = async (id, adminId) => {
  const withdrawal = await prisma.withdrawalRequest.findUnique({
    where: { id },
    include: {
      bankAccount: true,
      user: true,
    },
  });

  if (!withdrawal) {
    throw new ApiError(404, 'Permintaan penarikan tidak ditemukan.');
  }

  if (withdrawal.status !== 'PENDING_REVIEW') {
    throw new ApiError(400, 'Hanya penarikan dengan status PENDING_REVIEW yang dapat disetujui.');
  }

  // 1. CAS transition PENDING_REVIEW → PROCESSING
  const updateResult = await prisma.withdrawalRequest.updateMany({
    where: { id, status: 'PENDING_REVIEW' },
    data: {
      status: 'PROCESSING',
      reviewedById: adminId,
      reviewedAt: new Date(),
    },
  });

  if (updateResult.count === 0) {
    throw new ApiError(409, 'Status penarikan sudah berubah.');
  }

  // 2. Decrypt plain bank account number for external gateway payout
  const plainAccountNumber = decrypt(withdrawal.bankAccount.accountNumberEnc);
  const provider = getPaymentProvider();

  try {
    const payoutResult = await provider.createPayout({
      referenceId: withdrawal.id,
      amount: withdrawal.amount,
      bankCode: withdrawal.bankAccount.bankCode,
      accountNumber: plainAccountNumber,
      accountName: withdrawal.bankAccount.accountName,
    });

    const updated = await prisma.withdrawalRequest.update({
      where: { id },
      data: {
        providerRef: payoutResult.providerRef || null,
        status: payoutResult.status === 'COMPLETED' ? 'COMPLETED' : 'PROCESSING',
      },
      include: {
        bankAccount: true,
        user: { select: { id: true, name: true, email: true } },
      },
    });

    return updated;
  } catch (error) {
    // If provider call immediately rejects, mark as FAILED and release reserved balance
    await prisma.$transaction(async (tx) => {
      await tx.withdrawalRequest.update({
        where: { id },
        data: {
          status: 'FAILED',
          failureReason: error.message || 'Gagal mengirim payout ke penyedia pembayaran.',
        },
      });

      await ledgerService.credit(tx, {
        userId: withdrawal.userId,
        amount: withdrawal.amount + withdrawal.fee,
        type: 'WITHDRAWAL_RELEASE',
        idempotencyKey: `withdrawal:${withdrawal.id}:release`,
        referenceType: 'WITHDRAWAL',
        referenceId: withdrawal.id,
        metadata: { reason: 'PAYOUT_DISPATCH_FAILED', error: error.message },
      });
    });

    throw error;
  }
};

/**
 * Rejects a withdrawal request (Admin only).
 * Sets status to REJECTED and releases reserved balance back to user.
 *
 * @param {string} id - Withdrawal ID
 * @param {string} adminId - Rejecting admin ID
 * @param {string} [reason] - Rejection reason
 * @returns {Promise<Object>}
 */
const rejectWithdrawal = async (id, adminId, reason = null) => {
  const withdrawal = await prisma.withdrawalRequest.findUnique({
    where: { id },
  });

  if (!withdrawal) {
    throw new ApiError(404, 'Permintaan penarikan tidak ditemukan.');
  }

  if (withdrawal.status !== 'PENDING_REVIEW') {
    throw new ApiError(400, 'Hanya penarikan dengan status PENDING_REVIEW yang dapat ditolak.');
  }

  return await prisma.$transaction(async (tx) => {
    // 1. CAS status update PENDING_REVIEW → REJECTED
    const updateResult = await tx.withdrawalRequest.updateMany({
      where: { id, status: 'PENDING_REVIEW' },
      data: {
        status: 'REJECTED',
        failureReason: reason || 'Ditolak oleh admin.',
        reviewedById: adminId,
        reviewedAt: new Date(),
      },
    });

    if (updateResult.count === 0) {
      throw new ApiError(409, 'Status penarikan sudah berubah.');
    }

    // 2. Release reserved balance (credit WITHDRAWAL_RELEASE)
    await ledgerService.credit(tx, {
      userId: withdrawal.userId,
      amount: withdrawal.amount + withdrawal.fee,
      type: 'WITHDRAWAL_RELEASE',
      idempotencyKey: `withdrawal:${withdrawal.id}:release`,
      referenceType: 'WITHDRAWAL',
      referenceId: withdrawal.id,
      metadata: { reason: 'ADMIN_REJECTED', adminId, rejectReason: reason },
    });

    return await tx.withdrawalRequest.findUnique({
      where: { id },
    });
  });
};

/**
 * Handles payout callbacks from payment provider webhook.
 * Success → COMPLETED (no new ledger entry).
 * Failure → FAILED + ledger.credit WITHDRAWAL_RELEASE.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {Object} params
 * @returns {Promise<Object>}
 */
const handlePayoutWebhook = async (
  tx,
  { withdrawal, status, failureReason, eventId: _eventId }
) => {
  if (withdrawal.status === 'COMPLETED') {
    return { success: true, message: 'Penarikan sudah berstatus COMPLETED.' };
  }

  if (['COMPLETED', 'PAID', 'SUCCEEDED', 'SETTLED'].includes(status)) {
    await tx.withdrawalRequest.updateMany({
      where: { id: withdrawal.id, status: { in: ['PROCESSING', 'PENDING_REVIEW', 'APPROVED'] } },
      data: {
        status: 'COMPLETED',
      },
    });

    // Zero new ledger entries: money was already deducted when reserved
    return { success: true, message: 'Penarikan berhasil diselesaikan.' };
  }

  if (status === 'FAILED') {
    const updateResult = await tx.withdrawalRequest.updateMany({
      where: { id: withdrawal.id, status: { in: ['PROCESSING', 'PENDING_REVIEW', 'APPROVED'] } },
      data: {
        status: 'FAILED',
        failureReason: failureReason || 'Payout gagal dari gateway bank.',
      },
    });

    if (updateResult.count === 1) {
      // Release reserved funds back to user wallet
      await ledgerService.credit(tx, {
        userId: withdrawal.userId,
        amount: withdrawal.amount + withdrawal.fee,
        type: 'WITHDRAWAL_RELEASE',
        idempotencyKey: `withdrawal:${withdrawal.id}:release`,
        referenceType: 'WITHDRAWAL',
        referenceId: withdrawal.id,
        metadata: { reason: 'PAYOUT_FAILED', failureReason },
      });
    }

    return { success: true, message: 'Penarikan ditandai FAILED dan saldo dikembalikan.' };
  }

  return { success: true, message: `Status payout diabaikan: ${status}` };
};

module.exports = {
  assertCanWithdraw,
  createWithdrawal,
  getUserWithdrawals,
  cancelWithdrawal,
  getAdminWithdrawals,
  approveWithdrawal,
  rejectWithdrawal,
  handlePayoutWebhook,
};
