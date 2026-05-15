// =============================================================================
// Request Validation Middleware
// =============================================================================
// Centralizes express-validator result checking into a reusable middleware.
// Use this after your validation chains to automatically return 422 on errors.
//
// Usage:
//   router.post('/register',
//     [...validationRules],
//     validate,
//     controller.register
//   );

const { validationResult } = require('express-validator');

/**
 * Middleware: Check express-validator results.
 * If validation fails, returns 422 with an array of error messages.
 * If validation passes, calls next().
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    // Extract the first error message for each field for a clean response
    const extractedErrors = errors.array().map((err) => ({
      field: err.path,
      message: err.msg,
    }));

    return res.status(422).json({
      success: false,
      message: 'Validasi gagal. Periksa kembali input Anda.', // Validation failed.
      errors: extractedErrors,
    });
  }

  next();
};

module.exports = { validate };
