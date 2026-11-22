// =============================================================================
// Maintenance Mode Middleware (Prompt 20)
// =============================================================================
// Intercepts requests when platformSetting 'maintenance_mode' is enabled (true).
// Exempts health checks (/api/health, /health) and payment webhooks.
// Returns HTTP 503 Service Unavailable with a localized message.

const settingsService = require('../services/settings.service');

const EXEMPT_PREFIXES = [
  '/api/health',
  '/health',
  '/api/metrics',
  '/metrics',
  '/webhooks',
  '/api/webhooks',
];

const maintenanceMiddleware = async (req, res, next) => {
  const path = req.path || req.originalUrl || '';
  const isExempt = EXEMPT_PREFIXES.some(
    (prefix) => path === prefix || path.startsWith(`${prefix}/`)
  );

  if (isExempt) {
    return next();
  }

  try {
    const isMaintenance = await settingsService.getBoolean('maintenance_mode');
    if (isMaintenance) {
      return res.status(503).json({
        success: false,
        code: 'MAINTENANCE_MODE',
        message: 'Layanan sedang dalam pemeliharaan berkala. Silakan coba beberapa saat lagi.',
      });
    }
  } catch {
    // If settings check fails, proceed without blocking
  }

  return next();
};

module.exports = {
  maintenanceMiddleware,
  EXEMPT_PREFIXES,
};
