// =============================================================================
// REKBER Backend - Express Application Setup
// =============================================================================
// This is the main Express application configuration file.
// It sets up all middleware, routes, and error handlers.
// The server is started in src/server.js (separation of concerns).

require('./utils/money');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlewares/error.middleware');
const { httpLogger } = require('./config/logger');
const { globalLimiter } = require('./middlewares/rateLimit.middleware');
const config = require('./config');

const createApp = () => {
  const app = express();

  // 1. Helmet: Sets various HTTP headers for security
  app.use(helmet());

  // 2. Trust Proxy: Configure if TRUST_PROXY is set via env
  if (process.env.TRUST_PROXY) {
    const tp = process.env.TRUST_PROXY.trim().toLowerCase();
    if (tp === 'true') {
      app.set('trust proxy', true);
    } else if (tp === 'false') {
      app.set('trust proxy', false);
    } else if (!isNaN(Number(tp))) {
      app.set('trust proxy', Number(tp));
    } else {
      app.set('trust proxy', process.env.TRUST_PROXY);
    }
  }

  // 3. CORS: Enable Cross-Origin Resource Sharing
  // In production, strictly restrict to comma-separated CORS_ORIGIN list
  const allowedOrigins = (process.env.CORS_ORIGIN || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  app.use(
    cors({
      origin: config.isProd
        ? (origin, callback) => {
            // Allow requests with no origin (e.g. mobile apps, curl, server-to-server)
            if (!origin || allowedOrigins.includes(origin)) {
              callback(null, true);
            } else {
              callback(new Error('Origin tidak diizinkan oleh kebijakan CORS.'));
            }
          }
        : '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // 4. Pino HTTP structured logger (replaces morgan; redacts sensitive fields)
  app.use(httpLogger);

  // 5. Global Rate Limiter: 300 requests per 15 minutes per IP
  app.use(globalLimiter);

  // 6. Payment Webhook Routes: Mounted BEFORE express.json with express.raw
  const webhookRoutes = require('./routes/webhook.routes');
  app.use(
    ['/webhooks/payment', '/api/webhooks/payment'],
    express.raw({ type: '*/*', limit: '2mb' }),
    webhookRoutes
  );

  // 7. Body Parsers: Parse JSON and URL-encoded request bodies with 100kb limit
  app.use(express.json({ limit: '100kb' }));
  app.use(express.urlencoded({ extended: true, limit: '100kb' }));

  // =============================================================================
  // HEALTH CHECK ENDPOINT
  // =============================================================================

  app.get('/api/health', (req, res) => {
    res.status(200).json({
      success: true,
      message: 'Rekber API is running! 🚀',
      environment: config.nodeEnv,
      timestamp: new Date().toISOString(),
    });
  });

  // =============================================================================
  // API ROUTES
  // =============================================================================

  // Mount all routes under /api prefix and root for compatibility
  app.use(['/api', '/'], routes);

  // =============================================================================
  // ERROR HANDLING (must be AFTER routes)
  // =============================================================================

  // Handle 404 - Route not found
  app.use(notFoundHandler);

  // Global error handler - catches all errors passed via next(error)
  app.use(errorHandler);

  return app;
};

const app = createApp();

module.exports = app;
module.exports.createApp = createApp;
