// =============================================================================
// Data Encryption & Masking Utility (AES-256-GCM)
// =============================================================================
// Secures sensitive banking data (account numbers) at rest using AES-256-GCM.
// Encrypted format: `${ivHex}:${authTagHex}:${encryptedHex}`.

const crypto = require('crypto');
const { Buffer } = require('buffer');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // 96 bits for GCM

/**
 * Derives a 32-byte key from DATA_ENCRYPTION_KEY environment variable.
 */
const getEncryptionKey = () => {
  const secret =
    process.env.DATA_ENCRYPTION_KEY || 'rekber_secret_data_encryption_key_32_bytes_long_dev';
  return crypto.createHash('sha256').update(secret).digest();
};

/**
 * Encrypts a string using AES-256-GCM.
 *
 * @param {string} text - Plaintext to encrypt
 * @returns {string} `${ivHex}:${authTagHex}:${encryptedHex}`
 */
const encrypt = (text) => {
  if (!text || typeof text !== 'string') {
    throw new Error('Teks yang akan dienkripsi harus berupa string non-kosong.');
  }

  const key = getEncryptionKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  const authTag = cipher.getAuthTag();

  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
};

/**
 * Decrypts an AES-256-GCM encrypted string.
 *
 * @param {string} ciphertext - Formatted as `${ivHex}:${authTagHex}:${encryptedHex}`
 * @returns {string} Original plaintext
 */
const decrypt = (ciphertext) => {
  if (!ciphertext || typeof ciphertext !== 'string') {
    throw new Error('Ciphertext yang akan didekripsi harus berupa string non-kosong.');
  }

  const parts = ciphertext.split(':');
  if (parts.length !== 3) {
    throw new Error('Format ciphertext AES-256-GCM tidak valid.');
  }

  const [ivHex, authTagHex, encryptedHex] = parts;
  const key = getEncryptionKey();
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
};

/**
 * Masks an account number, showing only the last 4 digits.
 *
 * @param {string} accountNumber - e.g. "1234567890"
 * @returns {string} e.g. "•••• •••• ••90"
 */
const maskAccountNumber = (accountNumber) => {
  if (!accountNumber || typeof accountNumber !== 'string') return '••••';
  const clean = accountNumber.replace(/\s+/g, '');
  const len = clean.length;
  if (len <= 4) return clean;

  const last4 = clean.slice(-4);
  const maskedPrefix = '•'.repeat(Math.max(len - 4, 4));
  return `${maskedPrefix}${last4}`;
};

/**
 * Masks a 16-digit NIK, displaying first 4 and last 4 digits: e.g. "3171********0001".
 *
 * @param {string} nik - 16-digit NIK string
 * @returns {string}
 */
const maskNik = (nik) => {
  if (!nik || typeof nik !== 'string') return '••••••••••••••••';
  const clean = nik.replace(/\s+/g, '');
  if (clean.length < 8) return '•'.repeat(clean.length);
  return `${clean.slice(0, 4)}********${clean.slice(-4)}`;
};

module.exports = {
  encrypt,
  decrypt,
  maskAccountNumber,
  maskNik,
};
