// =============================================================================
// Logger Configuration (Pino & Pino-HTTP)
// =============================================================================
// Replaces morgan with structured logging via pino.
// Automatically redacts sensitive fields (Authorization, passwords, tokens)
// and tags each request with a unique request ID.

const pino = require('pino');
const pinoHttp = require('pino-http');
const crypto = require('crypto');
const config = require('./index');

const redactPaths = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.body.password',
  'req.body.oldPassword',
  'req.body.newPassword',
  'req.body.token',
  'req.body.refreshToken',
];

const logger = pino({
  level: config.isTest ? 'silent' : process.env.LOG_LEVEL || (config.isDev ? 'debug' : 'info'),
  redact: {
    paths: redactPaths,
    censor: '[REDACTED]',
  },
});

const httpLogger = pinoHttp({
  logger,
  genReqId: (req) => req.headers['x-request-id'] || crypto.randomUUID(),
  redact: {
    paths: redactPaths,
    censor: '[REDACTED]',
  },
  autoLogging: !config.isTest,
});

module.exports = { logger, httpLogger };
