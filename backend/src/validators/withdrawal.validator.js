// =============================================================================
// Withdrawal Validation Rules
// =============================================================================

const { body, param, header } = require('express-validator');

const createWithdrawalRules = [
  header('idempotency-key')
    .notEmpty()
    .withMessage('Header Idempotency-Key wajib disertakan.')
    .bail()
    .trim()
    .isLength({ min: 8, max: 128 })
    .withMessage('Header Idempotency-Key harus antara 8 dan 128 karakter.'),

  body('bankAccountId')
    .notEmpty()
    .withMessage('ID rekening bank tujuan wajib diisi.')
    .isUUID()
    .withMessage('ID rekening bank harus berupa UUID yang valid.'),

  body('amount')
    .notEmpty()
    .withMessage('Nominal penarikan wajib diisi.')
    .custom((val) => {
      const num = Number(val);
      if (!Number.isInteger(num)) {
        throw new Error('Nominal penarikan harus berupa bilangan bulat (rupiah bulat).');
      }
      if (num < 1000) {
        throw new Error('Nominal penarikan tidak valid.');
      }
      return true;
    }),
];

const withdrawalIdRules = [
  param('id').isUUID().withMessage('ID penarikan harus berupa UUID yang valid.'),
];

const rejectWithdrawalRules = [
  param('id').isUUID().withMessage('ID penarikan harus berupa UUID yang valid.'),
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 255 })
    .withMessage('Alasan penolakan maksimal 255 karakter.'),
];

module.exports = {
  createWithdrawalRules,
  withdrawalIdRules,
  rejectWithdrawalRules,
};
