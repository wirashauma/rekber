// =============================================================================
// Global Error Handling Middleware
// =============================================================================
// Catches all errors that are passed via `next(error)` or thrown in async
// handlers. Provides consistent JSON error responses.
//
// This MUST be the LAST middleware registered in app.js (after all routes).

const config = require('../config');

/**
 * Custom error class for API errors with an HTTP status code.
 * Throw this in services/controllers for clean error handling.
 *
 * Usage:
 *   throw new ApiError(404, 'Transaksi tidak ditemukan');
 */
class ApiError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
    this.name = 'ApiError';
  }
}

/**
 * Express error-handling middleware (4 arguments: err, req, res, next).
 * Formats errors into a consistent JSON response.
 */
const errorHandler = (err, req, res, next) => {
  // Log the full error in development for debugging
  if (config.isDev) {
    console.error('❌ [Error Handler]:', err);
  }

  // Determine the status code
  const statusCode = err.statusCode || 500;

  // Build the response object
  const response = {
    success: false,
    message: err.message || 'Terjadi kesalahan internal server.', // Internal server error.
  };

  // In development, include the stack trace for debugging
  if (config.isDev) {
    response.stack = err.stack;
  }

  // Handle Prisma-specific errors with user-friendly messages
  if (err.code === 'P2002') {
    // Unique constraint violation
    response.message = 'Data sudah ada. Duplikat tidak diperbolehkan.'; // Duplicate entry.
    return res.status(409).json(response);
  }

  if (err.code === 'P2025') {
    // Record not found
    response.message = 'Data tidak ditemukan.'; // Record not found.
    return res.status(404).json(response);
  }

  res.status(statusCode).json(response);
};

/**
 * Middleware for handling 404 (route not found).
 * Place this AFTER all route definitions but BEFORE the error handler.
 */
const notFoundHandler = (req, res, next) => {
  res.status(404).json({
    success: false,
    message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan.`, // Route not found.
  });
};

module.exports = { ApiError, errorHandler, notFoundHandler };
