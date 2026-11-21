// =============================================================================
// Bank Constants - Supported Indonesian Banks
// =============================================================================

const SUPPORTED_BANKS = {
  BCA: { code: 'BCA', name: 'Bank Central Asia' },
  BNI: { code: 'BNI', name: 'Bank Negara Indonesia' },
  BRI: { code: 'BRI', name: 'Bank Rakyat Indonesia' },
  MANDIRI: { code: 'MANDIRI', name: 'Bank Mandiri' },
  PERMATA: { code: 'PERMATA', name: 'Bank Permata' },
  CIMB: { code: 'CIMB', name: 'Bank CIMB Niaga' },
  BSI: { code: 'BSI', name: 'Bank Syariah Indonesia' },
  DANAMON: { code: 'DANAMON', name: 'Bank Danamon' },
  BTPN: { code: 'BTPN', name: 'Bank BTPN / Jenius' },
};

const BANK_CODES = Object.keys(SUPPORTED_BANKS);

/**
 * Validates whether a bank code is supported.
 *
 * @param {string} code
 * @returns {boolean}
 */
const isValidBankCode = (code) => {
  if (!code || typeof code !== 'string') return false;
  return BANK_CODES.includes(code.toUpperCase());
};

module.exports = {
  SUPPORTED_BANKS,
  BANK_CODES,
  isValidBankCode,
};
