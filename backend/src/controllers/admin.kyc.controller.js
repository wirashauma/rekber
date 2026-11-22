// =============================================================================
// Admin KYC Controller
// =============================================================================

const kycService = require('../services/kyc.service');

const getAdminKycSubmissions = async (req, res, next) => {
  try {
    const { status, cursor, limit } = req.query;
    const result = await kycService.getAdminKycSubmissions({ status, cursor, limit });

    res.status(200).json({
      success: true,
      data: result.submissions,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
    });
  } catch (err) {
    next(err);
  }
};

const getAdminKycById = async (req, res, next) => {
  try {
    const result = await kycService.getAdminKycById(req.params.id, req.user);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

const approveKyc = async (req, res, next) => {
  try {
    const result = await kycService.approveKyc(req.params.id, req.user, req.ip);

    res.status(200).json({
      success: true,
      message: 'Pengajuan KYC berhasil disetujui.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

const rejectKyc = async (req, res, next) => {
  try {
    const { reason } = req.body;
    const result = await kycService.rejectKyc(req.params.id, req.user, reason, req.ip);

    res.status(200).json({
      success: true,
      message: 'Pengajuan KYC berhasil ditolak.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getAdminKycSubmissions,
  getAdminKycById,
  approveKyc,
  rejectKyc,
};
