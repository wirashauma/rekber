// =============================================================================
// Admin Withdrawal Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { withdrawalIdRules, rejectWithdrawalRules } = require('../validators/withdrawal.validator');
const adminWithdrawalController = require('../controllers/admin.withdrawal.controller');

// All admin withdrawal routes require authentication and ADMIN role
router.use(authenticate, authorize('ADMIN'));

/**
 * GET /api/admin/withdrawals
 * List withdrawals with optional status query and cursor pagination
 */
router.get('/', adminWithdrawalController.getAdminWithdrawals);

/**
 * POST /api/admin/withdrawals/:id/approve
 * Approve withdrawal and trigger external payout
 */
router.post(
  '/:id/approve',
  withdrawalIdRules,
  validate,
  adminWithdrawalController.approveWithdrawal
);

/**
 * POST /api/admin/withdrawals/:id/reject
 * Reject withdrawal and return funds to user
 */
router.post(
  '/:id/reject',
  rejectWithdrawalRules,
  validate,
  adminWithdrawalController.rejectWithdrawal
);

module.exports = router;
