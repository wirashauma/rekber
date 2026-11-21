// =============================================================================
// Top-Up Validation Rules
// =============================================================================

const { body, param } = require('express-validator');

/**
 * Validation rules for POST /api/wallet/topups
 * Minimum: Rp 10.000, Maximum: Rp 20.000.000
 */
const createTopUpRules = [
  body('amount')
    .notEmpty()
    .withMessage('Nominal top-up wajib diisi.')
    .custom((val) => {
      const num = Number(val);
      if (!Number.isInteger(num)) {
        throw new Error('Nominal top-up harus berupa bilangan bulat (rupiah bulat tanpa desimal).');
      }
      if (num < 10000) {
        throw new Error('Nominal top-up minimal Rp 10.000.');
      }
      if (num > 20000000) {
        throw new Error('Nominal top-up maksimal Rp 20.000.000.');
      }
      return true;
    }),

  body('method')
    .trim()
    .notEmpty()
    .withMessage('Metode pembayaran wajib dipilih.')
    .toUpperCase()
    .isIn(['QRIS', 'VIRTUAL_ACCOUNT'])
    .withMessage('Metode pembayaran tidak valid. Pilihan yang didukung: QRIS, VIRTUAL_ACCOUNT.'),

  body('bankCode')
    .optional({ checkFalsy: true })
    .trim()
    .toUpperCase()
    .isIn(['BCA', 'BNI', 'BRI', 'MANDIRI', 'PERMATA', 'CIMB'])
    .withMessage('Kode bank tidak didukung. Pilihan: BCA, BNI, BRI, MANDIRI, PERMATA, CIMB.'),
];

/**
 * Validation rules for GET /api/wallet/topups/:id
 */
const getTopUpRules = [param('id').isUUID().withMessage('ID top-up harus berupa UUID yang valid.')];

module.exports = {
  createTopUpRules,
  getTopUpRules,
};
