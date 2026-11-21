// =============================================================================
// JWT Authentication & Authorization Middleware
// =============================================================================
// Verifies JWT token from Authorization header and loads the latest user state
// (including role and isActive) from PostgreSQL database. Rejects inactive users.

const jwt = require('jsonwebtoken');
const config = require('../config');
const prisma = require('../config/prisma');

/**
 * Middleware: Verify JWT token and attach fresh user from database to request.
 * Expected header format: Authorization: Bearer <token>
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Akses ditolak. Token tidak ditemukan.',
        code: 'UNAUTHORIZED',
      });
    }

    const token = authHeader.split(' ')[1];
    let decoded;

    try {
      decoded = jwt.verify(token, config.jwt.secret);
    } catch (jwtErr) {
      if (jwtErr.name === 'TokenExpiredError') {
        return res.status(401).json({
          success: false,
          message: 'Token sudah kedaluwarsa. Silakan login kembali.',
          code: 'TOKEN_EXPIRED',
        });
      }
      return res.status(401).json({
        success: false,
        message: 'Token tidak valid.',
        code: 'INVALID_TOKEN',
      });
    }

    // Load fresh user data directly from database
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isActive: true,
        balance: true,
      },
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User tidak ditemukan atau sesi tidak valid.',
        code: 'UNAUTHORIZED',
      });
    }

    // Enforce active account policy
    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Akun Anda telah dinonaktifkan. Hubungi admin.',
        code: 'ACCOUNT_INACTIVE',
      });
    }

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Middleware Factory: Restrict access to specific roles.
 *
 * @param  {...string} roles - Allowed roles (e.g., 'ADMIN', 'USER')
 * @returns {Function} Express middleware
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Akses ditolak. Autentikasi diperlukan.',
        code: 'UNAUTHORIZED',
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Akses ditolak. Anda tidak memiliki izin untuk aksi ini.',
        code: 'FORBIDDEN',
      });
    }

    next();
  };
};

module.exports = { authenticate, authorize };
