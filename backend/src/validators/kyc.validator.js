// =============================================================================
// KYC Validators - Request Validation Rules
// =============================================================================

const { body, param, query } = require('express-validator');

const submitKycRules = [
  body('fullName')
    .isString()
    .trim()
    .isLength({ min: 3, max: 100 })
    .withMessage('Nama lengkap wajib diisi minimal 3 dan maksimal 100 karakter.'),
  body('nik')
    .isString()
    .trim()
    .matches(/^\d{16}$/)
    .withMessage('NIK harus terdiri dari tepat 16 digit angka.'),
  body('idFileId').isUUID(4).withMessage('idFileId harus berupa UUID v4 yang valid.'),
  body('selfieFileId').isUUID(4).withMessage('selfieFileId harus berupa UUID v4 yang valid.'),
];

const rejectKycRules = [
  param('id').isUUID(4).withMessage('ID pengajuan KYC harus berupa UUID v4 yang valid.'),
  body('reason')
    .isString()
    .trim()
    .isLength({ min: 5, max: 1000 })
    .withMessage('Alasan penolakan (reason) wajib diisi minimal 5 karakter.'),
];

const getKycRules = [
  param('id').isUUID(4).withMessage('ID pengajuan KYC harus berupa UUID v4 yang valid.'),
];

const listKycRules = [
  query('status')
    .optional()
    .isIn(['PENDING', 'APPROVED', 'REJECTED'])
    .withMessage('Status filter harus bernilai PENDING, APPROVED, atau REJECTED.'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit harus berupa integer antara 1 dan 100.'),
  query('cursor').optional().isUUID(4).withMessage('Cursor harus berupa UUID v4 yang valid.'),
];

module.exports = {
  submitKycRules,
  rejectKycRules,
  getKycRules,
  listKycRules,
};
