// =============================================================================
// Reconcile Service - Read-Only Double-Entry Audit & Integrity Verifier
// =============================================================================

const prisma = require('../config/prisma');

/**
 * Perform a complete reconciliation of all user balances and escrow held balances.
 *
 * Checks:
 * 1. User Balance Integrity:
 *    For every user with balance or ledger entries:
 *    balance == (total credits - total debits).
 *
 * 2. Escrow Held Amount Integrity:
 *    - All active escrow transactions (PAID, SHIPPED, DISPUTED) must have heldAmount == amount + buyerFee.
 *    - All inactive transactions (PENDING, COMPLETED, CANCELLED, REFUNDED) must have heldAmount == 0.
 *
 * @returns {Promise<{ isReconciled: boolean, userDiscrepancies: Array, escrowDiscrepancies: Array, stats: Object }>}
 */
const reconcile = async () => {
  const userDiscrepancies = [];
  const escrowDiscrepancies = [];

  // 1. Audit user balances against ledger entries
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      balance: true,
    },
  });

  for (const user of users) {
    const [creditAgg, debitAgg] = await Promise.all([
      prisma.ledgerEntry.aggregate({
        where: { userId: user.id, direction: 'CREDIT' },
        _sum: { amount: true },
      }),
      prisma.ledgerEntry.aggregate({
        where: { userId: user.id, direction: 'DEBIT' },
        _sum: { amount: true },
      }),
    ]);

    const totalCredits = creditAgg._sum.amount || 0n;
    const totalDebits = debitAgg._sum.amount || 0n;
    const expectedBalance = totalCredits - totalDebits;

    if (user.balance !== expectedBalance) {
      userDiscrepancies.push({
        userId: user.id,
        email: user.email,
        currentBalance: user.balance,
        totalCredits,
        totalDebits,
        expectedBalance,
        diff: user.balance - expectedBalance,
      });
    }
  }

  // 2. Audit escrow held amounts
  const transactions = await prisma.transaction.findMany({
    select: {
      id: true,
      code: true,
      status: true,
      amount: true,
      buyerFee: true,
      heldAmount: true,
    },
  });

  const activeStatuses = ['PAID', 'SHIPPED', 'DISPUTED'];
  let totalActiveHeld = 0n;

  for (const tx of transactions) {
    if (activeStatuses.includes(tx.status)) {
      const expectedHeld = tx.amount + tx.buyerFee;
      if (tx.heldAmount !== expectedHeld) {
        escrowDiscrepancies.push({
          transactionId: tx.id,
          code: tx.code,
          status: tx.status,
          currentHeldAmount: tx.heldAmount,
          expectedHeldAmount: expectedHeld,
          diff: tx.heldAmount - expectedHeld,
        });
      }
      totalActiveHeld += tx.heldAmount;
    } else {
      // Inactive / terminal states must have heldAmount == 0
      if (tx.heldAmount !== 0n) {
        escrowDiscrepancies.push({
          transactionId: tx.id,
          code: tx.code,
          status: tx.status,
          currentHeldAmount: tx.heldAmount,
          expectedHeldAmount: 0n,
          diff: tx.heldAmount,
        });
      }
    }
  }

  const isReconciled = userDiscrepancies.length === 0 && escrowDiscrepancies.length === 0;

  return {
    isReconciled,
    userDiscrepancies,
    escrowDiscrepancies,
    stats: {
      totalUsersAudited: users.length,
      totalTransactionsAudited: transactions.length,
      totalActiveHeldAmount: totalActiveHeld,
    },
  };
};

module.exports = {
  reconcile,
};
