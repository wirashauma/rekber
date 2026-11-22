// =============================================================================
// Admin Metric Controller - Platform Overview & Analytics
// =============================================================================

const prisma = require('../config/prisma');
const { toSafeNumber } = require('../utils/money');

/**
 * GET /admin/metrics
 * Returns platform financial and operational metrics within an optional date range.
 */
const getMetrics = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    const [
      gmvResult,
      statusGroups,
      heldResult,
      feeResult,
      newUsers,
      openDisputes,
      pendingWithdrawals,
    ] = await Promise.all([
      // 1. GMV: Total amount of completed transactions in period
      prisma.transaction.aggregate({
        _sum: { amount: true },
        where: {
          status: 'COMPLETED',
          createdAt: { gte: start, lte: end },
        },
      }),

      // 2. Transaction count grouped by status in period
      prisma.transaction.groupBy({
        by: ['status'],
        _count: { id: true },
        where: {
          createdAt: { gte: start, lte: end },
        },
      }),

      // 3. Current held amount in active escrow (PAID, SHIPPED, DISPUTED)
      prisma.transaction.aggregate({
        _sum: { heldAmount: true },
        where: {
          status: { in: ['PAID', 'SHIPPED', 'DISPUTED'] },
        },
      }),

      // 4. Platform fee revenue earned in period
      prisma.transaction.aggregate({
        _sum: {
          buyerFee: true,
          sellerFee: true,
        },
        where: {
          status: 'COMPLETED',
          createdAt: { gte: start, lte: end },
        },
      }),

      // 5. New registered users in period
      prisma.user.count({
        where: {
          createdAt: { gte: start, lte: end },
        },
      }),

      // 6. Currently open disputes
      prisma.dispute.count({
        where: {
          status: { in: ['OPEN', 'UNDER_REVIEW'] },
        },
      }),

      // 7. Withdrawals waiting for review
      prisma.withdrawalRequest.count({
        where: {
          status: 'PENDING_REVIEW',
        },
      }),
    ]);

    // Build complete status map
    const defaultStatuses = {
      PENDING: 0,
      PAID: 0,
      SHIPPED: 0,
      COMPLETED: 0,
      CANCELLED: 0,
      REFUNDED: 0,
      DISPUTED: 0,
    };
    for (const group of statusGroups) {
      defaultStatuses[group.status] = group._count.id;
    }

    const gmv = toSafeNumber(gmvResult._sum.amount || 0n);
    const heldAmount = toSafeNumber(heldResult._sum.heldAmount || 0n);
    const platformFeeRevenue = toSafeNumber(
      (feeResult._sum.buyerFee || 0n) + (feeResult._sum.sellerFee || 0n)
    );

    res.status(200).json({
      success: true,
      data: {
        dateRange: {
          startDate: start.toISOString(),
          endDate: end.toISOString(),
        },
        gmv,
        transactionsByStatus: defaultStatuses,
        heldAmount,
        platformFeeRevenue,
        newUsers,
        openDisputes,
        pendingWithdrawals,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getMetrics,
};
