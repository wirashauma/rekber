// =============================================================================
// Transaction (Escrow) Controller
// =============================================================================
// Handles HTTP request/response for escrow transaction endpoints.
// Delegates all business logic to transaction.service.js.

const transactionService = require('../services/transaction.service');

/**
 * POST /api/transactions
 *
 * Create a new escrow transaction.
 * Body: { sellerId, buyerId, amount, itemDescription }
 */
const createTransaction = async (req, res, next) => {
  try {
    const { sellerId, buyerId, amount, itemDescription } = req.body;
    
    let resolvedBuyerId = buyerId;
    let resolvedSellerId = sellerId;

    if (!resolvedBuyerId && !resolvedSellerId) {
      return res.status(400).json({
        success: false,
        message: 'Lawan transaksi (buyerId atau sellerId) harus ditentukan.',
      });
    }

    if (resolvedSellerId && !resolvedBuyerId) {
      resolvedBuyerId = req.user.id; // Initiator is buyer
    } else if (resolvedBuyerId && !resolvedSellerId) {
      resolvedSellerId = req.user.id; // Initiator is seller
    }

    const transaction = await transactionService.createTransaction({
      buyerId: resolvedBuyerId,
      sellerId: resolvedSellerId,
      amount,
      itemDescription,
    });

    res.status(201).json({
      success: true,
      message: 'Transaksi escrow berhasil dibuat.',
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/transactions/:id
 *
 * Get details of a specific escrow transaction.
 * Only accessible by the buyer, seller, or admin.
 */
const getTransactionById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const transaction = await transactionService.getTransactionById(id, userId, userRole);

    res.status(200).json({
      success: true,
      message: 'Detail transaksi berhasil diambil.', // Transaction details retrieved.
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /api/transactions/:id/status
 *
 * Update the status of an escrow transaction.
 * Enforces the escrow state machine and role-based authorization.
 * Body: { status }
 *
 * Example valid transitions:
 *   - Buyer sends  { status: "PAID" }       when status is PENDING
 *   - Seller sends { status: "SHIPPED" }    when status is PAID
 *   - Buyer sends  { status: "COMPLETED" }  when status is SHIPPED
 */
const updateTransactionStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const userId = req.user.id;
    const userRole = req.user.role;

    const transaction = await transactionService.updateTransactionStatus(
      id,
      status,
      userId,
      userRole,
    );

    res.status(200).json({
      success: true,
      message: `Status transaksi berhasil diperbarui menjadi ${status}.`, // Status updated.
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

const getTransactions = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const transactions = await transactionService.getTransactions(userId);
    res.status(200).json({
      success: true,
      message: 'Daftar transaksi berhasil diambil.',
      data: transactions,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { createTransaction, getTransactionById, updateTransactionStatus, getTransactions };
