// =============================================================================
// Dispute Controller - User & Participant Dispute Endpoints
// =============================================================================

const disputeService = require('../services/dispute.service');

/**
 * POST /api/transactions/:id/dispute
 * Open a dispute for a transaction (buyer only, status PAID or SHIPPED)
 */
const openDispute = async (req, res, next) => {
  try {
    const dispute = await disputeService.openDispute(req.params.id, req.user.id, req.body);

    res.status(201).json({
      success: true,
      message: 'Sengketa berhasil diajukan.',
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/disputes/:id/evidence
 * Submit additional evidence for a dispute (buyer or seller, max 10 submissions)
 */
const submitEvidence = async (req, res, next) => {
  try {
    const evidence = await disputeService.submitEvidence(req.params.id, req.user.id, req.body);

    res.status(201).json({
      success: true,
      message: 'Bukti sengketa berhasil ditambahkan.',
      data: evidence,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/disputes/:id
 * Get dispute details by dispute ID (participants and admin only)
 */
const getDisputeById = async (req, res, next) => {
  try {
    const dispute = await disputeService.getDisputeById(req.params.id, req.user);

    res.status(200).json({
      success: true,
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/transactions/:id/dispute
 * Get dispute details for a specific transaction (participants and admin only)
 */
const getDisputeByTransactionId = async (req, res, next) => {
  try {
    const dispute = await disputeService.getDisputeByTransactionId(req.params.id, req.user);

    res.status(200).json({
      success: true,
      data: dispute,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  openDispute,
  submitEvidence,
  getDisputeById,
  getDisputeByTransactionId,
};
