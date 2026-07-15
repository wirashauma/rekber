// =============================================================================
// Transaction (Escrow) Routes
// =============================================================================
// Defines routes for escrow transactions.
// ALL routes here are PROTECTED — JWT authentication required.

const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transaction.controller');
const { authenticate } = require('../middlewares/auth.middleware');
const {
  createTransactionRules,
  updateStatusRules,
  getTransactionRules,
} = require('../validators/transaction.validator');
const { validate } = require('../middlewares/validate.middleware');

// All transaction routes require authentication
router.use(authenticate);

// POST /api/transactions
// Create a new escrow transaction (authenticated user = buyer)
router.post('/', createTransactionRules, validate, transactionController.createTransaction);

// GET /api/transactions
// Get list of all transactions for the authenticated user
router.get('/', transactionController.getTransactions);

// GET /api/transactions/:id
// Get details of a specific transaction
router.get('/:id', getTransactionRules, validate, transactionController.getTransactionById);

// PUT /api/transactions/:id/status
// Update the status of an escrow transaction (state machine)
router.put('/:id/status', updateStatusRules, validate, transactionController.updateTransactionStatus);

module.exports = router;
