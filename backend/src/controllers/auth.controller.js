// =============================================================================
// Auth Controller
// =============================================================================
// Handles HTTP request/response for authentication endpoints.
// Delegates business logic to auth.service.js.
// Controllers should be thin — only parsing input and formatting output.

const authService = require('../services/auth.service');

/**
 * POST /api/auth/register
 *
 * Register a new user account.
 * Body: { name, email, password }
 */
const register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;

    const user = await authService.register({ name, email, password });

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil! Silakan login.', // Registration successful!
      data: user,
    });
  } catch (error) {
    next(error); // Pass to global error handler
  }
};

/**
 * POST /api/auth/login
 *
 * Authenticate a user and return a JWT token.
 * Body: { email, password }
 */
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const result = await authService.login({ email, password });

    res.status(200).json({
      success: true,
      message: 'Login berhasil!', // Login successful!
      data: result,
    });
  } catch (error) {
    next(error); // Pass to global error handler
  }
};

module.exports = { register, login };
