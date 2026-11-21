// =============================================================================
// Dispute Routes - User & Participant Dispute Endpoints
// =============================================================================

const express = require('express');
const router = express.Router();
const disputeController = require('../controllers/dispute.controller');
const { authenticate } = require('../middlewares/auth.middleware');
const { submitEvidenceRules, getDisputeRules } = require('../validators/dispute.validator');
const { validate } = require('../middlewares/validate.middleware');

// All dispute routes require authentication
router.use(authenticate);

// POST /api/disputes/:id/evidence
// Submit additional evidence for a dispute (buyer or seller, max 10 submissions)
router.post('/:id/evidence', submitEvidenceRules, validate, disputeController.submitEvidence);

// GET /api/disputes/:id
// Get dispute details by dispute ID (participants and admin only)
router.get('/:id', getDisputeRules, validate, disputeController.getDisputeById);

module.exports = router;
