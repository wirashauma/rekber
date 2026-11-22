// =============================================================================
// KYC Routes - User Identity Verification Endpoints
// =============================================================================

const express = require('express');
const router = express.Router();
const kycController = require('../controllers/kyc.controller');
const { authenticate } = require('../middlewares/auth.middleware');
const { submitKycRules } = require('../validators/kyc.validator');
const { validate } = require('../middlewares/validate.middleware');

router.use(authenticate);

// POST /kyc & /api/kyc
router.post('/', submitKycRules, validate, kycController.submitKyc);

// GET /kyc/me & /api/kyc/me
router.get('/me', kycController.getMyKyc);

module.exports = router;
