// =============================================================================
// Admin Transaction Management Controller
// =============================================================================

const prisma = require('../config/prisma');

/**
 * GET /admin/transactions
 * Retrieve all transactions across the platform with filtering by status, date, and user.
 */
const getTransactions = async (req, res, next) => {
  try {
    const { status, startDate, endDate, userId, cursor, limit = 20 } = req.query;
    const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

    const where = {};

    if (status) {
      where.status = status;
    }

    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = new Date(startDate);
      if (endDate) where.createdAt.lte = new Date(endDate);
    }

    if (userId) {
      where.OR = [{ buyerId: userId }, { sellerId: userId }];
    }

    const queryOptions = {
      where,
      take: parsedLimit + 1,
      orderBy: { createdAt: 'desc' },
      include: {
        buyer: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        seller: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        shipmentProof: true,
        dispute: {
          select: {
            id: true,
            status: true,
            reason: true,
          },
        },
      },
    };

    if (cursor) {
      queryOptions.cursor = { id: cursor };
      queryOptions.skip = 1;
    }

    const items = await prisma.transaction.findMany(queryOptions);

    let nextCursor = null;
    let hasMore = false;

    if (items.length > parsedLimit) {
      hasMore = true;
      const extra = items.pop();
      nextCursor = extra.id;
    }

    res.status(200).json({
      success: true,
      data: items,
      nextCursor,
      hasMore,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getTransactions,
};
