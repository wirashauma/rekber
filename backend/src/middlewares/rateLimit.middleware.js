// =============================================================================
// Rate Limiting Middlewares (express-rate-limit)
// =============================================================================
// Enforces request rate limits to protect endpoints against brute force and abuse.
// Configurable via environment variables with Indonesian 429 responses.

const rateLimit = require('express-rate-limit');
const config = require('../config');

const createLimiter = ({ windowMs, max, message, keyGenerator }) => {
  return rateLimit({
    windowMs,
    // In test environment, keep limits high unless TEST_RATE_LIMIT is enabled
    max: config.isTest && !process.env.TEST_RATE_LIMIT ? 100000 : max,
    standardHeaders: true,
    legacyHeaders: false,
    validate: { keyGeneratorIpFallback: false },
    keyGenerator: keyGenerator || undefined,
    handler: (_req, res) => {
      res.status(429).json({
        success: false,
        message: message || 'Terlalu banyak permintaan. Silakan coba lagi nanti.',
        code: 'TOO_MANY_REQUESTS',
      });
    },
  });
};

// Global API limiter: 300 req / 15 minutes / IP
const globalLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_GLOBAL_WINDOW_MS, 10) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_GLOBAL_MAX, 10) || 300,
  message: 'Terlalu banyak permintaan ke server. Silakan coba lagi nanti.',
});

// Login limiter: 10 attempts / 15 minutes per IP + email
const loginLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_LOGIN_WINDOW_MS, 10) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_LOGIN_MAX, 10) || 10,
  keyGenerator: (req) => {
    const email = (req.body?.email || '').trim().toLowerCase();
    return `${req.ip}_${email}`;
  },
  message: 'Terlalu banyak percobaan login yang gagal. Silakan coba lagi dalam 15 menit.',
});

// Register limiter: 5 attempts / hour / IP
const registerLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_REGISTER_WINDOW_MS, 10) || 60 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_REGISTER_MAX, 10) || 5,
  message: 'Batas pendaftaran akun terlampaui. Silakan coba lagi dalam 1 jam.',
});

// Forgot Password limiter: 5 attempts / hour / IP
const forgotPasswordLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_FORGOT_PASSWORD_WINDOW_MS, 10) || 60 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_FORGOT_PASSWORD_MAX, 10) || 5,
  message: 'Terlalu banyak permintaan reset password. Silakan coba lagi dalam 1 jam.',
});

// Refresh Token limiter: 60 attempts / 15 minutes / IP
const refreshLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_REFRESH_WINDOW_MS, 10) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_REFRESH_MAX, 10) || 60,
  message: 'Terlalu banyak permintaan pembaruan token. Silakan coba lagi nanti.',
});

// Top-up creation limiter: 30 attempts / 15 minutes / user or IP
const topUpLimiter = createLimiter({
  windowMs: parseInt(process.env.RATE_LIMIT_TOPUP_WINDOW_MS, 10) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_TOPUP_MAX, 10) || 30,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: 'Terlalu banyak permintaan pembuatan top-up. Silakan coba lagi nanti.',
});

module.exports = {
  createLimiter,
  globalLimiter,
  loginLimiter,
  registerLimiter,
  forgotPasswordLimiter,
  refreshLimiter,
  topUpLimiter,
};
