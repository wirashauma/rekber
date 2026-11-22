// =============================================================================
// Notification Controller - User Notification Inbox Handlers
// =============================================================================

const notificationService = require('../services/notification.service');

/**
 * GET /api/notifications
 * Get user notifications with cursor or page pagination
 */
const getNotifications = async (req, res, next) => {
  try {
    const result = await notificationService.getNotifications(req.user.id, req.query);

    res.status(200).json({
      success: true,
      data: result.notifications,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/notifications/unread-count
 * Get count of unread notifications
 */
const getUnreadCount = async (req, res, next) => {
  try {
    const result = await notificationService.getUnreadCount(req.user.id);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notifications/:id/read
 * Mark a single notification as read
 */
const markAsRead = async (req, res, next) => {
  try {
    const notification = await notificationService.markAsRead(req.user.id, req.params.id);

    res.status(200).json({
      success: true,
      message: 'Notifikasi ditandai telah dibaca.',
      data: notification,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/notifications/read-all
 * Mark all unread notifications as read
 */
const markAllAsRead = async (req, res, next) => {
  try {
    const result = await notificationService.markAllAsRead(req.user.id);

    res.status(200).json({
      success: true,
      message: 'Semua notifikasi ditandai telah dibaca.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
};
