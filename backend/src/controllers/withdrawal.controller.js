// =============================================================================
// Withdrawal Controller - User Endpoints
// =============================================================================

const withdrawalService = require('../services/withdrawal.service');

/**
 * POST /api/wallet/withdrawals
 * Requests a new balance withdrawal to a saved bank account.
 * Mandates Idempotency-Key header.
 */
const createWithdrawal = async (req, res, next) => {
  try {
    const idempotencyKey = req.headers['idempotency-key'];
    const { bankAccountId, amount } = req.body;

    const result = await withdrawalService.createWithdrawal(req.user.id, {
      bankAccountId,
      amount,
      idempotencyKey,
    });

    res.status(201).json({
      success: true,
      message: 'Permintaan penarikan berhasil dibuat.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/wallet/withdrawals
 * Retrieves cursor-paginated list of user withdrawals.
 */
const getUserWithdrawals = async (req, res, next) => {
  try {
    const { cursor, limit } = req.query;
    const result = await withdrawalService.getUserWithdrawals(req.user.id, {
      cursor,
      limit,
    });

    res.status(200).json({
      success: true,
      message: 'Daftar penarikan berhasil diambil.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/wallet/withdrawals/:id/cancel
 * Cancels a pending withdrawal and releases reserved balance back to wallet.
 */
const cancelWithdrawal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await withdrawalService.cancelWithdrawal(id, req.user.id);

    res.status(200).json({
      success: true,
      message: 'Permintaan penarikan berhasil dibatalkan.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createWithdrawal,
  getUserWithdrawals,
  cancelWithdrawal,
};
