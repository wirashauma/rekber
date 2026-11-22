// =============================================================================
// Notification Routes - User Notification Inbox API
// =============================================================================

const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notification.controller');
const { authenticate } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const {
  listNotificationsRules,
  notificationIdRules,
} = require('../validators/notification.validator');

// All notification endpoints require user authentication
router.use(authenticate);

// GET /api/notifications
router.get('/', listNotificationsRules, validate, notificationController.getNotifications);

// GET /api/notifications/unread-count
router.get('/unread-count', notificationController.getUnreadCount);

// POST /api/notifications/:id/read
router.post('/:id/read', notificationIdRules, validate, notificationController.markAsRead);

// POST /api/notifications/read-all
router.post('/read-all', notificationController.markAllAsRead);

module.exports = router;
