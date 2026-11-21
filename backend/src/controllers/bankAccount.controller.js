// =============================================================================
// Bank Account Controller
// =============================================================================

const bankAccountService = require('../services/bankAccount.service');

/**
 * POST /bank-accounts
 * Adds a new bank account.
 */
const createBankAccount = async (req, res, next) => {
  try {
    const { bankCode, accountNumber, accountName, isDefault } = req.body;
    const account = await bankAccountService.createBankAccount(req.user.id, {
      bankCode,
      accountNumber,
      accountName,
      isDefault,
    });

    res.status(201).json({
      success: true,
      message: 'Rekening bank berhasil ditambahkan.',
      data: account,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /bank-accounts
 * Lists all active bank accounts for the authenticated user.
 */
const getBankAccounts = async (req, res, next) => {
  try {
    const accounts = await bankAccountService.getBankAccounts(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Daftar rekening bank berhasil diambil.',
      data: accounts,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /bank-accounts/:id
 * Soft deletes a bank account.
 */
const deleteBankAccount = async (req, res, next) => {
  try {
    const result = await bankAccountService.deleteBankAccount(req.params.id, req.user.id);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createBankAccount,
  getBankAccounts,
  deleteBankAccount,
};
