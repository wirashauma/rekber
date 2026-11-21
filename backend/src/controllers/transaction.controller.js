// =============================================================================
// Transaction (Escrow) Controller
// =============================================================================
// Handles HTTP request/response for escrow transaction endpoints.
// Delegates business and state machine logic to escrow.service.js.

const escrowService = require('../services/escrow.service');

/**
 * POST /api/transactions
 *
 * Create a new escrow transaction.
 * Body: { sellerId, buyerId, amount, itemDescription, feePayer }
 */
const createTransaction = async (req, res, next) => {
  try {
    const { sellerId, buyerId, amount, itemDescription, feePayer } = req.body;

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

    const transaction = await escrowService.createTransaction({
      buyerId: resolvedBuyerId,
      sellerId: resolvedSellerId,
      amount,
      itemDescription,
      feePayer,
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

    const transaction = await escrowService.getTransactionById(id, userId, userRole);

    res.status(200).json({
      success: true,
      message: 'Detail transaksi berhasil diambil.',
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/transactions/code/:code
 *
 * Get details of a transaction by 8-character unique code.
 * Accessible only by participants (buyer, seller) or admin.
 * Returns 404 for non-participants to prevent code probing.
 */
const getTransactionByCode = async (req, res, next) => {
  try {
    const { code } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const transaction = await escrowService.getTransactionByCode(code, userId, userRole);

    res.status(200).json({
      success: true,
      message: 'Detail transaksi berhasil diambil.',
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
 * Enforces compare-and-swap, escrow state machine and role-based authority.
 * Body: { status, reason }
 */
const updateTransactionStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, reason } = req.body;

    if (status === 'SHIPPED') {
      return res.status(400).json({
        success: false,
        message:
          'Perubahan status ke SHIPPED harus melalui endpoint pengiriman (POST /transactions/:id/shipment).',
        code: 'USE_SHIPMENT_ENDPOINT',
      });
    }

    const transaction = await escrowService.executeTransition(id, status, req.user, reason);

    res.status(200).json({
      success: true,
      message: `Status transaksi berhasil diperbarui menjadi ${status}.`,
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/transactions/:id/shipment
 * Submits shipment proof and transitions status from PAID to SHIPPED.
 */
const submitShipmentProof = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { courier, trackingNumber, note, fileIds } = req.body;

    const transaction = await escrowService.submitShipmentProof(id, req.user.id, {
      courier,
      trackingNumber,
      note,
      fileIds,
    });

    res.status(200).json({
      success: true,
      message: 'Bukti pengiriman berhasil dikirimkan dan status transaksi menjadi SHIPPED.',
      data: transaction,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/transactions
 *
 * Get list of all transactions for the authenticated user.
 */
const getTransactions = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const transactions = await escrowService.getTransactions(userId);
    res.status(200).json({
      success: true,
      message: 'Daftar transaksi berhasil diambil.',
      data: transactions,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createTransaction,
  getTransactionById,
  getTransactionByCode,
  updateTransactionStatus,
  submitShipmentProof,
  getTransactions,
};
