// =============================================================================
// Wallet Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth.middleware');
const { topUpLimiter } = require('../middlewares/rateLimit.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { createTopUpRules, getTopUpRules } = require('../validators/topup.validator');
const { createWithdrawalRules, withdrawalIdRules } = require('../validators/withdrawal.validator');
const topupController = require('../controllers/topup.controller');
const withdrawalController = require('../controllers/withdrawal.controller');
const walletService = require('../services/wallet.service');

// All wallet routes require authentication
router.use(authenticate);

/**
 * POST /api/wallet/topups
 * Create a new top-up intent (QRIS or Virtual Account)
 */
router.post('/topups', topUpLimiter, createTopUpRules, validate, topupController.createTopUp);

/**
 * GET /api/wallet/topups/:id
 * Retrieve details of a specific top-up intent
 */
router.get('/topups/:id', getTopUpRules, validate, topupController.getTopUpById);

/**
 * GET /api/wallet/topups
 * List top-up intents with cursor pagination
 */
router.get('/topups', topupController.getTopUps);

/**
 * GET /api/wallet
 * Returns available balance and held escrow balance for the user.
 */
router.get('/', async (req, res, next) => {
  try {
    const summary = await walletService.getWalletSummary(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Ringkasan dompet berhasil diambil.',
      data: summary,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/wallet/ledger
 * Returns cursor-paginated ledger entries for the user.
 */
router.get('/ledger', async (req, res, next) => {
  try {
    const { cursor, limit } = req.query;
    const history = await walletService.getLedgerHistory(req.user.id, { cursor, limit });
    res.status(200).json({
      success: true,
      message: 'Riwayat mutasi buku besar berhasil diambil.',
      data: history,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/wallet/withdrawals
 * Request balance withdrawal to saved bank account
 */
router.post('/withdrawals', createWithdrawalRules, validate, withdrawalController.createWithdrawal);

/**
 * GET /api/wallet/withdrawals
 * List paginated withdrawal history for user
 */
router.get('/withdrawals', withdrawalController.getUserWithdrawals);

/**
 * POST /api/wallet/withdrawals/:id/cancel
 * Cancel a pending withdrawal and release reserved balance
 */
router.post(
  '/withdrawals/:id/cancel',
  withdrawalIdRules,
  validate,
  withdrawalController.cancelWithdrawal
);

/**
 * POST /api/wallet/topup (Legacy Endpoint)
 * Deprecated: returns 410 Gone.
 */
router.post('/topup', (req, res) => {
  return res.status(410).json({
    success: false,
    message: 'Gunakan fitur top-up/penarikan baru.',
    code: 'GONE',
  });
});

/**
 * POST /api/wallet/withdraw (Legacy Endpoint)
 * Deprecated: returns 410 Gone.
 */
router.post('/withdraw', (req, res) => {
  return res.status(410).json({
    success: false,
    message: 'Gunakan fitur top-up/penarikan baru.',
    code: 'GONE',
  });
});

module.exports = router;
