// =============================================================================
// Request Validation Middleware
// =============================================================================
// Centralizes express-validator result checking into a reusable middleware.
// Automatically returns 422 with a structured error response on validation failures.

const { validationResult } = require('express-validator');

/**
 * Middleware: Check express-validator results.
 * If validation fails, returns 422 with an array of error messages.
 * If validation passes, calls next().
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    const extractedErrors = errors.array().map((err) => ({
      field: err.path,
      message: err.msg,
    }));

    return res.status(422).json({
      success: false,
      message: 'Validasi gagal. Periksa kembali input Anda.',
      code: 'VALIDATION_ERROR',
      errors: extractedErrors,
    });
  }

  next();
};

module.exports = { validate };
