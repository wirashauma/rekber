// =============================================================================
// Notification Service - Persistence, FCM Dispatch & User Inbox
// =============================================================================

const prisma = require('../config/prisma');
const { ApiError } = require('../middlewares/error.middleware');
const { logger } = require('../config/logger');
const { getFcmProvider } = require('../providers/fcm');

/**
 * Persists a notification to the database and sends a push notification via FCM.
 * Push notification failure will NOT throw or abort the primary transaction flow.
 *
 * @param {string} userId
 * @param {Object} params
 * @param {string} params.type
 * @param {string} params.title
 * @param {string} params.body
 * @param {Object} [params.data]
 * @returns {Promise<Object>} Created database notification
 */
const notify = async (userId, { type, title, body, data = {} }) => {
  // 1. Persist notification to database
  const notification = await prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      data,
    },
  });

  // 2. Dispatch FCM push notification (non-blocking, post-commit)
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, fcmToken: true },
    });

    if (user && user.fcmToken) {
      const fcmProvider = getFcmProvider();
      await fcmProvider.send({
        token: user.fcmToken,
        title,
        body,
        data,
      });
    }
  } catch (err) {
    logger.warn(
      { userId, type, error: err.message, code: err.code },
      'Gagal mengirim FCM push notification'
    );

    // Clean up invalid or expired FCM registration tokens
    const isTokenInvalid =
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token' ||
      err.message?.includes('not-registered') ||
      err.message?.includes('invalid-registration-token');

    if (isTokenInvalid) {
      try {
        await prisma.user.update({
          where: { id: userId },
          data: { fcmToken: null },
        });
        logger.info({ userId }, 'FCM token tidak valid, telah dibersihkan dari profil user.');
      } catch (cleanupErr) {
        logger.warn({ userId, error: cleanupErr.message }, 'Gagal membersihkan FCM token');
      }
    }
  }

  return notification;
};

/**
 * Retrieve notifications for a user with cursor and page pagination.
 *
 * @param {string} userId
 * @param {Object} query
 * @param {number} [query.limit=20]
 * @param {string} [query.cursor]
 * @param {number} [query.page]
 * @returns {Promise<{ notifications: Array, nextCursor: string|null, hasMore: boolean }>}
 */
const getNotifications = async (userId, { limit = 20, cursor, page }) => {
  const parsedLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  const queryOptions = {
    where: { userId },
    take: parsedLimit + 1,
    orderBy: { createdAt: 'desc' },
  };

  if (cursor) {
    queryOptions.cursor = { id: cursor };
    queryOptions.skip = 1;
  } else if (page && parseInt(page, 10) > 1) {
    queryOptions.skip = (parseInt(page, 10) - 1) * parsedLimit;
  }

  const items = await prisma.notification.findMany(queryOptions);

  let nextCursor = null;
  let hasMore = false;

  if (items.length > parsedLimit) {
    hasMore = true;
    const extra = items.pop();
    nextCursor = extra.id;
  }

  return {
    notifications: items,
    nextCursor,
    hasMore,
  };
};

/**
 * Get total unread notifications count for a user.
 *
 * @param {string} userId
 * @returns {Promise<{ unreadCount: number }>}
 */
const getUnreadCount = async (userId) => {
  const count = await prisma.notification.count({
    where: {
      userId,
      readAt: null,
    },
  });

  return { unreadCount: count };
};

/**
 * Mark a single notification as read.
 * User can only mark their own notification.
 *
 * @param {string} userId
 * @param {string} notificationId
 * @returns {Promise<Object>}
 */
const markAsRead = async (userId, notificationId) => {
  const notification = await prisma.notification.findUnique({
    where: { id: notificationId },
  });

  if (!notification || notification.userId !== userId) {
    throw new ApiError(404, 'Notifikasi tidak ditemukan.');
  }

  if (notification.readAt) {
    return notification;
  }

  return await prisma.notification.update({
    where: { id: notificationId },
    data: { readAt: new Date() },
  });
};

/**
 * Mark all unread notifications as read for a user.
 *
 * @param {string} userId
 * @returns {Promise<{ count: number }>}
 */
const markAllAsRead = async (userId) => {
  const result = await prisma.notification.updateMany({
    where: {
      userId,
      readAt: null,
    },
    data: {
      readAt: new Date(),
    },
  });

  return { count: result.count };
};

module.exports = {
  notify,
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
};
