// =============================================================================
// Ledger Service - Atomic, Idempotent Financial Double-Entry Accounting
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { parseInteger } = require('../utils/money');

/**
 * Computes a deterministic 63-bit integer hash for PostgreSQL advisory locks.
 */
const hashKeyToBigInt = (key) => {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c64e6d;
  for (let i = 0; i < key.length; i++) {
    const ch = key.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  const combined = (BigInt(h1 >>> 0) << 32n) | BigInt(h2 >>> 0);
  return combined & 0x7fffffffffffffffn;
};

/**
 * Execute a credit operation atomically within a Prisma transaction.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {Object} params
 * @param {string|null} params.userId - User ID or null for platform revenue
 * @param {number|string|bigint} params.amount - Positive amount (rupiah bulat)
 * @param {string} params.type - LedgerType enum (TOPUP, ESCROW_RELEASE, ESCROW_REFUND, PLATFORM_FEE, ADJUSTMENT, etc.)
 * @param {string} params.idempotencyKey - Unique idempotency key
 * @param {string} [params.transactionId] - Optional transaction ID
 * @param {string} [params.referenceType] - e.g. 'TRANSACTION', 'TOPUP'
 * @param {string} [params.referenceId] - Reference ID (e.g. transaction UUID)
 * @param {Object} [params.metadata] - Optional arbitrary metadata
 * @returns {Promise<Object>} Created or existing LedgerEntry
 */
const credit = async (
  tx,
  {
    userId = null,
    amount,
    type,
    idempotencyKey,
    transactionId = null,
    referenceType = null,
    referenceId = null,
    metadata = null,
  }
) => {
  if (!idempotencyKey) {
    throw new ApiError(400, 'Idempotency key wajib disertakan untuk setiap mutasi saldo.');
  }

  // 1. Acquire transaction-level advisory lock on idempotencyKey hash to serialize parallel requests
  const lockId = hashKeyToBigInt(idempotencyKey);
  await tx.$executeRawUnsafe(`SELECT pg_advisory_xact_lock(CAST(${lockId} AS bigint))`);

  // 2. Check if idempotencyKey already exists (idempotent replay)
  const existing = await tx.ledgerEntry.findUnique({
    where: { idempotencyKey },
  });
  if (existing) {
    return existing;
  }

  const parsedAmount = parseInteger(amount, { min: 1 });

  let balanceAfter;

  // 2. Perform credit: update user balance if userId is provided
  if (userId) {
    const updatedUser = await tx.user.update({
      where: { id: userId },
      data: { balance: { increment: parsedAmount } },
      select: { balance: true },
    });
    balanceAfter = updatedUser.balance;
  } else {
    // Platform credit (userId === null, e.g. PLATFORM_FEE)
    const agg = await tx.ledgerEntry.aggregate({
      where: { userId: null },
      _sum: { amount: true },
    });
    balanceAfter = (agg._sum.amount || 0n) + parsedAmount;
  }

  // 3. Write LedgerEntry with balanceAfter
  try {
    const entry = await tx.ledgerEntry.create({
      data: {
        userId,
        transactionId: transactionId || (referenceType === 'TRANSACTION' ? referenceId : null),
        type,
        direction: 'CREDIT',
        amount: parsedAmount,
        balanceAfter,
        idempotencyKey,
        referenceType: referenceType || (transactionId ? 'TRANSACTION' : null),
        referenceId: referenceId || transactionId || null,
        metadata: metadata || null,
      },
    });
    return entry;
  } catch (err) {
    // Handle concurrent unique constraint violation on idempotency_key
    if (err.code === 'P2002' && err.meta?.target?.includes('idempotency_key')) {
      const existingEntry = await tx.ledgerEntry.findUnique({ where: { idempotencyKey } });
      if (existingEntry) return existingEntry;
    }
    throw err;
  }
};

/**
 * Execute a debit operation atomically within a Prisma transaction.
 * Uses conditional update (balance >= amount) and checks affected rows count.
 *
 * @param {Object} tx - Prisma transaction client
 * @param {Object} params
 * @param {string} params.userId - User ID (cannot be null for debit)
 * @param {number|string|bigint} params.amount - Positive amount (rupiah bulat)
 * @param {string} params.type - LedgerType enum (ESCROW_HOLD, WITHDRAWAL_RESERVE, ADJUSTMENT, etc.)
 * @param {string} params.idempotencyKey - Unique idempotency key
 * @param {string} [params.transactionId] - Optional transaction ID
 * @param {string} [params.referenceType] - e.g. 'TRANSACTION'
 * @param {string} [params.referenceId] - Reference ID (e.g. transaction UUID)
 * @param {Object} [params.metadata] - Optional arbitrary metadata
 * @returns {Promise<Object>} Created or existing LedgerEntry
 */
const debit = async (
  tx,
  {
    userId,
    amount,
    type,
    idempotencyKey,
    transactionId = null,
    referenceType = null,
    referenceId = null,
    metadata = null,
  }
) => {
  if (!idempotencyKey) {
    throw new ApiError(400, 'Idempotency key wajib disertakan untuk setiap mutasi saldo.');
  }

  // 1. Acquire transaction-level advisory lock on idempotencyKey hash to serialize parallel requests
  const lockId = hashKeyToBigInt(idempotencyKey);
  await tx.$executeRawUnsafe(`SELECT pg_advisory_xact_lock(CAST(${lockId} AS bigint))`);

  // 2. Check if idempotencyKey already exists (idempotent replay)
  const existing = await tx.ledgerEntry.findUnique({
    where: { idempotencyKey },
  });
  if (existing) {
    return existing;
  }

  if (!userId) {
    throw new ApiError(400, 'User ID wajib diisi untuk operasi debit saldo.');
  }

  const parsedAmount = parseInteger(amount, { min: 1 });

  // 2. Conditional UPDATE (balance >= amount) to prevent race conditions and overdrafts
  const updateResult = await tx.user.updateMany({
    where: {
      id: userId,
      balance: { gte: parsedAmount },
    },
    data: {
      balance: { decrement: parsedAmount },
    },
  });

  if (updateResult.count === 0) {
    // Check whether the user exists or merely has insufficient balance
    const user = await tx.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new ApiError(404, 'Pengguna tidak ditemukan.');
    }
    throw new ApiError(400, 'Saldo tidak mencukupi untuk melakukan transaksi ini.');
  }

  // 3. Retrieve accurate balanceAfter
  const updatedUser = await tx.user.findUnique({
    where: { id: userId },
    select: { balance: true },
  });
  const balanceAfter = updatedUser.balance;

  // 4. Write LedgerEntry with balanceAfter
  try {
    const entry = await tx.ledgerEntry.create({
      data: {
        userId,
        transactionId: transactionId || (referenceType === 'TRANSACTION' ? referenceId : null),
        type,
        direction: 'DEBIT',
        amount: parsedAmount,
        balanceAfter,
        idempotencyKey,
        referenceType: referenceType || (transactionId ? 'TRANSACTION' : null),
        referenceId: referenceId || transactionId || null,
        metadata: metadata || null,
      },
    });
    return entry;
  } catch (err) {
    // Handle concurrent unique constraint violation on idempotency_key
    if (err.code === 'P2002' && err.meta?.target?.includes('idempotency_key')) {
      const existingEntry = await tx.ledgerEntry.findUnique({ where: { idempotencyKey } });
      if (existingEntry) return existingEntry;
    }
    throw err;
  }
};

/**
 * Fetch paginated ledger entries for a user using cursor pagination.
 *
 * @param {string} userId - User UUID
 * @param {Object} options - { cursor, limit }
 * @returns {Promise<{ items: Array, nextCursor: string|null }>}
 */
const getLedgerEntries = async (userId, { cursor = null, limit = 20 } = {}) => {
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

  const items = await prisma.ledgerEntry.findMany(queryArgs);

  let nextCursor = null;
  if (items.length > safeLimit) {
    const nextItem = items.pop();
    nextCursor = nextItem.id;
  }

  return {
    items,
    nextCursor,
  };
};

module.exports = {
  credit,
  debit,
  getLedgerEntries,
};
