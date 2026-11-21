// =============================================================================
// Dispute Validators - Request Validation Rules
// =============================================================================

const { body, param, query } = require('express-validator');
const { DISPUTE_REASON, DISPUTE_STATUS, DISPUTE_DECISION } = require('../constants/dispute');

const openDisputeRules = [
  param('id').isUUID().withMessage('ID transaksi harus berformat UUID.'),

  body('reason')
    .notEmpty()
    .withMessage('Alasan sengketa wajib diisi.')
    .isIn(Object.values(DISPUTE_REASON))
    .withMessage(
      `Alasan sengketa tidak valid. Pilihan: ${Object.values(DISPUTE_REASON).join(', ')}.`
    ),

  body('description')
    .notEmpty()
    .withMessage('Deskripsi sengketa wajib diisi.')
    .isString()
    .withMessage('Deskripsi sengketa harus berupa string.')
    .trim()
    .isLength({ min: 20, max: 2000 })
    .withMessage('Deskripsi sengketa harus antara 20 hingga 2000 karakter.'),

  body('fileIds').optional().isArray().withMessage('fileIds harus berupa array string.'),

  body('fileIds.*').optional().isUUID().withMessage('Setiap fileId harus berformat UUID.'),
];

const submitEvidenceRules = [
  param('id').isUUID().withMessage('ID sengketa harus berformat UUID.'),

  body('note')
    .optional()
    .isString()
    .withMessage('Catatan bukti harus berupa string.')
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Catatan bukti maksimal 1000 karakter.'),

  body('fileIds').optional().isArray().withMessage('fileIds harus berupa array string.'),

  body('fileIds.*').optional().isUUID().withMessage('Setiap fileId harus berformat UUID.'),

  body().custom((value, { req }) => {
    const hasNote = typeof req.body.note === 'string' && req.body.note.trim().length > 0;
    const hasFiles = Array.isArray(req.body.fileIds) && req.body.fileIds.length > 0;
    if (!hasNote && !hasFiles) {
      throw new Error('Wajib menyertakan catatan bukti (note) atau berkas bukti (fileIds).');
    }
    return true;
  }),
];

const getDisputeRules = [param('id').isUUID().withMessage('ID sengketa harus berformat UUID.')];

const getTransactionDisputeRules = [
  param('id').isUUID().withMessage('ID transaksi harus berformat UUID.'),
];

const adminListDisputesRules = [
  query('status')
    .optional()
    .isIn(Object.values(DISPUTE_STATUS))
    .withMessage(
      `Status filter tidak valid. Pilihan: ${Object.values(DISPUTE_STATUS).join(', ')}.`
    ),

  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Halaman (page) harus bilangan bulat minimal 1.'),

  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Batas per halaman (limit) antara 1 hingga 100.'),
];

const resolveDisputeRules = [
  param('id').isUUID().withMessage('ID sengketa harus berformat UUID.'),

  body('decision')
    .notEmpty()
    .withMessage('Keputusan sengketa wajib dipilih.')
    .isIn(Object.values(DISPUTE_DECISION))
    .withMessage(
      `Keputusan sengketa harus ${DISPUTE_DECISION.RELEASE_TO_SELLER} atau ${DISPUTE_DECISION.REFUND_TO_BUYER}.`
    ),

  body('note')
    .notEmpty()
    .withMessage('Catatan resolusi wajib diisi.')
    .isString()
    .withMessage('Catatan resolusi harus berupa string.')
    .trim()
    .isLength({ min: 10, max: 2000 })
    .withMessage('Catatan resolusi sengketa minimal 10 karakter.'),
];

module.exports = {
  openDisputeRules,
  submitEvidenceRules,
  getDisputeRules,
  getTransactionDisputeRules,
  adminListDisputesRules,
  resolveDisputeRules,
};
