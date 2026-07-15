// =============================================================================
// Auth Validation Rules
// =============================================================================
// Defines express-validator chains for auth endpoints.
// These are used as middleware arrays before the controller in routes.

const { body } = require('express-validator');

/**
 * Validation rules for POST /api/auth/register
 */
const registerRules = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama wajib diisi.') // Name is required.
    .isLength({ min: 2, max: 100 })
    .withMessage('Nama harus antara 2-100 karakter.'), // Name must be 2-100 chars.

  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email wajib diisi.') // Email is required.
    .isEmail()
    .withMessage('Format email tidak valid.') // Invalid email format.
    .normalizeEmail(),

  body('password')
    .notEmpty()
    .withMessage('Password wajib diisi.') // Password is required.
    .isLength({ min: 8 })
    .withMessage('Password minimal 8 karakter.') // Password min 8 chars.
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password harus mengandung huruf besar, huruf kecil, dan angka.'),
    // Password must contain uppercase, lowercase, and number.
];

/**
 * Validation rules for POST /api/auth/login
 */
const loginRules = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email wajib diisi.') // Email is required.
    .isEmail()
    .withMessage('Format email tidak valid.'), // Invalid email format.

  body('password')
    .notEmpty()
    .withMessage('Password wajib diisi.'), // Password is required.
];

/**
 * Validation rules for POST /api/auth/forgot-email
 */
const forgotEmailRules = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama lengkap wajib diisi.'),

  body('password')
    .notEmpty()
    .withMessage('Password wajib diisi.'),
];

module.exports = { registerRules, loginRules, forgotEmailRules };
