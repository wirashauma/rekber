// =============================================================================
// Auth Routes
// =============================================================================
// Defines routes for authentication, session lifecycle, and profile management.

const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const {
  registerRules,
  loginRules,
  refreshRules,
  updatePasswordRules,
  forgotPasswordRules,
  resetPasswordRules,
  updateProfileRules,
  updateFcmRules,
  searchOpponentRules,
} = require('../validators/auth.validator');
const { validate } = require('../middlewares/validate.middleware');
const { authenticate } = require('../middlewares/auth.middleware');
const {
  registerLimiter,
  loginLimiter,
  refreshLimiter,
  forgotPasswordLimiter,
} = require('../middlewares/rateLimit.middleware');

// POST /api/auth/register
// Register a new user account with accessToken + refreshToken
router.post('/register', registerLimiter, registerRules, validate, authController.register);

// POST /api/auth/login
// Authenticate and receive accessToken + refreshToken
router.post('/login', loginLimiter, loginRules, validate, authController.login);

// POST /api/auth/refresh
// Rotate refresh token and issue new accessToken
router.post('/refresh', refreshLimiter, refreshRules, validate, authController.refresh);

// POST /api/auth/logout
// Revoke current refresh token
router.post('/logout', authController.logout);

// POST /api/auth/logout-all
// Revoke all refresh tokens for the authenticated user
router.post('/logout-all', authenticate, authController.logoutAll);

// PUT /api/auth/password
// Change password (revokes all other refresh tokens)
router.put('/password', authenticate, updatePasswordRules, validate, authController.changePassword);

// POST /api/auth/forgot-password
// Request password reset email (always returns generic 200 response)
router.post(
  '/forgot-password',
  forgotPasswordLimiter,
  forgotPasswordRules,
  validate,
  authController.forgotPassword
);

// POST /api/auth/reset-password
// Reset password using single-use 32-byte reset token
router.post('/reset-password', resetPasswordRules, validate, authController.resetPassword);

// POST /api/auth/forgot-email
// Deprecated endpoint: returns 410 Gone
router.post('/forgot-email', authController.forgotEmail);

// GET /api/auth/me
// Get current user profile and balance details
router.get('/me', authenticate, authController.me);

// PUT /api/auth/profile
// Update user profile details (validated 2-100 characters)
router.put('/profile', authenticate, updateProfileRules, validate, authController.updateProfile);

// POST /api/auth/update-fcm
// Update FCM token for notifications
router.post('/update-fcm', authenticate, updateFcmRules, validate, authController.updateFcm);

// GET /api/auth/search-opponent
// Search other users for transaction counterparty (validated 2-100 characters)
router.get(
  '/search-opponent',
  authenticate,
  searchOpponentRules,
  validate,
  authController.searchOpponent
);

module.exports = router;
