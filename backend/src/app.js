// =============================================================================
// REKBER Backend - Express Application Setup
// =============================================================================
// This is the main Express application configuration file.
// It sets up all middleware, routes, and error handlers.
// The server is started in src/server.js (separation of concerns).

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlewares/error.middleware');
const config = require('./config');

// Initialize Express app
const app = express();

// =============================================================================
// GLOBAL MIDDLEWARE (order matters!)
// =============================================================================

// 1. Helmet: Sets various HTTP headers for security
//    (XSS protection, content-type sniffing prevention, etc.)
app.use(helmet());

// 2. CORS: Enable Cross-Origin Resource Sharing
//    Configure this to only allow your Flutter app's origin in production
app.use(cors({
  origin: config.isDev ? '*' : process.env.CORS_ORIGIN,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// 3. Morgan: HTTP request logger
//    'dev' format for development, 'combined' for production
app.use(morgan(config.isDev ? 'dev' : 'combined'));

// 4. Body Parsers: Parse JSON and URL-encoded request bodies
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

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

// Mount all routes under /api prefix
app.use('/api', routes);

// =============================================================================
// ERROR HANDLING (must be AFTER routes)
// =============================================================================

// Handle 404 - Route not found
app.use(notFoundHandler);

// Global error handler - catches all errors passed via next(error)
app.use(errorHandler);

module.exports = app;
