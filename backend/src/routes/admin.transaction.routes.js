// =============================================================================
// Admin Transaction Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const adminTransactionController = require('../controllers/admin.transaction.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.use(authenticate, authorize('ADMIN'));

// GET /admin/transactions
router.get('/', adminTransactionController.getTransactions);

module.exports = router;
