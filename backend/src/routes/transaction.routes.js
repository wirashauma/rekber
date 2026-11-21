// =============================================================================
// Transaction (Escrow) Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transaction.controller');
const disputeController = require('../controllers/dispute.controller');
const { authenticate } = require('../middlewares/auth.middleware');
const {
  createTransactionRules,
  updateStatusRules,
  getTransactionRules,
} = require('../validators/transaction.validator');
const { submitShipmentRules } = require('../validators/shipment.validator');
const { openDisputeRules, getTransactionDisputeRules } = require('../validators/dispute.validator');
const { validate } = require('../middlewares/validate.middleware');

// All transaction routes require authentication
router.use(authenticate);

// POST /api/transactions
// Create a new escrow transaction
router.post('/', createTransactionRules, validate, transactionController.createTransaction);

// GET /api/transactions
// Get list of all transactions for the authenticated user
router.get('/', transactionController.getTransactions);

// GET /api/transactions/code/:code
// Get transaction by 8-character unique code (participants/admin only)
router.get('/code/:code', transactionController.getTransactionByCode);

// GET /api/transactions/:id
// Get details of a specific transaction
router.get('/:id', getTransactionRules, validate, transactionController.getTransactionById);

// POST /api/transactions/:id/shipment
// Submit shipment proof and move status from PAID to SHIPPED (seller only)
router.post(
  '/:id/shipment',
  submitShipmentRules,
  validate,
  transactionController.submitShipmentProof
);

// POST /api/transactions/:id/dispute
// Open a dispute for a transaction (buyer only, status PAID or SHIPPED)
router.post('/:id/dispute', openDisputeRules, validate, disputeController.openDispute);

// GET /api/transactions/:id/dispute
// Get dispute details for a specific transaction (participants/admin only)
router.get(
  '/:id/dispute',
  getTransactionDisputeRules,
  validate,
  disputeController.getDisputeByTransactionId
);

// PUT /api/transactions/:id/status
// Update the status of an escrow transaction (state machine)
router.put(
  '/:id/status',
  updateStatusRules,
  validate,
  transactionController.updateTransactionStatus
);

module.exports = router;
