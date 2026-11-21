// =============================================================================
// Config Routes (Public Configuration)
// =============================================================================

const express = require('express');
const router = express.Router();
const settingsService = require('../services/settings.service');

/**
 * GET /api/config/public
 * Returns public platform configuration settings without authentication.
 */
router.get('/public', async (req, res, next) => {
  try {
    const [
      fee_percent,
      fee_min,
      fee_payer_default,
      withdraw_min,
      withdraw_fee,
      max_transaction_amount,
    ] = await Promise.all([
      settingsService.getNumber('fee_percent'),
      settingsService.getNumber('fee_min'),
      settingsService.getString('fee_payer_default'),
      settingsService.getNumber('withdraw_min'),
      settingsService.getNumber('withdraw_fee'),
      settingsService.getNumber('max_transaction_amount'),
    ]);

    res.status(200).json({
      success: true,
      data: {
        fee_percent,
        fee_min,
        fee_payer_default,
        withdraw_min,
        withdraw_fee,
        max_transaction_amount,
      },
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
