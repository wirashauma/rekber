// =============================================================================
// Notification Validator - Request Validation Rules
// =============================================================================

const { param, query } = require('express-validator');

const listNotificationsRules = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Batas per halaman (limit) antara 1 hingga 100.'),

  query('cursor').optional().isUUID().withMessage('Cursor harus berformat UUID.'),

  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Halaman (page) harus berupa bilangan bulat positif.'),
];

const notificationIdRules = [
  param('id').isUUID().withMessage('ID notifikasi harus berformat UUID.'),
];

module.exports = {
  listNotificationsRules,
  notificationIdRules,
};
