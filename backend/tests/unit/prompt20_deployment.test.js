// =============================================================================
// Test Suite: Prompt 20 - Deployment, Observability & Release Readiness
// =============================================================================

const request = require('supertest');
const app = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { validateEnv } = require('../../src/config/env');
const { scrubObject } = require('../../src/config/sentry');
const metricsService = require('../../src/services/metrics.service');

describe('PROMPT 20 — Deployment, Observability & Release Readiness', () => {
  describe('1. Production Environment Hardening (env.js)', () => {
    it('menolak start bila PAYMENT_PROVIDER bernilai fake pada production', () => {
      const errors = validateEnv({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
        JWT_SECRET: 'a_very_long_jwt_secret_that_has_more_than_32_characters',
        CORS_ORIGIN: 'https://admin.rekber.id',
        DATA_ENCRYPTION_KEY: 'production_encryption_key_at_least_32_bytes_long',
        PAYMENT_PROVIDER: 'fake',
        STORAGE_PROVIDER: 's3',
        S3_BUCKET: 'rekber-bucket',
        S3_ACCESS_KEY_ID: 'access_key',
        S3_SECRET_ACCESS_KEY: 'secret_key',
      });

      expect(errors).toContain(
        'PAYMENT_PROVIDER tidak boleh bernilai "fake" pada lingkungan production.'
      );
    });

    it('menolak start bila STORAGE_PROVIDER bernilai local pada production', () => {
      const errors = validateEnv({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
        JWT_SECRET: 'a_very_long_jwt_secret_that_has_more_than_32_characters',
        CORS_ORIGIN: 'https://admin.rekber.id',
        DATA_ENCRYPTION_KEY: 'production_encryption_key_at_least_32_bytes_long',
        PAYMENT_PROVIDER: 'xendit',
        XENDIT_SECRET_KEY: 'xnd_test_123',
        STORAGE_PROVIDER: 'local',
      });

      expect(errors).toContain(
        'STORAGE_PROVIDER tidak boleh bernilai "local" pada lingkungan production.'
      );
    });

    it('menolak start bila DATA_ENCRYPTION_KEY menggunakan nilai dev pada production', () => {
      const errors = validateEnv({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
        JWT_SECRET: 'a_very_long_jwt_secret_that_has_more_than_32_characters',
        CORS_ORIGIN: 'https://admin.rekber.id',
        DATA_ENCRYPTION_KEY: 'rekber_secret_data_encryption_key_32_bytes_long_dev',
        PAYMENT_PROVIDER: 'xendit',
        XENDIT_SECRET_KEY: 'xnd_test_123',
        STORAGE_PROVIDER: 's3',
        S3_BUCKET: 'bucket',
        S3_ACCESS_KEY_ID: 'id',
        S3_SECRET_ACCESS_KEY: 'secret',
      });

      expect(errors).toContain(
        'DATA_ENCRYPTION_KEY tidak boleh menggunakan nilai default pengujian pada production.'
      );
    });

    it('lolos validasi bila seluruh konfigurasi production valid', () => {
      const errors = validateEnv({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
        JWT_SECRET: 'a_very_long_jwt_secret_that_has_more_than_32_characters',
        CORS_ORIGIN: 'https://admin.rekber.id',
        DATA_ENCRYPTION_KEY: 'production_encryption_key_at_least_32_bytes_long',
        PAYMENT_PROVIDER: 'xendit',
        XENDIT_SECRET_KEY: 'xnd_production_secret',
        STORAGE_PROVIDER: 's3',
        S3_BUCKET: 'rekber-prod-storage',
        S3_ACCESS_KEY_ID: 'AKIA_PROD_EXAMPLE',
        S3_SECRET_ACCESS_KEY: 'SECRET_PROD_EXAMPLE_1234567890',
      });

      expect(errors).toHaveLength(0);
    });
  });

  describe('2. Health & Readiness Probes (/api/health & /api/health/ready)', () => {
    it('GET /api/health mengembalikan 200 status healthy (liveness probe)', async () => {
      const res = await request(app).get('/api/health');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.status).toBe('healthy');
    });

    it('GET /health (root path) mengembalikan 200 status healthy', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
    });

    it('GET /api/health/ready mengembalikan 200 saat database terhubung (readiness probe)', async () => {
      const res = await request(app).get('/api/health/ready');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.status).toBe('ready');
      expect(res.body.database).toBe('connected');
    });
  });

  describe('3. Maintenance Mode Middleware', () => {
    afterEach(async () => {
      // Pastikan maintenance_mode dikembalikan ke 'false'
      await prisma.platformSetting.upsert({
        where: { key: 'maintenance_mode' },
        update: { value: 'false' },
        create: { key: 'maintenance_mode', value: 'false' },
      });
      // Invalidate internal cache
      require('../../src/services/settings.service').clearCache();
    });

    it('mengembalikan 503 ketika maintenance_mode aktif untuk rute biasa', async () => {
      await prisma.platformSetting.upsert({
        where: { key: 'maintenance_mode' },
        update: { value: 'true' },
        create: { key: 'maintenance_mode', value: 'true' },
      });
      require('../../src/services/settings.service').clearCache();

      const res = await request(app).get('/api/config');
      expect(res.status).toBe(503);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('MAINTENANCE_MODE');
      expect(res.body.message).toContain('pemeliharaan');
    });

    it('tetap mengizinkan probe /api/health dan /api/health/ready saat maintenance_mode aktif', async () => {
      await prisma.platformSetting.upsert({
        where: { key: 'maintenance_mode' },
        update: { value: 'true' },
        create: { key: 'maintenance_mode', value: 'true' },
      });
      require('../../src/services/settings.service').clearCache();

      const resHealth = await request(app).get('/api/health');
      expect(resHealth.status).toBe(200);

      const resReady = await request(app).get('/api/health/ready');
      expect(resReady.status).toBe(200);
    });
  });

  describe('4. Sentry Sensitive Data Scrubber', () => {
    it('menyensor field sensitif (password, token, NIK, nomor rekening)', () => {
      const rawPayload = {
        email: 'user@example.com',
        password: 'SuperSecretPassword123!',
        token: 'jwt.token.here',
        nik: '3171012345678901',
        accountNumber: '1234567890',
        metadata: {
          refreshToken: 'refresh.secret.token',
          nested: {
            authSecret: 'my_nested_secret',
            regularName: 'Budi Santoso',
          },
        },
      };

      const sanitized = scrubObject(rawPayload);

      expect(sanitized.email).toBe('user@example.com');
      expect(sanitized.password).toBe('[REDACTED]');
      expect(sanitized.token).toBe('[REDACTED]');
      expect(sanitized.nik).toBe('[REDACTED]');
      expect(sanitized.accountNumber).toBe('[REDACTED]');
      expect(sanitized.metadata.refreshToken).toBe('[REDACTED]');
      expect(sanitized.metadata.nested.authSecret).toBe('[REDACTED]');
      expect(sanitized.metadata.nested.regularName).toBe('Budi Santoso');
    });
  });

  describe('5. Prometheus Metrics Endpoint (/metrics)', () => {
    it('menolak akses tanpa token atau token tidak valid dengan 401', async () => {
      const resNoToken = await request(app).get('/metrics');
      expect(resNoToken.status).toBe(401);
      expect(resNoToken.body.code).toBe('UNAUTHORIZED');

      const resWrongToken = await request(app)
        .get('/metrics')
        .set('X-Metrics-Token', 'wrong-token-value');
      expect(resWrongToken.status).toBe(401);
    });

    it('mengembalikan format prometheus 200 saat token valid', async () => {
      const token = process.env.METRICS_TOKEN || 'rekber-metrics-token-secret';

      // Test helper metrics
      metricsService.incrementJobFailure('autoReleaseTest');
      metricsService.recordReconcileDiscrepancies(0);

      const res = await request(app)
        .get('/metrics')
        .set('X-Metrics-Token', token);

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/plain');
      expect(res.text).toContain('rekber_transactions_total');
      expect(res.text).toContain('rekber_topups_total');
      expect(res.text).toContain('rekber_withdrawals_total');
      expect(res.text).toContain('rekber_disputes_total');
      expect(res.text).toContain('rekber_job_failures_total');
      expect(res.text).toContain('rekber_reconcile_discrepancies');
      expect(res.text).toContain('process_uptime_seconds');
      expect(res.text).toContain('process_resident_memory_bytes');
    });
  });
});
