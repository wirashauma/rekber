// =============================================================================
// REKBER Backend - Environment Validation
// =============================================================================
// Validates all critical environment variables on startup (fail-fast principle).
// If any required variable is missing or invalid, logs a descriptive error
// mentioning the variable name (never its value) and terminates the process.

require('dotenv').config();

const errors = [];

// 1. DATABASE_URL (Required)
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl || databaseUrl.trim() === '') {
  errors.push('DATABASE_URL wajib diisi.');
}

// 2. JWT_SECRET (Required, min 32 characters)
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret || jwtSecret.trim() === '') {
  errors.push('JWT_SECRET wajib diisi.');
} else if (jwtSecret.length < 32) {
  errors.push('JWT_SECRET harus memiliki panjang minimal 32 karakter demi keamanan token.');
}

// 3. NODE_ENV (Defaults to 'development')
const nodeEnv = process.env.NODE_ENV || 'development';
const validEnvironments = ['development', 'production', 'test'];
if (!validEnvironments.includes(nodeEnv)) {
  errors.push(`NODE_ENV tidak valid. Pilihan yang diizinkan: ${validEnvironments.join(', ')}.`);
}

// 4. PORT (Optional, defaults to 5000, 1-65535)
let port = 5000;
if (process.env.PORT) {
  const parsedPort = parseInt(process.env.PORT, 10);
  if (isNaN(parsedPort) || parsedPort <= 0 || parsedPort > 65535) {
    errors.push('PORT harus berupa angka antara 1 dan 65535.');
  } else {
    port = parsedPort;
  }
}

// 5. CORS_ORIGIN (Required when NODE_ENV=production)
const corsOrigin = process.env.CORS_ORIGIN;
if (nodeEnv === 'production' && (!corsOrigin || corsOrigin.trim() === '')) {
  errors.push('CORS_ORIGIN wajib diisi saat NODE_ENV bernilai "production".');
}

// Fail-fast if any validation errors occurred
if (errors.length > 0) {
  console.error('\n❌ Kesalahan Konfigurasi Environment:');
  errors.forEach((err, idx) => {
    console.error(`   ${idx + 1}. ${err}`);
  });
  console.error('\nSilakan periksa file konfigurasi environment (.env) Anda.\n');
  process.exit(1);
}

const env = {
  NODE_ENV: nodeEnv,
  PORT: port,
  DATABASE_URL: databaseUrl,
  JWT_SECRET: jwtSecret,
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  CORS_ORIGIN: corsOrigin || '*',
  BCRYPT_SALT_ROUNDS: parseInt(process.env.BCRYPT_SALT_ROUNDS, 10) || 12,
  DATA_ENCRYPTION_KEY:
    process.env.DATA_ENCRYPTION_KEY || 'rekber_secret_data_encryption_key_32_bytes_long_dev',
  PAYMENT_PROVIDER: (process.env.PAYMENT_PROVIDER || 'fake').toLowerCase(),
  XENDIT_SECRET_KEY: process.env.XENDIT_SECRET_KEY || '',
  XENDIT_WEBHOOK_VERIFICATION_TOKEN: process.env.XENDIT_WEBHOOK_VERIFICATION_TOKEN || '',
  STORAGE_PROVIDER: (process.env.STORAGE_PROVIDER || 'local').toLowerCase(),
  STORAGE_LOCAL_DIR: process.env.STORAGE_LOCAL_DIR || 'storage_uploads',
  STORAGE_LOCAL_SECRET: process.env.STORAGE_LOCAL_SECRET || jwtSecret,
  S3_BUCKET: process.env.S3_BUCKET || '',
  S3_REGION: process.env.S3_REGION || 'ap-southeast-1',
  S3_ENDPOINT: process.env.S3_ENDPOINT || null,
  S3_ACCESS_KEY_ID: process.env.S3_ACCESS_KEY_ID || '',
  S3_SECRET_ACCESS_KEY: process.env.S3_SECRET_ACCESS_KEY || '',
  S3_FORCE_PATH_STYLE: process.env.S3_FORCE_PATH_STYLE === 'true',
  isDev: nodeEnv !== 'production',
  isProd: nodeEnv === 'production',
  isTest: nodeEnv === 'test',
};

module.exports = env;
