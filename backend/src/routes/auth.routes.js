// =============================================================================
// Auth Routes
// =============================================================================
// Defines routes for authentication (register, login).
// These routes are PUBLIC — no JWT required.

const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { registerRules, loginRules, forgotEmailRules } = require('../validators/auth.validator');
const { validate } = require('../middlewares/validate.middleware');

const { authenticate } = require('../middlewares/auth.middleware');

// POST /api/auth/register
// Register a new user account
router.post('/register', registerRules, validate, authController.register);

// POST /api/auth/login
// Authenticate and receive a JWT token
router.post('/login', loginRules, validate, authController.login);

// POST /api/auth/forgot-email
// Retrieve email using name and password
router.post('/forgot-email', forgotEmailRules, validate, authController.forgotEmail);

// GET /api/auth/me
// Get current user profile and balance details
router.get('/me', authenticate, authController.me);

// PUT /api/auth/profile
// Update user profile details
router.put('/profile', authenticate, authController.updateProfile);

// GET /api/auth/search-opponent
// Search other users for transaction counterparty
router.get('/search-opponent', authenticate, authController.searchOpponent);

// POST /api/auth/update-fcm
// Update FCM token for notifications
router.post('/update-fcm', authenticate, authController.updateFcm);

module.exports = router;
