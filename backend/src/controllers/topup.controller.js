// =============================================================================
// Top-Up & Payment Webhook Controller
// =============================================================================

const topupService = require('../services/topup.service');

/**
 * POST /api/wallet/topups
 * Creates a new top-up intent with the payment provider.
 */
const createTopUp = async (req, res, next) => {
  try {
    const { amount, method, bankCode } = req.body;
    const intent = await topupService.createTopUpIntent({
      userId: req.user.id,
      amount,
      method,
      bankCode,
    });

    res.status(201).json({
      success: true,
      message: 'Permintaan top-up berhasil dibuat.',
      data: intent,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/wallet/topups/:id
 * Fetches single top-up intent details (owner only).
 */
const getTopUpById = async (req, res, next) => {
  try {
    const intent = await topupService.getTopUpById(req.params.id, req.user.id);
    res.status(200).json({
      success: true,
      message: 'Detail top-up berhasil diambil.',
      data: intent,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/wallet/topups
 * Fetches cursor-paginated list of top-ups for the authenticated user.
 */
const getTopUps = async (req, res, next) => {
  try {
    const { cursor, limit } = req.query;
    const result = await topupService.getTopUps(req.user.id, { cursor, limit });
    res.status(200).json({
      success: true,
      message: 'Daftar riwayat top-up berhasil diambil.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /webhooks/payment/:provider
 * Handles asynchronous payment gateway notifications (raw body).
 */
const handleWebhook = async (req, res, next) => {
  try {
    const providerName = req.params.provider;
    const result = await topupService.processWebhook({
      providerName,
      headers: req.headers,
      rawBody: req.body,
    });

    res.status(200).json({
      success: true,
      message: result.message || 'Webhook berhasil diproses.',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createTopUp,
  getTopUpById,
  getTopUps,
  handleWebhook,
};
