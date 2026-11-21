// =============================================================================
// Admin Withdrawal Controller
// =============================================================================

const withdrawalService = require('../services/withdrawal.service');

/**
 * GET /api/admin/withdrawals
 * Retrieves withdrawals for admin review with nameMatch score and status filter.
 */
const getAdminWithdrawals = async (req, res, next) => {
  try {
    const { status, cursor, limit } = req.query;
    const result = await withdrawalService.getAdminWithdrawals({
      status,
      cursor,
      limit,
    });

    res.status(200).json({
      success: true,
      message: 'Daftar penarikan admin berhasil diambil.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/admin/withdrawals/:id/approve
 * Approves a withdrawal and dispatches payout to payment provider.
 */
const approveWithdrawal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await withdrawalService.approveWithdrawal(id, req.user.id);

    res.status(200).json({
      success: true,
      message: 'Permintaan penarikan berhasil disetujui dan sedang diproses.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /api/admin/withdrawals/:id/reject
 * Rejects a withdrawal and releases reserved funds back to the user.
 */
const rejectWithdrawal = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const result = await withdrawalService.rejectWithdrawal(id, req.user.id, reason);

    res.status(200).json({
      success: true,
      message: 'Permintaan penarikan berhasil ditolak.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAdminWithdrawals,
  approveWithdrawal,
  rejectWithdrawal,
};
