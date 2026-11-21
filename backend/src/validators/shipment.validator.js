// =============================================================================
// Shipment Proof Validation Rules
// =============================================================================

const { body, param } = require('express-validator');

const submitShipmentRules = [
  param('id').isUUID().withMessage('ID transaksi harus berupa UUID yang valid.'),
  body('courier')
    .optional({ values: 'null' })
    .isString()
    .trim()
    .isLength({ max: 50 })
    .withMessage('Nama kurir maksimal 50 karakter.'),
  body('trackingNumber')
    .optional({ values: 'null' })
    .isString()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Nomor resi maksimal 100 karakter.'),
  body('note')
    .optional({ values: 'null' })
    .isString()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Catatan pengiriman maksimal 1000 karakter.'),
  body('fileIds').optional().isArray().withMessage('fileIds harus berupa array string UUID.'),
  body('fileIds.*').optional().isUUID().withMessage('Setiap fileId harus berupa UUID yang valid.'),
];

module.exports = {
  submitShipmentRules,
};
