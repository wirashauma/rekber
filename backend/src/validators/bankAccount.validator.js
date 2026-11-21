// =============================================================================
// Bank Account Validation Rules
// =============================================================================

const { body, param } = require('express-validator');
const { BANK_CODES } = require('../constants/banks');

const createBankAccountRules = [
  body('bankCode')
    .trim()
    .notEmpty()
    .withMessage('Kode bank wajib diisi.')
    .toUpperCase()
    .isIn(BANK_CODES)
    .withMessage(`Kode bank tidak didukung. Pilihan: ${BANK_CODES.join(', ')}.`),

  body('accountNumber')
    .trim()
    .notEmpty()
    .withMessage('Nomor rekening wajib diisi.')
    .matches(/^\d{8,18}$/)
    .withMessage('Nomor rekening harus terdiri dari 8 hingga 18 digit angka numerik.'),

  body('accountName')
    .trim()
    .notEmpty()
    .withMessage('Nama pemilik rekening wajib diisi.')
    .isLength({ min: 2, max: 100 })
    .withMessage('Nama pemilik rekening harus antara 2 hingga 100 karakter.'),

  body('isDefault')
    .optional()
    .isBoolean()
    .withMessage('isDefault harus berupa boolean (true/false).'),
];

const bankAccountIdRules = [
  param('id').isUUID().withMessage('ID rekening bank harus berupa UUID yang valid.'),
];

module.exports = {
  createBankAccountRules,
  bankAccountIdRules,
};
