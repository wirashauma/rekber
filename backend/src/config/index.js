// =============================================================================
// Application Configuration
// =============================================================================
// Centralizes all configuration values using validated environment variables from env.js.
// This ensures a single source of truth for configuration values across the app.

const env = require('./env');

const config = {
  // Server
  port: env.PORT,
  nodeEnv: env.NODE_ENV,
  isDev: env.isDev,
  isProd: env.isProd,
  isTest: env.isTest,
  corsOrigin: env.CORS_ORIGIN,

  // Database
  databaseUrl: env.DATABASE_URL,

  // JWT
  jwt: {
    secret: env.JWT_SECRET,
    expiresIn: env.JWT_EXPIRES_IN,
  },

  // Bcrypt
  bcrypt: {
    saltRounds: env.BCRYPT_SALT_ROUNDS,
  },

  // Encryption
  encryption: {
    key: env.DATA_ENCRYPTION_KEY,
  },

  // Payment Gateway
  payment: {
    provider: env.PAYMENT_PROVIDER,
    xenditSecretKey: env.XENDIT_SECRET_KEY,
    webhookToken: env.XENDIT_WEBHOOK_VERIFICATION_TOKEN,
  },

  // Storage
  storage: {
    provider: env.STORAGE_PROVIDER,
    localDir: env.STORAGE_LOCAL_DIR,
    localSecret: env.STORAGE_LOCAL_SECRET,
    s3: {
      bucket: env.S3_BUCKET,
      region: env.S3_REGION,
      endpoint: env.S3_ENDPOINT,
      accessKeyId: env.S3_ACCESS_KEY_ID,
      secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      forcePathStyle: env.S3_FORCE_PATH_STYLE,
    },
  },
};

module.exports = config;
