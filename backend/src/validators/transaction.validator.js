// =============================================================================
// Transaction Validation Rules
// =============================================================================
// Defines express-validator chains for transaction endpoints.

const { body, param } = require('express-validator');

/**
 * Validation rules for POST /api/transactions
 */
const createTransactionRules = [
  body('amount')
    .notEmpty()
    .withMessage('Jumlah transaksi wajib diisi.') // Amount is required.
    .isFloat({ min: 1000 })
    .withMessage('Jumlah transaksi minimal Rp 1.000.'), // Minimum amount Rp 1,000.

  body('itemDescription')
    .trim()
    .notEmpty()
    .withMessage('Deskripsi barang wajib diisi.') // Item description is required.
    .isLength({ min: 5, max: 500 })
    .withMessage('Deskripsi barang harus antara 5-500 karakter.'), // 5-500 chars.
];

/**
 * Validation rules for PUT /api/transactions/:id/status
 */
const updateStatusRules = [
  param('id')
    .isUUID()
    .withMessage('ID transaksi harus berupa UUID yang valid.'), // Transaction ID must be valid UUID.

  body('status')
    .trim()
    .notEmpty()
    .withMessage('Status baru wajib diisi.') // New status is required.
    .isIn(['PENDING', 'PAID', 'SHIPPED', 'COMPLETED', 'CANCELLED', 'DISPUTED'])
    .withMessage(
      'Status tidak valid. Pilihan: PENDING, PAID, SHIPPED, COMPLETED, CANCELLED, DISPUTED.'
    ), // Invalid status.
];

/**
 * Validation rules for GET /api/transactions/:id
 */
const getTransactionRules = [
  param('id')
    .isUUID()
    .withMessage('ID transaksi harus berupa UUID yang valid.'), // Transaction ID must be valid UUID.
];

module.exports = { createTransactionRules, updateStatusRules, getTransactionRules };
