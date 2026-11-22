// =============================================================================
// Chat Validators - Request Validation Rules
// =============================================================================

const { param, query, body } = require('express-validator');

const getMessagesRules = [
  param('id').isUUID(4).withMessage('ID transaksi harus berupa UUID v4 yang valid.'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit harus berupa integer antara 1 dan 100.'),
  query('cursor').optional().isUUID(4).withMessage('Cursor harus berupa UUID v4 yang valid.'),
];

const sendMessageRules = [
  param('id').isUUID(4).withMessage('ID transaksi harus berupa UUID v4 yang valid.'),
  body('type')
    .optional()
    .isIn(['TEXT', 'IMAGE', 'SYSTEM'])
    .withMessage('Tipe pesan harus bernilai TEXT, IMAGE, atau SYSTEM.'),
  body('body')
    .optional()
    .isString()
    .withMessage('Isi pesan harus berupa teks string.')
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Isi pesan maksimal 2000 karakter.'),
  body('fileId').optional().isUUID(4).withMessage('fileId harus berupa UUID v4 yang valid.'),
];

const markReadRules = [
  param('id').isUUID(4).withMessage('ID transaksi harus berupa UUID v4 yang valid.'),
];

module.exports = {
  getMessagesRules,
  sendMessageRules,
  markReadRules,
};
