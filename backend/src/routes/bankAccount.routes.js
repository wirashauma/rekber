// =============================================================================
// Bank Account Routes
// =============================================================================

const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const {
  createBankAccountRules,
  bankAccountIdRules,
} = require('../validators/bankAccount.validator');
const bankAccountController = require('../controllers/bankAccount.controller');

// All bank account routes require authentication
router.use(authenticate);

/**
 * GET /bank-accounts
 * List all active bank accounts for the authenticated user
 */
router.get('/', bankAccountController.getBankAccounts);

/**
 * POST /bank-accounts
 * Register a new bank account
 */
router.post('/', createBankAccountRules, validate, bankAccountController.createBankAccount);

/**
 * DELETE /bank-accounts/:id
 * Soft delete an active bank account
 */
router.delete('/:id', bankAccountIdRules, validate, bankAccountController.deleteBankAccount);

module.exports = router;
