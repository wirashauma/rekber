// =============================================================================
// Admin Metric Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminMetricController = require('../controllers/admin.metric.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/metrics
router.get('/', adminMetricController.getMetrics);

module.exports = router;
