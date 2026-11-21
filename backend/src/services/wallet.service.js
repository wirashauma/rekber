// =============================================================================
// Wallet Service - Wallet Summary & User Balance Oversight
// =============================================================================

const prisma = require('../config/prisma');
const ledgerService = require('./ledger.service');
const { ApiError } = require('../middlewares/error.middleware');

/**
 * Get wallet summary for an authenticated user.
 * Returns available balance and total funds currently held in active escrow.
 *
 * @param {string} userId - User UUID
 * @returns {Promise<{ balance: bigint, heldBalance: bigint, currency: string }>}
 */
const getWalletSummary = async (userId) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { balance: true },
  });

  if (!user) {
    throw new ApiError(404, 'Pengguna tidak ditemukan.');
  }

  // Aggregate active held amounts where this user is buyer
  const heldAgg = await prisma.transaction.aggregate({
    where: {
      buyerId: userId,
      status: { in: ['PAID', 'SHIPPED', 'DISPUTED'] },
    },
    _sum: {
      heldAmount: true,
    },
  });

  return {
    balance: user.balance,
    heldBalance: heldAgg._sum.heldAmount || 0n,
    currency: 'IDR',
  };
};

/**
 * Get paginated ledger history for the user.
 *
 * @param {string} userId - User UUID
 * @param {Object} options - { cursor, limit }
 * @returns {Promise<{ items: Array, nextCursor: string|null }>}
 */
const getLedgerHistory = async (userId, options) => {
  return await ledgerService.getLedgerEntries(userId, options);
};

module.exports = {
  getWalletSummary,
  getLedgerHistory,
};
