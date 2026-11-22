// =============================================================================
// Admin Platform Settings Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminSettingController = require('../controllers/admin.setting.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/settings
router.get('/', adminSettingController.getSettings);

// PUT /admin/settings
router.put('/', adminSettingController.updateSettings);

module.exports = router;
