// =============================================================================
// Audit Service - Administrative Audit Logging & Inquiry
// =============================================================================

const prisma = require('../config/prisma');
const { logger } = require('../config/logger');

/**
 * Records an immutable administrative audit log entry.
 *
 * @param {Object} params
 * @param {string} [params.actorId] - User ID of the administrator
 * @param {string} params.action - Action name (e.g. KYC_APPROVE, WITHDRAWAL_REJECT)
 * @param {string} params.targetType - Resource type (e.g. KYC_SUBMISSION, USER)
 * @param {string} params.targetId - Resource ID
 * @param {Object} [params.before] - Snapshot before action
 * @param {Object} [params.after] - Snapshot after action
 * @param {string} [params.ip] - IP address of the actor
 * @returns {Promise<Object|null>}
 */
const log = async ({
  actorId,
  action,
  targetType,
  targetId,
  before = null,
  after = null,
  ip = null,
}) => {
  try {
    return await prisma.auditLog.create({
      data: {
        actorId: actorId || null,
        action,
        targetType,
        targetId: String(targetId),
        before: before ? JSON.parse(JSON.stringify(before)) : null,
        after: after ? JSON.parse(JSON.stringify(after)) : null,
        ip: ip || null,
      },
    });
  } catch (err) {
    logger.warn({ err: err.message, action, targetType, targetId }, 'Gagal mencatat audit log');
    return null;
  }
};

/**
 * Retrieves paginated audit logs with filtering by actor, action, target, and date range.
 *
 * @param {Object} query
 * @param {string} [query.actorId]
 * @param {string} [query.action]
 * @param {string} [query.targetType]
 * @param {string} [query.startDate]
 * @param {string} [query.endDate]
 * @param {string} [query.cursor]
 * @param {number} [query.limit=20]
 * @returns {Promise<{ logs: Array, nextCursor: string|null, hasMore: boolean }>}
 */
const getAuditLogs = async ({
  actorId,
  action,
  targetType,
  startDate,
  endDate,
  cursor,
  limit = 20,
}) => {
  const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  const where = {};

  if (actorId) where.actorId = actorId;
  if (action) where.action = action;
  if (targetType) where.targetType = targetType;

  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = new Date(startDate);
    if (endDate) where.createdAt.lte = new Date(endDate);
  }

  const queryOptions = {
    where,
    take: parsedLimit + 1,
    orderBy: { createdAt: 'desc' },
    include: {
      actor: {
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
        },
      },
    },
  };

  if (cursor) {
    queryOptions.cursor = { id: cursor };
    queryOptions.skip = 1;
  }

  const items = await prisma.auditLog.findMany(queryOptions);

  let nextCursor = null;
  let hasMore = false;

  if (items.length > parsedLimit) {
    hasMore = true;
    const extra = items.pop();
    nextCursor = extra.id;
  }

  return {
    logs: items,
    nextCursor,
    hasMore,
  };
};

module.exports = {
  log,
  getAuditLogs,
};
