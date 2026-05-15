// =============================================================================
// JWT Authentication Middleware
// =============================================================================
// Protects routes by verifying the JWT token from the Authorization header.
// Attaches the decoded user payload (id, email, role) to `req.user`.
//
// Usage: Add `authenticate` to any route that requires a logged-in user.
//   router.get('/protected', authenticate, controller.method);

const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Middleware: Verify JWT token and attach user to request.
 *
 * Expected header format:  Authorization: Bearer <token>
 *
 * On success: sets req.user = { id, email, role }
 * On failure: returns 401 Unauthorized
 */
const authenticate = (req, res, next) => {
  try {
    // 1. Extract the Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Akses ditolak. Token tidak ditemukan.', // Access denied. No token provided.
      });
    }

    // 2. Extract the token (remove "Bearer " prefix)
    const token = authHeader.split(' ')[1];

    // 3. Verify the token
    const decoded = jwt.verify(token, config.jwt.secret);

    // 4. Attach the decoded payload to the request object
    req.user = decoded;

    // 5. Proceed to the next middleware/controller
    next();
  } catch (error) {
    // Handle specific JWT errors with descriptive messages
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Token sudah kedaluwarsa. Silakan login kembali.', // Token expired.
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        message: 'Token tidak valid.', // Invalid token.
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada autentikasi.', // Authentication error.
    });
  }
};

/**
 * Middleware Factory: Restrict access to specific roles.
 *
 * Usage:
 *   router.get('/admin-only', authenticate, authorize('ADMIN'), controller.method);
 *
 * @param  {...string} roles - Allowed roles (e.g., 'ADMIN', 'USER')
 * @returns {Function} Express middleware
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Akses ditolak. Autentikasi diperlukan.', // Authentication required.
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Akses ditolak. Anda tidak memiliki izin untuk aksi ini.', // Forbidden.
      });
    }

    next();
  };
};

module.exports = { authenticate, authorize };
