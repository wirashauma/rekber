// =============================================================================
// Admin User Management Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminUserController = require('../controllers/admin.user.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const { param, body } = require('express-validator');
const { validate } = require('../middlewares/validate.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/users?search&status
router.get('/', adminUserController.getUsers);

// GET /admin/users/:id
router.get(
  '/:id',
  [param('id').isUUID(4).withMessage('ID pengguna harus berupa UUID v4 yang valid.')],
  validate,
  adminUserController.getUserById
);

// POST /admin/users/:id/ban
router.post(
  '/:id/ban',
  [
    param('id').isUUID(4).withMessage('ID pengguna harus berupa UUID v4 yang valid.'),
    body('reason')
      .isString()
      .trim()
      .isLength({ min: 3, max: 500 })
      .withMessage('Alasan pemblokiran minimal 3 karakter.'),
  ],
  validate,
  adminUserController.banUser
);

// POST /admin/users/:id/unban
router.post(
  '/:id/unban',
  [param('id').isUUID(4).withMessage('ID pengguna harus berupa UUID v4 yang valid.')],
  validate,
  adminUserController.unbanUser
);

module.exports = router;
