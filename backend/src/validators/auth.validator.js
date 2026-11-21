// =============================================================================
// Auth Validation Rules
// =============================================================================
// Defines express-validator chains for all authentication endpoints.

const { body, query } = require('express-validator');

/**
 * Validation rules for POST /api/auth/register
 */
const registerRules = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama wajib diisi.')
    .isLength({ min: 2, max: 100 })
    .withMessage('Nama harus antara 2-100 karakter.'),

  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email wajib diisi.')
    .isEmail()
    .withMessage('Format email tidak valid.')
    .normalizeEmail(),

  body('password')
    .notEmpty()
    .withMessage('Password wajib diisi.')
    .isLength({ min: 8 })
    .withMessage('Password minimal 8 karakter.')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password harus mengandung huruf besar, huruf kecil, dan angka.'),
];

/**
 * Validation rules for POST /api/auth/login
 */
const loginRules = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email wajib diisi.')
    .isEmail()
    .withMessage('Format email tidak valid.')
    .normalizeEmail(),

  body('password').notEmpty().withMessage('Password wajib diisi.'),
];

/**
 * Validation rules for POST /api/auth/refresh
 */
const refreshRules = [
  body('refreshToken').trim().notEmpty().withMessage('Refresh token wajib disertakan.'),
];

/**
 * Validation rules for PUT /api/auth/password
 */
const updatePasswordRules = [
  body('oldPassword').notEmpty().withMessage('Password lama wajib diisi.'),

  body('newPassword')
    .notEmpty()
    .withMessage('Password baru wajib diisi.')
    .isLength({ min: 8 })
    .withMessage('Password baru minimal 8 karakter.')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password baru harus mengandung huruf besar, huruf kecil, dan angka.'),
];

/**
 * Validation rules for POST /api/auth/forgot-password
 */
const forgotPasswordRules = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email wajib diisi.')
    .isEmail()
    .withMessage('Format email tidak valid.')
    .normalizeEmail(),
];

/**
 * Validation rules for POST /api/auth/reset-password
 */
const resetPasswordRules = [
  body('token').trim().notEmpty().withMessage('Token reset password wajib diisi.'),

  body('newPassword')
    .notEmpty()
    .withMessage('Password baru wajib diisi.')
    .isLength({ min: 8 })
    .withMessage('Password baru minimal 8 karakter.')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password baru harus mengandung huruf besar, huruf kecil, dan angka.'),
];

/**
 * Validation rules for PUT /api/auth/profile
 */
const updateProfileRules = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama wajib diisi.')
    .isLength({ min: 2, max: 100 })
    .withMessage('Nama harus antara 2-100 karakter.'),
];

/**
 * Validation rules for POST /api/auth/update-fcm
 */
const updateFcmRules = [body('fcmToken').trim().notEmpty().withMessage('FCM token wajib diisi.')];

/**
 * Validation rules for GET /api/auth/search-opponent
 */
const searchOpponentRules = [
  query('query')
    .trim()
    .notEmpty()
    .withMessage('Query pencarian tidak boleh kosong.')
    .isLength({ min: 2, max: 100 })
    .withMessage('Query pencarian harus antara 2-100 karakter.'),
];

module.exports = {
  registerRules,
  loginRules,
  refreshRules,
  updatePasswordRules,
  forgotPasswordRules,
  resetPasswordRules,
  updateProfileRules,
  updateFcmRules,
  searchOpponentRules,
};
