// =============================================================================
// Chat Rate Limiter Middleware
// =============================================================================
// Enforces 20 messages per minute per user limit for chat communication.

const { rateLimit } = require('express-rate-limit');

const messageHistoryMap = new Map(); // userId -> number[] timestamps
const WINDOW_MS = 60 * 1000;
const MAX_MESSAGES_PER_MINUTE = 20;

/**
 * Express middleware for REST POST /transactions/:id/messages
 */
const chatMessageLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: MAX_MESSAGES_PER_MINUTE,
  keyGenerator: (req) => req.user?.id || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  validate: { keyGeneratorIpFallback: false },
  message: {
    success: false,
    message:
      'Batas pengiriman pesan tercapai (maksimal 20 pesan per menit). Silakan tunggu sejenak.',
  },
});

/**
 * In-memory sliding window check for both REST and Socket message sending.
 *
 * @param {string} userId
 * @returns {boolean} true if permitted, false if rate limited
 */
const checkMessageRateLimit = (userId) => {
  if (!userId) return true;

  const now = Date.now();
  const timestamps = (messageHistoryMap.get(userId) || []).filter((t) => now - t < WINDOW_MS);

  if (timestamps.length >= MAX_MESSAGES_PER_MINUTE) {
    messageHistoryMap.set(userId, timestamps);
    return false;
  }

  timestamps.push(now);
  messageHistoryMap.set(userId, timestamps);
  return true;
};

/**
 * Reset rate limit tracker for tests.
 *
 * @param {string} [userId]
 */
const resetMessageRateLimit = (userId) => {
  if (userId) {
    messageHistoryMap.delete(userId);
  } else {
    messageHistoryMap.clear();
  }
};

module.exports = {
  chatMessageLimiter,
  checkMessageRateLimit,
  resetMessageRateLimit,
};
