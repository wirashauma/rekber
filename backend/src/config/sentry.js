// =============================================================================
// Sentry Observability Configuration & Sensitive Data Scrubber (Prompt 20)
// =============================================================================
// Initializes @sentry/node when SENTRY_DSN is configured.
// Redacts sensitive data (Authorization, passwords, tokens, NIK, account numbers)
// before any exception is transmitted to Sentry.

const Sentry = require('@sentry/node');
const config = require('./index');

let isInitialized = false;

const SENSITIVE_KEYWORDS = [
  'password',
  'oldpassword',
  'newpassword',
  'token',
  'refreshtoken',
  'nik',
  'nikenc',
  'accountnumber',
  'accountno',
  'secret',
  'authorization',
  'cookie',
  'creditcard',
  'cvv',
];

/**
 * Deeply scrubs sensitive keys from objects or arrays.
 *
 * @param {any} obj
 * @returns {any}
 */
const scrubObject = (obj) => {
  if (!obj || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(scrubObject);

  const clean = {};
  for (const [k, v] of Object.entries(obj)) {
    const lowerKey = k.toLowerCase().replace(/[^a-z0-9]/g, '');
    const isSensitive = SENSITIVE_KEYWORDS.some((kw) => lowerKey.includes(kw));

    if (isSensitive) {
      clean[k] = '[REDACTED]';
    } else if (typeof v === 'object' && v !== null) {
      clean[k] = scrubObject(v);
    } else {
      clean[k] = v;
    }
  }
  return clean;
};

/**
 * Initialize Sentry on application boot.
 */
const initSentry = () => {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn || isInitialized) return;

  Sentry.init({
    dsn,
    environment: config.nodeEnv,
    beforeSend(event) {
      if (event.request) {
        if (event.request.headers) {
          delete event.request.headers.authorization;
          delete event.request.headers.cookie;
          delete event.request.headers['x-metrics-token'];
        }
        if (event.request.data) {
          event.request.data = scrubObject(event.request.data);
        }
      }
      return event;
    },
  });

  isInitialized = true;
};

/**
 * Safely capture an exception to Sentry if configured.
 *
 * @param {Error} err
 */
const captureException = (err) => {
  if (process.env.SENTRY_DSN) {
    try {
      Sentry.captureException(err);
    } catch {
      // ignore
    }
  }
};

module.exports = {
  initSentry,
  scrubObject,
  captureException,
};
