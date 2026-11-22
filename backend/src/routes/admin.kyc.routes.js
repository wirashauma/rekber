// =============================================================================
// Admin KYC Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminKycController = require('../controllers/admin.kyc.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');
const { listKycRules, getKycRules, rejectKycRules } = require('../validators/kyc.validator');
const { validate } = require('../middlewares/validate.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/kyc?status=
router.get('/', listKycRules, validate, adminKycController.getAdminKycSubmissions);

// GET /admin/kyc/:id
router.get('/:id', getKycRules, validate, adminKycController.getAdminKycById);

// POST /admin/kyc/:id/approve
router.post('/:id/approve', getKycRules, validate, adminKycController.approveKyc);

// POST /admin/kyc/:id/reject
router.post('/:id/reject', rejectKycRules, validate, adminKycController.rejectKyc);

module.exports = router;
