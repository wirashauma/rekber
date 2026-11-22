// =============================================================================
// Automated Security Test Suite (Prompt 19 Deliverable 2)
// Comprehensive IDOR sweep, Auth guards, Mass assignment, Injection resistance,
// Helmet headers, CORS policies, Rate limiting, Leak scans, and JWT attack suite.
// =============================================================================

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const config = require('../../src/config');
const {
  createUser,
  tokenFor,
  createTransaction,
  createDispute,
  resetDb,
  disconnectDb,
} = require('../helpers');
const { encrypt } = require('../../src/utils/encryption');

const app = createApp();

// Recursive response scanner for sensitive fields
const scanForSensitiveData = (obj, path = '') => {
  const leaks = [];
  if (!obj || typeof obj !== 'object') return leaks;

  for (const [key, val] of Object.entries(obj)) {
    const currentPath = path ? `${path}.${key}` : key;

    // Check sensitive keys
    const lowerKey = key.toLowerCase();
    if (
      ['password', 'passwordhash', 'tokenhash', 'secret'].includes(lowerKey) &&
      val !== null &&
      val !== undefined
    ) {
      leaks.push(`Kunci sensitif terdeteksi: ${currentPath}`);
    }

    // Check values for unmasked 16-digit NIK
    if (typeof val === 'string') {
      if (/^\d{16}$/.test(val.trim())) {
        leaks.push(`Unmasked 16-digit NIK terdeteksi di: ${currentPath} (${val})`);
      }
      // Check full bank account numbers (>8 digits with no masking asterisk)
      if (/^\d{10,16}$/.test(val.trim()) && !val.includes('•') && !val.includes('*')) {
        // Exclude UUID timestamps or purely numeric test IDs if any
        if (lowerKey.includes('accountnumber') || lowerKey === 'accountno') {
          leaks.push(`Unmasked full account number terdeteksi di: ${currentPath}`);
        }
      }
    } else if (typeof val === 'object') {
      leaks.push(...scanForSensitiveData(val, currentPath));
    }
  }

  return leaks;
};

describe('Automated Security Test Suite (Prompt 19)', () => {
  let adminUser;
  let victimUser;
  let attackerUser;
  let adminToken;
  let victimToken;
  let attackerToken;

  afterAll(async () => {
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();

    // Default platform settings
    const defaultSettings = [
      { key: 'fee_percent', value: '2' },
      { key: 'fee_min', value: '1000' },
      { key: 'fee_payer_default', value: 'SPLIT' },
      { key: 'auto_release_hours', value: '72' },
      { key: 'pending_expire_hours', value: '24' },
      { key: 'withdraw_min', value: '50000' },
      { key: 'withdraw_fee', value: '0' },
      { key: 'withdraw_daily_limit', value: '10000000' },
      { key: 'max_transaction_amount', value: '5000000' },
      { key: 'maintenance_mode', value: 'false' },
    ];
    for (const s of defaultSettings) {
      await prisma.platformSetting.upsert({
        where: { key: s.key },
        update: { value: s.value },
        create: { key: s.key, value: s.value },
      });
    }

    adminUser = await createUser({
      name: 'Admin Security',
      email: 'admin.sec@test.com',
      role: 'ADMIN',
      kycStatus: 'APPROVED',
    });
    victimUser = await createUser({
      name: 'Victim User',
      email: 'victim@test.com',
      role: 'USER',
      balance: 1000000n,
      kycStatus: 'APPROVED',
    });
    attackerUser = await createUser({
      name: 'Attacker User',
      email: 'attacker@test.com',
      role: 'USER',
      balance: 100000n,
      kycStatus: 'NONE',
    });

    adminToken = tokenFor(adminUser);
    victimToken = tokenFor(victimUser);
    attackerToken = tokenFor(attackerUser);
  });

  // ---------------------------------------------------------------------------
  // 1. Sapu IDOR Seluruh Endpoint ber-:id
  // ---------------------------------------------------------------------------
  describe('1. Sapu IDOR Terotomasi (Exhaustive :id Route Sweep)', () => {
    let victimTx;
    let victimPendingTx;
    let victimDispute;
    let victimBankAccount;
    let victimFile;
    let victimNotification;
    let victimTopup;
    let victimWithdrawal;
    let victimKyc;

    beforeEach(async () => {
      // Setup victim resources
      victimTx = await createTransaction({
        buyerId: victimUser.id,
        amount: 200000,
        status: 'PAID',
      });

      victimPendingTx = await createTransaction({
        buyerId: victimUser.id,
        amount: 100000,
        status: 'PENDING',
      });

      victimDispute = await createDispute({
        transactionId: victimTx.id,
        openedById: victimUser.id,
        status: 'OPEN',
      });

      victimBankAccount = await prisma.bankAccount.create({
        data: {
          userId: victimUser.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Victim User',
        },
      });

      victimFile = await prisma.fileAsset.create({
        data: {
          ownerId: victimUser.id,
          purpose: 'SHIPMENT_PROOF',
          storageKey: 'shipment/victim_proof.jpg',
          mime: 'image/jpeg',
          size: 1024,
          sha256: 'hash_victim_file_123',
        },
      });

      victimNotification = await prisma.notification.create({
        data: {
          userId: victimUser.id,
          type: 'TRANSACTION_PAID',
          title: 'Notifikasi Korban',
          body: 'Pembayaran berhasil diverifikasi.',
          data: { txId: victimTx.id },
        },
      });

      victimTopup = await prisma.paymentIntent.create({
        data: {
          userId: victimUser.id,
          provider: 'FAKE',
          referenceId: `topup_victim_${Date.now()}`,
          amount: 500000n,
          method: 'QRIS',
          status: 'PENDING',
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        },
      });

      victimWithdrawal = await prisma.withdrawalRequest.create({
        data: {
          userId: victimUser.id,
          bankAccountId: victimBankAccount.id,
          amount: 100000n,
          fee: 0n,
          status: 'PENDING_REVIEW',
          idempotencyKey: `idem_victim_with_${Date.now()}`,
        },
      });

      victimKyc = await prisma.kycSubmission.create({
        data: {
          userId: victimUser.id,
          fullName: 'Victim User',
          nikEnc: encrypt('3201123456789012'),
          idFileId: victimFile.id,
          selfieFileId: victimFile.id,
          status: 'PENDING',
        },
      });
    });

    test('Memverifikasi seluruh endpoint :id menolak akses pengguna tidak berhak (IDOR Protection)', async () => {
      // Registry of all 26 extracted :id endpoints and their respective test calls
      const idorCases = [
        {
          method: 'get',
          path: `/api/transactions/${victimTx.id}`,
          desc: 'GET transaction by non-participant',
        },
        {
          method: 'post',
          path: `/api/transactions/${victimTx.id}/shipment`,
          body: { courier: 'JNE', trackingNumber: 'JNE123456789' },
          desc: 'Submit shipment by unauthorized user',
        },
        {
          method: 'post',
          path: `/api/transactions/${victimTx.id}/dispute`,
          body: {
            reason: 'NOT_RECEIVED',
            description: 'Barang tidak saya terima sama sekali.',
          },
          desc: 'Open dispute by non-buyer',
        },
        {
          method: 'get',
          path: `/api/transactions/${victimTx.id}/dispute`,
          desc: 'View dispute by non-participant',
        },
        {
          method: 'put',
          path: `/api/transactions/${victimPendingTx.id}/status`,
          body: { status: 'CANCELLED' },
          desc: 'Cancel transaction by non-participant',
        },
        {
          method: 'get',
          path: `/api/transactions/${victimTx.id}/messages`,
          desc: 'Read messages by non-participant',
        },
        {
          method: 'post',
          path: `/api/transactions/${victimTx.id}/messages`,
          body: { type: 'TEXT', body: 'Pesan penyusup' },
          desc: 'Send message by non-participant',
        },
        {
          method: 'post',
          path: `/api/transactions/${victimTx.id}/messages/read`,
          desc: 'Mark read by non-participant',
        },
        {
          method: 'get',
          path: `/api/wallet/topups/${victimTopup.id}`,
          desc: 'View victim topup intent',
        },
        {
          method: 'post',
          path: `/api/wallet/withdrawals/${victimWithdrawal.id}/cancel`,
          desc: 'Cancel victim withdrawal',
        },
        {
          method: 'delete',
          path: `/api/bank-accounts/${victimBankAccount.id}`,
          desc: 'Delete victim bank account',
        },
        {
          method: 'get',
          path: `/api/files/${victimFile.id}/url`,
          desc: 'Access signed URL of non-owned file',
        },
        {
          method: 'get',
          path: `/api/disputes/${victimDispute.id}`,
          desc: 'View dispute by non-participant',
        },
        {
          method: 'post',
          path: `/api/disputes/${victimDispute.id}/evidence`,
          body: { note: 'Bukti palsu penyusup' },
          desc: 'Submit evidence by non-participant',
        },
        {
          method: 'post',
          path: `/api/notifications/${victimNotification.id}/read`,
          desc: 'Mark victim notification as read',
        },
        // Admin endpoints accessed with regular USER token
        {
          method: 'post',
          path: `/api/admin/withdrawals/${victimWithdrawal.id}/approve`,
          desc: 'Approve withdrawal as user',
        },
        {
          method: 'post',
          path: `/api/admin/withdrawals/${victimWithdrawal.id}/reject`,
          desc: 'Reject withdrawal as user',
        },
        {
          method: 'get',
          path: `/api/admin/disputes/${victimDispute.id}`,
          desc: 'View admin dispute as user',
        },
        {
          method: 'post',
          path: `/api/admin/disputes/${victimDispute.id}/review`,
          desc: 'Review dispute as user',
        },
        {
          method: 'post',
          path: `/api/admin/disputes/${victimDispute.id}/resolve`,
          body: { decision: 'REFUND_TO_BUYER', note: 'Resolusi ilegal' },
          desc: 'Resolve dispute as user',
        },
        {
          method: 'get',
          path: `/api/admin/kyc/${victimKyc.id}`,
          desc: 'View KYC submission as user',
        },
        {
          method: 'post',
          path: `/api/admin/kyc/${victimKyc.id}/approve`,
          desc: 'Approve KYC as user',
        },
        {
          method: 'post',
          path: `/api/admin/kyc/${victimKyc.id}/reject`,
          body: { reason: 'Ditolak penyusup' },
          desc: 'Reject KYC as user',
        },
        {
          method: 'get',
          path: `/api/admin/users/${victimUser.id}`,
          desc: 'View user profile as user',
        },
        {
          method: 'post',
          path: `/api/admin/users/${victimUser.id}/ban`,
          body: { reason: 'Ban ilegal' },
          desc: 'Ban user as non-admin',
        },
        {
          method: 'post',
          path: `/api/admin/users/${victimUser.id}/unban`,
          desc: 'Unban user as non-admin',
        },
      ];

      for (const item of idorCases) {
        let req = request(app)[item.method](item.path).set(
          'Authorization',
          `Bearer ${attackerToken}`
        );

        if (item.body) {
          req = req.send(item.body);
        }

        const res = await req;
        // Every single endpoint must reject the unauthorized attacker with 403 or 404
        expect([403, 404]).toContain(res.status);
        expect(res.body.success).toBe(false);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Semua Endpoint Non-Publik Tanpa Token -> 401
  // ---------------------------------------------------------------------------
  describe('2. Endpoint Non-Publik Tanpa Token', () => {
    test('Menolak request tanpa Authorization header dengan status 401', async () => {
      const protectedEndpoints = [
        { method: 'get', path: '/api/auth/me' },
        { method: 'put', path: '/api/auth/profile' },
        { method: 'get', path: '/api/transactions' },
        { method: 'post', path: '/api/transactions' },
        { method: 'get', path: '/api/wallet' },
        { method: 'get', path: '/api/wallet/ledger' },
        { method: 'post', path: '/api/wallet/topups' },
        { method: 'get', path: '/api/bank-accounts' },
        { method: 'post', path: '/api/bank-accounts' },
        { method: 'get', path: '/api/notifications' },
        { method: 'get', path: '/api/kyc/me' },
        { method: 'get', path: '/api/admin/metrics/dashboard' },
        { method: 'get', path: '/api/admin/users' },
      ];

      for (const ep of protectedEndpoints) {
        const res = await request(app)[ep.method](ep.path);
        expect(res.status).toBe(401);
        expect(res.body.success).toBe(false);
        expect(res.body.code).toBe('UNAUTHORIZED');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Endpoint Admin Sebagai USER -> 403
  // ---------------------------------------------------------------------------
  describe('3. Endpoint Admin Sebagai Regular USER', () => {
    test('Menolak regular USER pada semua endpoint admin dengan status 403', async () => {
      const adminEndpoints = [
        { method: 'get', path: '/api/admin/metrics/dashboard' },
        { method: 'get', path: '/api/admin/metrics/growth' },
        { method: 'get', path: '/api/admin/metrics/disputes' },
        { method: 'get', path: '/api/admin/users' },
        { method: 'get', path: '/api/admin/kyc' },
        { method: 'get', path: '/api/admin/disputes' },
        { method: 'get', path: '/api/admin/withdrawals' },
        { method: 'get', path: '/api/admin/settings' },
        { method: 'put', path: '/api/admin/settings' },
        { method: 'get', path: '/api/admin/transactions' },
        { method: 'get', path: '/api/admin/audit-logs' },
      ];

      for (const ep of adminEndpoints) {
        const res = await request(app)[ep.method](ep.path).set(
          'Authorization',
          `Bearer ${attackerToken}`
        );
        expect(res.status).toBe(403);
        expect(res.body.success).toBe(false);
        expect(res.body.code).toBe('FORBIDDEN');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Mass Assignment Protection
  // ---------------------------------------------------------------------------
  describe('4. Mass Assignment Protection', () => {
    test('Parameter istimewa (role, balance, status, isActive) diabaikan pada register dan update', async () => {
      // a. Register: mencoba menyusupkan role ADMIN dan balance 10 juta
      const regRes = await request(app).post('/api/auth/register').send({
        name: 'Hacker User',
        email: 'hacker@test.com',
        password: 'Password123!',
        role: 'ADMIN',
        balance: 10000000,
        isActive: false,
        kycStatus: 'APPROVED',
      });

      expect(regRes.status).toBe(201);
      const hacker = regRes.body.data.user;
      expect(hacker.role).toBe('USER');
      expect(hacker.balance).toBe(0);

      // Verifikasi di DB
      const hackerInDb = await prisma.user.findUnique({ where: { email: 'hacker@test.com' } });
      expect(hackerInDb.role).toBe('USER');
      expect(hackerInDb.balance).toBe(0n);
      expect(hackerInDb.kycStatus).toBe('NONE');

      // b. Profile update: mencoba mengubah role & balance
      const updateRes = await request(app)
        .put('/api/auth/profile')
        .set('Authorization', `Bearer ${regRes.body.data.accessToken}`)
        .send({
          name: 'Hacker Renamed',
          role: 'ADMIN',
          balance: 99999999,
          isActive: false,
        });
      expect(updateRes.status).toBe(200);

      const recheckedDb = await prisma.user.findUnique({ where: { id: hacker.id } });
      expect(recheckedDb.role).toBe('USER');
      expect(recheckedDb.balance).toBe(0n);
      expect(recheckedDb.name).toBe('Hacker Renamed');

      // c. Transaction creation: mencoba menyusupkan status COMPLETED & heldAmount 0
      const seller = await createUser();
      const txRes = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${victimToken}`)
        .send({
          sellerId: seller.id,
          amount: 50000,
          itemDescription: 'Barang Normal',
          status: 'COMPLETED',
          heldAmount: 0,
        });
      expect(txRes.status).toBe(201);
      expect(txRes.body.data.status).toBe('PENDING');
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Payload Injeksi pada Parameter Query
  // ---------------------------------------------------------------------------
  describe('5. Ketahanan Terhadap Injeksi SQL / Query Injection', () => {
    test('Query parameter dengan payload SQL injection ditangani secara aman tanpa error 500', async () => {
      const injectionPayloads = [
        "' OR '1'='1",
        "1; DROP TABLE users; --",
        "admin'--",
        "' UNION SELECT id, password, email FROM users --",
        "<script>alert(1)</script>",
      ];

      for (const payload of injectionPayloads) {
        // Search opponent endpoint
        const resOpponent = await request(app)
          .get(`/api/auth/search-opponent?q=${encodeURIComponent(payload)}`)
          .set('Authorization', `Bearer ${victimToken}`);
        expect([200, 400, 422]).toContain(resOpponent.status);

        // Transactions list endpoint
        const resTx = await request(app)
          .get(`/api/transactions?search=${encodeURIComponent(payload)}`)
          .set('Authorization', `Bearer ${victimToken}`);
        expect([200, 400, 422]).toContain(resTx.status);

        // Admin users list endpoint
        const resAdminUsers = await request(app)
          .get(`/api/admin/users?search=${encodeURIComponent(payload)}`)
          .set('Authorization', `Bearer ${adminToken}`);
        expect([200, 400, 422]).toContain(resAdminUsers.status);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Header Helmet Keamanan
  // ---------------------------------------------------------------------------
  describe('6. Header Keamanan Helmet', () => {
    test('Menyertakan header keamanan penting pada setiap respons', async () => {
      const res = await request(app).get('/api/health');
      expect(res.status).toBe(200);

      // Verify helmet headers
      expect(res.headers['x-content-type-options']).toBe('nosniff');
      expect(res.headers['x-frame-options']).toBeDefined();
      expect(res.headers['x-dns-prefetch-control']).toBe('off');
    });
  });

  // ---------------------------------------------------------------------------
  // 7. CORS Production Check
  // ---------------------------------------------------------------------------
  describe('7. Kebijakan CORS Lingkungan Produksi', () => {
    test('Menolak origin yang tidak terdaftar saat konfigurasi produksi aktif', async () => {
      const originalIsProd = config.isProd;
      const originalCors = process.env.CORS_ORIGIN;

      try {
        config.isProd = true;
        process.env.CORS_ORIGIN = 'https://app.rekber.com,https://admin.rekber.com';

        const prodApp = createApp();

        // Disallowed origin
        const badOriginRes = await request(prodApp)
          .get('/api/health')
          .set('Origin', 'https://attacker-phishing.com');
        // CORS rejection returns error status (500 via Express error handler)
        expect([403, 500]).toContain(badOriginRes.status);

        // Allowed origin
        const goodOriginRes = await request(prodApp)
          .get('/api/health')
          .set('Origin', 'https://app.rekber.com');
        expect(goodOriginRes.status).toBe(200);
        expect(goodOriginRes.headers['access-control-allow-origin']).toBe('https://app.rekber.com');
      } finally {
        config.isProd = originalIsProd;
        process.env.CORS_ORIGIN = originalCors;
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Rate Limiting Aktif
  // ---------------------------------------------------------------------------
  describe('8. Pengujian Rate Limiting', () => {
    test('Mengembalikan status 429 ketika frekuensi permintaan melebihi batas', async () => {
      const origTestRate = process.env.TEST_RATE_LIMIT;
      try {
        process.env.TEST_RATE_LIMIT = 'true';
        const { createLimiter } = require('../../src/middlewares/rateLimit.middleware');
        const express = require('express');
        const testApp = express();
        const testLimiter = createLimiter({
          windowMs: 60 * 1000,
          max: 3,
          message: 'Terlalu banyak permintaan untuk tes.',
        });

        testApp.use(testLimiter);
        testApp.get('/test-rate', (req, res) => res.json({ ok: true }));

        // Send 5 rapid requests
        let hit429 = false;
        for (let i = 0; i < 5; i++) {
          const res = await request(testApp).get('/test-rate');
          if (res.status === 429) {
            hit429 = true;
            expect(res.body.code).toBe('TOO_MANY_REQUESTS');
            break;
          }
        }
        expect(hit429).toBe(true);
      } finally {
        if (origTestRate === undefined) {
          delete process.env.TEST_RATE_LIMIT;
        } else {
          process.env.TEST_RATE_LIMIT = origTestRate;
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Tidak Ada Stack Trace Bocor di Respons Error
  // ---------------------------------------------------------------------------
  describe('9. Pencegahan Kebocoran Stack Trace', () => {
    test('Respons error 400, 401, 403, 404, 500 tidak memuat stack trace atau path file internal', async () => {
      const errorRequests = [
        request(app).get('/api/non-existent-route-xyz'), // 404
        request(app).post('/api/auth/login').send({ email: 'bad' }), // 400
        request(app).get('/api/wallet'), // 401
        request(app).get('/api/admin/users').set('Authorization', `Bearer ${victimToken}`), // 403
      ];

      for (const reqPromise of errorRequests) {
        const res = await reqPromise;
        expect(res.body.stack).toBeUndefined();
        const rawBody = JSON.stringify(res.body);
        expect(rawBody).not.toMatch(/\s+at\s+/);
        expect(rawBody).not.toContain('node_modules');
        expect(rawBody).not.toContain('rekber\\backend');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Pemindaian Respons JSON dari Data Sensitif (Password, Hash, NIK, Rekening)
  // ---------------------------------------------------------------------------
  describe('10. Pindai Respons JSON dari Data Sensitif', () => {
    test('Tidak ada kebocoran password hash, token hash, atau nomor rekening/NIK polos', async () => {
      // Login
      const loginRes = await request(app).post('/api/auth/login').send({
        email: 'victim@test.com',
        password: 'Password123',
      });
      expect(scanForSensitiveData(loginRes.body)).toHaveLength(0);

      // Me
      const meRes = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${victimToken}`);
      expect(scanForSensitiveData(meRes.body)).toHaveLength(0);

      // Bank account (must be masked)
      await prisma.bankAccount.create({
        data: {
          userId: victimUser.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Victim User',
        },
      });
      const bankRes = await request(app)
        .get('/api/bank-accounts')
        .set('Authorization', `Bearer ${victimToken}`);
      expect(scanForSensitiveData(bankRes.body)).toHaveLength(0);
      expect(bankRes.body.data[0].accountNumberMasked).toContain('••••');

      // Admin user detail
      const adminUserRes = await request(app)
        .get(`/api/admin/users/${victimUser.id}`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(scanForSensitiveData(adminUserRes.body)).toHaveLength(0);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Pengujian Keamanan JWT
  // ---------------------------------------------------------------------------
  describe('11. Pengujian Keamanan JWT (Alg None, Signature, Expiry, Banned)', () => {
    test('Menolak token dengan alg: none', async () => {
      // Unsigned JWT with alg: none
      const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
      const payload = Buffer.from(
        JSON.stringify({ id: adminUser.id, role: 'ADMIN', email: adminUser.email })
      ).toString('base64url');
      const unsignedToken = `${header}.${payload}.`;

      const res = await request(app)
        .get('/api/admin/users')
        .set('Authorization', `Bearer ${unsignedToken}`);
      expect(res.status).toBe(401);
      expect(['UNAUTHORIZED', 'INVALID_TOKEN']).toContain(res.body.code);
    });

    test('Menolak token dengan signature yang telah dimodifikasi (tampered)', async () => {
      const validToken = tokenFor(adminUser);
      const parts = validToken.split('.');
      // Tamper signature
      const tamperedSignature = parts[2].substring(0, parts[2].length - 4) + 'XXXX';
      const tamperedToken = `${parts[0]}.${parts[1]}.${tamperedSignature}`;

      const res = await request(app)
        .get('/api/admin/users')
        .set('Authorization', `Bearer ${tamperedToken}`);
      expect(res.status).toBe(401);
      expect(['UNAUTHORIZED', 'INVALID_TOKEN']).toContain(res.body.code);
    });

    test('Menolak token yang telah kedaluwarsa (expired)', async () => {
      const expiredToken = jwt.sign(
        { id: victimUser.id, email: victimUser.email, role: 'USER' },
        config.jwt.secret,
        { expiresIn: '-10s' }
      );

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${expiredToken}`);
      expect(res.status).toBe(401);
      expect(['UNAUTHORIZED', 'TOKEN_EXPIRED']).toContain(res.body.code);
    });

    test('Menolak token milik pengguna yang telah dinonaktifkan (isActive: false)', async () => {
      const bannedUser = await createUser({ isActive: false });
      const bannedToken = tokenFor(bannedUser);

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${bannedToken}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('ACCOUNT_INACTIVE');
    });
  });
});
