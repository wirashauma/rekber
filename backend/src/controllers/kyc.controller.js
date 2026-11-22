// =============================================================================
// KYC Controller - User Verification Endpoints
// =============================================================================

const kycService = require('../services/kyc.service');

const submitKyc = async (req, res, next) => {
  try {
    const { fullName, nik, idFileId, selfieFileId } = req.body;
    const result = await kycService.submitKyc(req.user.id, {
      fullName,
      nik,
      idFileId,
      selfieFileId,
    });

    res.status(201).json({
      success: true,
      message: 'Pengajuan verifikasi identitas (KYC) berhasil dikirim.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

const getMyKyc = async (req, res, next) => {
  try {
    const result = await kycService.getMyKyc(req.user);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  submitKyc,
  getMyKyc,
};
