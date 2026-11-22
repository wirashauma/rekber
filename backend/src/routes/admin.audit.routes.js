// =============================================================================
// Admin Audit Log Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminAuditController = require('../controllers/admin.audit.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/audit-logs
router.get('/', adminAuditController.getAuditLogs);

module.exports = router;
