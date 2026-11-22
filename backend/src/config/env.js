// =============================================================================
// REKBER Backend - Environment Validation
// =============================================================================
// Validates all critical environment variables on startup (fail-fast principle).
// If any required variable is missing or invalid, logs a descriptive error
// mentioning the variable name (never its value) and terminates the process.

require('dotenv').config();

/**
 * Validates environment variables according to environment requirements.
 * Returns an array of error messages.
 *
 * @param {Record<string, string | undefined>} envVars
 * @returns {string[]}
 */
const validateEnv = (envVars = process.env) => {
  const errors = [];

  // 1. DATABASE_URL (Required)
  const databaseUrl = envVars.DATABASE_URL;
  if (!databaseUrl || databaseUrl.trim() === '') {
    errors.push('DATABASE_URL wajib diisi.');
  }

  // 2. JWT_SECRET (Required, min 32 characters)
  const jwtSecret = envVars.JWT_SECRET;
  if (!jwtSecret || jwtSecret.trim() === '') {
    errors.push('JWT_SECRET wajib diisi.');
  } else if (jwtSecret.length < 32) {
    errors.push('JWT_SECRET harus memiliki panjang minimal 32 karakter demi keamanan token.');
  }

  // 3. NODE_ENV (Defaults to 'development')
  const nodeEnv = envVars.NODE_ENV || 'development';
  const validEnvironments = ['development', 'production', 'test', 'staging'];
  if (!validEnvironments.includes(nodeEnv)) {
    errors.push(`NODE_ENV tidak valid. Pilihan yang diizinkan: ${validEnvironments.join(', ')}.`);
  }

  // 4. PORT (Optional, defaults to 5000, 1-65535)
  if (envVars.PORT) {
    const parsedPort = parseInt(envVars.PORT, 10);
    if (isNaN(parsedPort) || parsedPort <= 0 || parsedPort > 65535) {
      errors.push('PORT harus berupa angka antara 1 dan 65535.');
    }
  }

  // 5. CORS_ORIGIN (Required when NODE_ENV=production)
  const corsOrigin = envVars.CORS_ORIGIN;
  if (nodeEnv === 'production' && (!corsOrigin || corsOrigin.trim() === '')) {
    errors.push('CORS_ORIGIN wajib diisi saat NODE_ENV bernilai "production".');
  }

  // 6. Production Hardening Requirements
  if (nodeEnv === 'production') {
    const paymentProvider = (envVars.PAYMENT_PROVIDER || '').toLowerCase();
    if (paymentProvider === 'fake') {
      errors.push('PAYMENT_PROVIDER tidak boleh bernilai "fake" pada lingkungan production.');
    } else if (paymentProvider === 'xendit' && (!envVars.XENDIT_SECRET_KEY || envVars.XENDIT_SECRET_KEY.trim() === '')) {
      errors.push('XENDIT_SECRET_KEY wajib diisi saat PAYMENT_PROVIDER="xendit" pada production.');
    }

    const storageProvider = (envVars.STORAGE_PROVIDER || '').toLowerCase();
    if (storageProvider === 'local') {
      errors.push('STORAGE_PROVIDER tidak boleh bernilai "local" pada lingkungan production.');
    } else if (storageProvider === 's3') {
      if (!envVars.S3_BUCKET || envVars.S3_BUCKET.trim() === '') {
        errors.push('S3_BUCKET wajib diisi saat STORAGE_PROVIDER="s3" pada production.');
      }
      if (!envVars.S3_ACCESS_KEY_ID || envVars.S3_ACCESS_KEY_ID.trim() === '') {
        errors.push('S3_ACCESS_KEY_ID wajib diisi saat STORAGE_PROVIDER="s3" pada production.');
      }
      if (!envVars.S3_SECRET_ACCESS_KEY || envVars.S3_SECRET_ACCESS_KEY.trim() === '') {
        errors.push('S3_SECRET_ACCESS_KEY wajib diisi saat STORAGE_PROVIDER="s3" pada production.');
      }
    }

    const dataEncryptionKey = envVars.DATA_ENCRYPTION_KEY;
    if (!dataEncryptionKey || dataEncryptionKey.trim() === '') {
      errors.push('DATA_ENCRYPTION_KEY wajib diisi pada lingkungan production.');
    } else if (dataEncryptionKey === 'rekber_secret_data_encryption_key_32_bytes_long_dev') {
      errors.push('DATA_ENCRYPTION_KEY tidak boleh menggunakan nilai default pengujian pada production.');
    } else if (dataEncryptionKey.length < 32) {
      errors.push('DATA_ENCRYPTION_KEY harus memiliki panjang minimal 32 karakter pada production.');
    }
  }

  return errors;
};

// Execute validation on load
const errors = validateEnv(process.env);

// Fail-fast if any validation errors occurred (bypassed in test environment)
if (errors.length > 0 && process.env.NODE_ENV !== 'test') {
  console.error('\n❌ Kesalahan Konfigurasi Environment:');
  errors.forEach((err, idx) => {
    console.error(`   ${idx + 1}. ${err}`);
  });
  console.error('\nSilakan periksa file konfigurasi environment (.env) Anda.\n');
  process.exit(1);
}

const nodeEnv = process.env.NODE_ENV || 'development';
const port = parseInt(process.env.PORT, 10) || 5000;

const env = {
  NODE_ENV: nodeEnv,
  PORT: port,
  DATABASE_URL: process.env.DATABASE_URL,
  JWT_SECRET: process.env.JWT_SECRET,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  BCRYPT_SALT_ROUNDS: parseInt(process.env.BCRYPT_SALT_ROUNDS, 10) || 12,
  DATA_ENCRYPTION_KEY:
    process.env.DATA_ENCRYPTION_KEY || 'rekber_secret_data_encryption_key_32_bytes_long_dev',
  PAYMENT_PROVIDER: (process.env.PAYMENT_PROVIDER || 'fake').toLowerCase(),
  XENDIT_SECRET_KEY: process.env.XENDIT_SECRET_KEY || '',
  XENDIT_WEBHOOK_VERIFICATION_TOKEN: process.env.XENDIT_WEBHOOK_VERIFICATION_TOKEN || '',
  STORAGE_PROVIDER: (process.env.STORAGE_PROVIDER || 'local').toLowerCase(),
  STORAGE_LOCAL_DIR: process.env.STORAGE_LOCAL_DIR || 'storage_uploads',
  STORAGE_LOCAL_SECRET: process.env.STORAGE_LOCAL_SECRET || process.env.JWT_SECRET,
  S3_BUCKET: process.env.S3_BUCKET || '',
  S3_REGION: process.env.S3_REGION || 'ap-southeast-1',
  S3_ENDPOINT: process.env.S3_ENDPOINT || null,
  S3_ACCESS_KEY_ID: process.env.S3_ACCESS_KEY_ID || '',
  S3_SECRET_ACCESS_KEY: process.env.S3_SECRET_ACCESS_KEY || '',
  S3_FORCE_PATH_STYLE: process.env.S3_FORCE_PATH_STYLE === 'true',
  FIREBASE_SERVICE_ACCOUNT_JSON: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '',
  RUN_JOBS_IN_API: process.env.RUN_JOBS_IN_API === 'true',
  WORKER_ACCELERATED_INTERVAL: process.env.WORKER_ACCELERATED_INTERVAL === 'true',
  METRICS_TOKEN: process.env.METRICS_TOKEN || 'rekber-metrics-token-secret',
  SENTRY_DSN: process.env.SENTRY_DSN || '',
  isDev: nodeEnv !== 'production',
  isProd: nodeEnv === 'production',
  isTest: nodeEnv === 'test',
  validateEnv,
};

module.exports = env;
