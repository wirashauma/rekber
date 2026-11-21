// =============================================================================
// Transaction Code Generator
// =============================================================================
// Generates unique 8-character codes using uppercase letters and digits,
// excluding visually ambiguous characters: 0, O, 1, I.

const crypto = require('crypto');

// 32-character alphabet without ambiguous 0, O, 1, I
const CHARSET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

/**
 * Generates an 8-character random transaction code.
 *
 * @param {number} length - default 8
 * @returns {string}
 */
const generateTransactionCode = (length = 8) => {
  const bytes = crypto.randomBytes(length);
  let result = '';
  for (let i = 0; i < length; i++) {
    result += CHARSET[bytes[i] % CHARSET.length];
  }
  return result;
};

module.exports = {
  generateTransactionCode,
  CHARSET,
};
