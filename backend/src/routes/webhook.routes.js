// =============================================================================
// Webhook Routes (Mounted BEFORE express.json with express.raw)
// =============================================================================

const express = require('express');
const router = express.Router();
const topupController = require('../controllers/topup.controller');

/**
 * POST /webhooks/payment/:provider
 * Handles payment provider callbacks (Xendit, Fake, etc.)
 */
router.post('/:provider', topupController.handleWebhook);

module.exports = router;
