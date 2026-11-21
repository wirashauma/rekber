// =============================================================================
// Admin Dispute Routes - Platform Dispute Management & Resolution
// =============================================================================

const express = require('express');
const router = express.Router();
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const {
  adminListDisputesRules,
  getDisputeRules,
  resolveDisputeRules,
} = require('../validators/dispute.validator');
const adminDisputeController = require('../controllers/admin.dispute.controller');

// All admin dispute routes require authentication and ADMIN role
router.use(authenticate, authorize('ADMIN'));

/**
 * GET /api/admin/disputes
 * List disputes with optional status filter and pagination
 */
router.get('/', adminListDisputesRules, validate, adminDisputeController.getAdminDisputes);

/**
 * GET /api/admin/disputes/:id
 * Get full dispute review details for admin
 */
router.get('/:id', getDisputeRules, validate, adminDisputeController.getAdminDisputeById);

/**
 * POST /api/admin/disputes/:id/review
 * Transition dispute status from OPEN to UNDER_REVIEW
 */
router.post('/:id/review', getDisputeRules, validate, adminDisputeController.reviewDispute);

/**
 * POST /api/admin/disputes/:id/resolve
 * Resolve dispute atomically with escrow release or refund
 */
router.post('/:id/resolve', resolveDisputeRules, validate, adminDisputeController.resolveDispute);

module.exports = router;
