// =============================================================================
// Admin Dispute Controller - Platform Dispute Resolution & Review
// =============================================================================

const disputeService = require('../services/dispute.service');

/**
 * GET /api/admin/disputes
 * List disputes with optional status filter and pagination
 */
const getAdminDisputes = async (req, res, next) => {
  try {
    const result = await disputeService.getAdminDisputes(req.query);

    res.status(200).json({
      success: true,
      data: result.disputes,
      pagination: result.pagination,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/admin/disputes/:id
 * Get full dispute review details for admin
 */
const getAdminDisputeById = async (req, res, next) => {
  try {
    const dispute = await disputeService.getAdminDisputeById(req.params.id);

    res.status(200).json({
      success: true,
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/admin/disputes/:id/review
 * Transition dispute status from OPEN to UNDER_REVIEW
 */
const reviewDispute = async (req, res, next) => {
  try {
    const dispute = await disputeService.reviewDispute(req.params.id, req.user.id);

    res.status(200).json({
      success: true,
      message: 'Sengketa sedang ditinjau oleh admin.',
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/admin/disputes/:id/resolve
 * Resolve dispute atomically with escrow release or refund
 */
const resolveDispute = async (req, res, next) => {
  try {
    const dispute = await disputeService.resolveDispute(req.params.id, req.user.id, req.body);

    res.status(200).json({
      success: true,
      message: 'Sengketa berhasil diselesaikan.',
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAdminDisputes,
  getAdminDisputeById,
  reviewDispute,
  resolveDispute,
};
