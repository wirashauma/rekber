// =============================================================================
// Global Error Handling Middleware
// =============================================================================
// Catches all errors that are passed via `next(error)` or thrown in async
// handlers. Provides consistent, secure JSON error responses without stack traces.

/**
 * Custom error class for API errors with an HTTP status code, error code, and field errors.
 */
class ApiError extends Error {
  constructor(statusCode, message, errors = [], code = null) {
    super(message);
    this.statusCode = statusCode;
    this.errors = errors;
    this.code =
      code ||
      (statusCode === 400
        ? 'BAD_REQUEST'
        : statusCode === 401
          ? 'UNAUTHORIZED'
          : statusCode === 403
            ? 'FORBIDDEN'
            : statusCode === 404
              ? 'NOT_FOUND'
              : statusCode === 409
                ? 'CONFLICT'
                : statusCode === 410
                  ? 'GONE'
                  : statusCode === 422
                    ? 'VALIDATION_ERROR'
                    : statusCode === 429
                      ? 'TOO_MANY_REQUESTS'
                      : 'INTERNAL_SERVER_ERROR');
    this.name = 'ApiError';
  }
}

/**
 * Express error-handling middleware (4 arguments: err, req, res, next).
 * Formats errors into a uniform JSON response without exposing stack traces.
 */
const errorHandler = (err, req, res, _next) => {
  // Determine the status code
  let statusCode = err.statusCode || (err.status ? err.status : 500);

  // Handle Prisma-specific errors with user-friendly messages and appropriate codes
  let message = err.message || 'Terjadi kesalahan internal server.';
  let code = err.code;

  if (err.code === 'P2002') {
    statusCode = 409;
    message = 'Data sudah ada. Duplikat tidak diperbolehkan.';
    code = 'DUPLICATE_ENTRY';
  } else if (err.code === 'P2025') {
    statusCode = 404;
    message = 'Data tidak ditemukan.';
    code = 'NOT_FOUND';
  }

  if (!code) {
    code =
      statusCode === 400
        ? 'BAD_REQUEST'
        : statusCode === 401
          ? 'UNAUTHORIZED'
          : statusCode === 403
            ? 'FORBIDDEN'
            : statusCode === 404
              ? 'NOT_FOUND'
              : statusCode === 409
                ? 'CONFLICT'
                : statusCode === 410
                  ? 'GONE'
                  : statusCode === 422
                    ? 'VALIDATION_ERROR'
                    : statusCode === 429
                      ? 'TOO_MANY_REQUESTS'
                      : 'INTERNAL_SERVER_ERROR';
  }

  // Report unhandled 5xx server errors to Sentry
  if (statusCode >= 500) {
    const { captureException } = require('../config/sentry');
    captureException(err);
  }

  // Uniform error response (NEVER includes stack trace)
  const response = {
    success: false,
    message,
    code,
  };

  if (err.errors && Array.isArray(err.errors) && err.errors.length > 0) {
    response.errors = err.errors;
  }

  res.status(statusCode).json(response);
};

/**
 * Middleware for handling 404 (route not found).
 */
const notFoundHandler = (req, res, _next) => {
  res.status(404).json({
    success: false,
    message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan.`,
    code: 'NOT_FOUND',
  });
};

module.exports = { ApiError, errorHandler, notFoundHandler };
