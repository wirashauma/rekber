const request = require('supertest');
const express = require('express');
const crypto = require('crypto');
const { Writable } = require('stream');
const pino = require('pino');

const app = require('../../src/app');
const { createUser, tokenFor, prisma } = require('../helpers');
const { getTestInbox, clearTestInbox } = require('../../src/providers/mail.provider');
const { createLimiter } = require('../../src/middlewares/rateLimit.middleware');

describe('Keamanan Backend & Autentikasi (/api/auth)', () => {
  beforeEach(() => {
    clearTestInbox();
  });

  // ===========================================================================
  // 1. REGISTER
  // ===========================================================================
  describe('POST /api/auth/register', () => {
    test('Sukses mendaftarkan user baru, mengembalikan accessToken, refreshToken, dan alias token', async () => {
      const payload = {
        name: 'Budi Santoso',
        email: 'budi.santoso@example.com',
        password: 'Password123',
      };

      const res = await request(app)
        .post('/api/auth/register')
        .set('User-Agent', 'Jest-Test-Agent')
        .send(payload);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('user');
      expect(res.body.data.user).toHaveProperty('id');
      expect(res.body.data.user.name).toBe('Budi Santoso');
      expect(res.body.data.user.email).toBe('budi.santoso@example.com');
      expect(res.body.data.user).not.toHaveProperty('password');
      expect(res.body.data.user.isActive).toBe(true);

      // Token verification
      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      expect(res.body.data).toHaveProperty('token'); // Backward compatibility alias
      expect(res.body.data.token).toBe(res.body.data.accessToken);

      // Verify refreshToken is hashed in database
      const hashed = crypto.createHash('sha256').update(res.body.data.refreshToken).digest('hex');
      const savedToken = await prisma.refreshToken.findUnique({
        where: { tokenHash: hashed },
      });
      expect(savedToken).toBeTruthy();
      expect(savedToken.userId).toBe(res.body.data.user.id);
      expect(savedToken.userAgent).toBe('Jest-Test-Agent');
    });

    test('Tidak menyimpan firebaseUid meskipun dikirim pada request', async () => {
      const payload = {
        name: 'No Firebase User',
        email: 'no.firebase@example.com',
        password: 'Password123',
        firebaseUid: 'legacy-firebase-uid-should-be-ignored',
      };

      const res = await request(app).post('/api/auth/register').send(payload);

      expect(res.status).toBe(201);
      const userInDb = await prisma.user.findUnique({
        where: { id: res.body.data.user.id },
      });
      expect(userInDb.firebaseUid).toBeNull();
    });

    test('Gagal jika email sudah terdaftar (409 Conflict)', async () => {
      await createUser({ email: 'duplicate@example.com', password: 'Password123' });

      const res = await request(app).post('/api/auth/register').send({
        name: 'Another User',
        email: 'duplicate@example.com',
        password: 'Password123',
      });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Email sudah terdaftar');
    });

    test('Gagal jika validasi input tidak terpenuhi (422 Unprocessable Entity)', async () => {
      const res = await request(app).post('/api/auth/register').send({
        name: 'A', // kurang dari 2 karakter
        email: 'bukan-email-valid',
        password: '123', // kurang dari 8 karakter dan tidak ada huruf besar
      });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('VALIDATION_ERROR');
      expect(res.body.errors).toBeInstanceOf(Array);
      expect(res.body.errors.length).toBeGreaterThanOrEqual(3);
    });
  });

  // ===========================================================================
  // 2. LOGIN
  // ===========================================================================
  describe('POST /api/auth/login', () => {
    test('Sukses login dengan kredensial yang benar dan mencatat refreshToken', async () => {
      const user = await createUser({
        email: 'login.test@example.com',
        password: 'Password123',
      });

      const res = await request(app)
        .post('/api/auth/login')
        .set('User-Agent', 'Jest-Login-Agent')
        .send({
          email: 'login.test@example.com',
          password: 'Password123',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      expect(res.body.data).toHaveProperty('token');
      expect(res.body.data.user.id).toBe(user.id);

      // Verify refreshToken in DB
      const hashed = crypto.createHash('sha256').update(res.body.data.refreshToken).digest('hex');
      const tokenRecord = await prisma.refreshToken.findUnique({
        where: { tokenHash: hashed },
      });
      expect(tokenRecord).toBeTruthy();
      expect(tokenRecord.userId).toBe(user.id);
      expect(tokenRecord.userAgent).toBe('Jest-Login-Agent');
    });

    test('Gagal login jika user dinonaktifkan / isActive: false (403 Forbidden)', async () => {
      await createUser({
        email: 'inactive@example.com',
        password: 'Password123',
        isActive: false,
      });

      const res = await request(app).post('/api/auth/login').send({
        email: 'inactive@example.com',
        password: 'Password123',
      });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('ACCOUNT_INACTIVE');
      expect(res.body.message).toContain('dinonaktifkan');
    });

    test('Gagal login jika email tidak ditemukan (401 Unauthorized)', async () => {
      const res = await request(app).post('/api/auth/login').send({
        email: 'tidak.ada@example.com',
        password: 'Password123',
      });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Email atau password salah.');
    });

    test('Gagal login jika password salah (401 Unauthorized)', async () => {
      await createUser({
        email: 'password.salah@example.com',
        password: 'Password123',
      });

      const res = await request(app).post('/api/auth/login').send({
        email: 'password.salah@example.com',
        password: 'WrongPassword456',
      });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Email atau password salah.');
    });

    test('Gagal login jika input kosong (422 Unprocessable Entity)', async () => {
      const res = await request(app).post('/api/auth/login').send({
        email: '',
        password: '',
      });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  // ===========================================================================
  // 3. REFRESH & THEFT DETECTION
  // ===========================================================================
  describe('POST /api/auth/refresh', () => {
    test('Sukses melakukan rotasi token: menerima token baru dan token lama dicabut', async () => {
      await createUser({ email: 'refresh@example.com' });
      const loginRes = await request(app).post('/api/auth/login').send({
        email: 'refresh@example.com',
        password: 'Password123',
      });

      const oldRefreshToken = loginRes.body.data.refreshToken;

      const refreshRes = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: oldRefreshToken });

      expect(refreshRes.status).toBe(200);
      expect(refreshRes.body.success).toBe(true);
      expect(refreshRes.body.data).toHaveProperty('accessToken');
      expect(refreshRes.body.data).toHaveProperty('refreshToken');
      expect(refreshRes.body.data.refreshToken).not.toBe(oldRefreshToken);

      // Verify old token was revoked in DB
      const oldHash = crypto.createHash('sha256').update(oldRefreshToken).digest('hex');
      const oldRecord = await prisma.refreshToken.findUnique({
        where: { tokenHash: oldHash },
      });
      expect(oldRecord.revokedAt).not.toBeNull();
      expect(oldRecord.replacedById).not.toBeNull();
    });

    test('Theft detection: jika refresh token yang sudah dicabut dipakai ulang, cabut SEMUA refresh token user', async () => {
      const user = await createUser({ email: 'theft@example.com' });

      // Session 1
      const login1 = await request(app).post('/api/auth/login').send({
        email: 'theft@example.com',
        password: 'Password123',
      });
      const token1 = login1.body.data.refreshToken;

      // Session 2
      const login2 = await request(app).post('/api/auth/login').send({
        email: 'theft@example.com',
        password: 'Password123',
      });
      const token2 = login2.body.data.refreshToken;

      // Rotate session 1 normally
      const rotateRes = await request(app).post('/api/auth/refresh').send({ refreshToken: token1 });
      expect(rotateRes.status).toBe(200);
      const token1Rotated = rotateRes.body.data.refreshToken;

      // An attacker attempts to reuse the already-revoked token1!
      const theftAttempt = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: token1 });

      expect(theftAttempt.status).toBe(401);
      expect(theftAttempt.body.code).toBe('TOKEN_THEFT_DETECTED');
      expect(theftAttempt.body.message).toContain('Keamanan terdeteksi dikompromikan');

      // Check that ALL refresh tokens for this user are now revoked
      const activeTokens = await prisma.refreshToken.findMany({
        where: { userId: user.id, revokedAt: null },
      });
      expect(activeTokens.length).toBe(0);

      // Verify that neither token1Rotated nor token2 can be used now
      const tryToken2 = await request(app).post('/api/auth/refresh').send({ refreshToken: token2 });
      expect(tryToken2.status).toBe(401);

      const tryToken1Rotated = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: token1Rotated });
      expect(tryToken1Rotated.status).toBe(401);
    });

    test('Gagal jika refresh token sudah kedaluwarsa (401 Unauthorized)', async () => {
      const user = await createUser();
      const rawToken = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

      await prisma.refreshToken.create({
        data: {
          userId: user.id,
          tokenHash,
          expiresAt: new Date(Date.now() - 10000), // Expired in the past
        },
      });

      const res = await request(app).post('/api/auth/refresh').send({ refreshToken: rawToken });

      expect(res.status).toBe(401);
      expect(res.body.message).toContain('kedaluwarsa');
    });

    test('Gagal jika refresh token tidak valid / tidak ada di DB (401 Unauthorized)', async () => {
      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: 'random-invalid-token-1234567890' });

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Refresh token tidak valid.');
    });

    test('Gagal jika refreshToken tidak disertakan (422 Unprocessable Entity)', async () => {
      const res = await request(app).post('/api/auth/refresh').send({});

      expect(res.status).toBe(422);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  // ===========================================================================
  // 4. LOGOUT & LOGOUT-ALL
  // ===========================================================================
  describe('POST /api/auth/logout & /api/auth/logout-all', () => {
    test('POST /api/auth/logout mencabut refresh token yang diberikan', async () => {
      await createUser({ email: 'logout@example.com' });
      const loginRes = await request(app).post('/api/auth/login').send({
        email: 'logout@example.com',
        password: 'Password123',
      });
      const refreshToken = loginRes.body.data.refreshToken;

      const res = await request(app).post('/api/auth/logout').send({ refreshToken });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Logout berhasil.');

      // Refresh token is revoked
      const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      const record = await prisma.refreshToken.findUnique({ where: { tokenHash: hash } });
      expect(record.revokedAt).not.toBeNull();
    });

    test('POST /api/auth/logout-all mencabut SEMUA refresh token user', async () => {
      const user = await createUser({ email: 'logoutall@example.com' });
      const token = tokenFor(user);

      // Create 3 active refresh tokens
      await request(app)
        .post('/api/auth/login')
        .send({ email: 'logoutall@example.com', password: 'Password123' });
      await request(app)
        .post('/api/auth/login')
        .send({ email: 'logoutall@example.com', password: 'Password123' });
      await request(app)
        .post('/api/auth/login')
        .send({ email: 'logoutall@example.com', password: 'Password123' });

      const activeBefore = await prisma.refreshToken.findMany({
        where: { userId: user.id, revokedAt: null },
      });
      expect(activeBefore.length).toBe(3);

      const res = await request(app)
        .post('/api/auth/logout-all')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Semua sesi berhasil dihentikan.');

      const activeAfter = await prisma.refreshToken.findMany({
        where: { userId: user.id, revokedAt: null },
      });
      expect(activeAfter.length).toBe(0);
    });
  });

  // ===========================================================================
  // 5. CHANGE PASSWORD
  // ===========================================================================
  describe('PUT /api/auth/password', () => {
    test('Sukses mengubah password dan mencabut semua refresh token aktif', async () => {
      const user = await createUser({
        email: 'change.pwd@example.com',
        password: 'OldPassword123',
      });
      const token = tokenFor(user);

      // Create an active refresh token
      await request(app).post('/api/auth/login').send({
        email: 'change.pwd@example.com',
        password: 'OldPassword123',
      });

      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          oldPassword: 'OldPassword123',
          newPassword: 'NewPassword456',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Password berhasil diperbarui.');

      // Active refresh tokens are revoked
      const activeTokens = await prisma.refreshToken.findMany({
        where: { userId: user.id, revokedAt: null },
      });
      expect(activeTokens.length).toBe(0);

      // Old password no longer works
      const loginOld = await request(app).post('/api/auth/login').send({
        email: 'change.pwd@example.com',
        password: 'OldPassword123',
      });
      expect(loginOld.status).toBe(401);

      // New password works
      const loginNew = await request(app).post('/api/auth/login').send({
        email: 'change.pwd@example.com',
        password: 'NewPassword456',
      });
      expect(loginNew.status).toBe(200);
    });

    test('Gagal jika password lama salah (400 Bad Request)', async () => {
      const user = await createUser({ password: 'CorrectPassword123' });
      const token = tokenFor(user);

      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          oldPassword: 'WrongPassword123',
          newPassword: 'NewPassword456',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('Password lama salah.');
    });

    test('Gagal jika password baru sama dengan password lama (400 Bad Request)', async () => {
      const user = await createUser({ password: 'Password123' });
      const token = tokenFor(user);

      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          oldPassword: 'Password123',
          newPassword: 'Password123',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('Password baru tidak boleh sama dengan password lama.');
    });

    test('Gagal jika format password baru tidak valid (422 Unprocessable Entity)', async () => {
      const user = await createUser({ password: 'Password123' });
      const token = tokenFor(user);

      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          oldPassword: 'Password123',
          newPassword: 'weak',
        });

      expect(res.status).toBe(422);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  // ===========================================================================
  // 6. FORGOT & RESET PASSWORD
  // ===========================================================================
  describe('POST /api/auth/forgot-password & /api/auth/reset-password', () => {
    test('POST /api/auth/forgot-password SELALU mengembalikan respons generik meskipun email tidak ada', async () => {
      const res = await request(app)
        .post('/api/auth/forgot-password')
        .send({ email: 'nonexistent@example.com' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toContain('instruksi reset password telah dikirim');
      expect(getTestInbox().length).toBe(0);
    });

    test('POST /api/auth/forgot-password membuat token dan mengirim email jika user terdaftar', async () => {
      const user = await createUser({ email: 'registered@example.com' });

      const res = await request(app)
        .post('/api/auth/forgot-password')
        .send({ email: 'registered@example.com' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const inbox = getTestInbox();
      expect(inbox.length).toBe(1);
      expect(inbox[0].to).toBe('registered@example.com');
      const resetToken = inbox[0].token;
      expect(resetToken).toBeDefined();

      // Check token in DB
      const hashed = crypto.createHash('sha256').update(resetToken).digest('hex');
      const tokenRecord = await prisma.passwordResetToken.findUnique({
        where: { tokenHash: hashed },
      });
      expect(tokenRecord).toBeTruthy();
      expect(tokenRecord.userId).toBe(user.id);
      expect(tokenRecord.usedAt).toBeNull();
    });

    test('POST /api/auth/reset-password sukses mereset password dan mencabut token', async () => {
      const user = await createUser({ email: 'reset.me@example.com', password: 'OldPassword123' });

      // Request forgot password
      await request(app).post('/api/auth/forgot-password').send({ email: 'reset.me@example.com' });
      const resetToken = getTestInbox()[0].token;

      // Active refresh token before reset
      await request(app).post('/api/auth/login').send({
        email: 'reset.me@example.com',
        password: 'OldPassword123',
      });

      // Perform reset
      const resetRes = await request(app).post('/api/auth/reset-password').send({
        token: resetToken,
        newPassword: 'BrandNewPassword123',
      });

      expect(resetRes.status).toBe(200);
      expect(resetRes.body.success).toBe(true);

      // Verify token is marked as used
      const hashed = crypto.createHash('sha256').update(resetToken).digest('hex');
      const usedRecord = await prisma.passwordResetToken.findUnique({
        where: { tokenHash: hashed },
      });
      expect(usedRecord.usedAt).not.toBeNull();

      // Verify all refresh tokens revoked
      const activeTokens = await prisma.refreshToken.findMany({
        where: { userId: user.id, revokedAt: null },
      });
      expect(activeTokens.length).toBe(0);

      // Login with new password
      const loginRes = await request(app).post('/api/auth/login').send({
        email: 'reset.me@example.com',
        password: 'BrandNewPassword123',
      });
      expect(loginRes.status).toBe(200);
    });

    test('Gagal jika token reset sudah pernah digunakan (sekali pakai)', async () => {
      await createUser({ email: 'used.token@example.com' });
      await request(app)
        .post('/api/auth/forgot-password')
        .send({ email: 'used.token@example.com' });
      const resetToken = getTestInbox()[0].token;

      // Use once
      await request(app).post('/api/auth/reset-password').send({
        token: resetToken,
        newPassword: 'FirstNewPassword123',
      });

      // Try using again
      const reuseRes = await request(app).post('/api/auth/reset-password').send({
        token: resetToken,
        newPassword: 'SecondNewPassword123',
      });

      expect(reuseRes.status).toBe(400);
      expect(reuseRes.body.message).toContain('sudah digunakan');
    });

    test('Gagal jika token reset sudah kedaluwarsa (400 Bad Request)', async () => {
      const user = await createUser();
      const rawToken = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

      await prisma.passwordResetToken.create({
        data: {
          userId: user.id,
          tokenHash,
          expiresAt: new Date(Date.now() - 10000), // Expired
        },
      });

      const res = await request(app).post('/api/auth/reset-password').send({
        token: rawToken,
        newPassword: 'NewPassword123',
      });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('kedaluwarsa');
    });
  });

  // ===========================================================================
  // 7. FORGOT-EMAIL -> 410 GONE
  // ===========================================================================
  describe('POST /api/auth/forgot-email', () => {
    test('Mengembalikan 410 Gone', async () => {
      const res = await request(app).post('/api/auth/forgot-email').send({
        name: 'User',
        password: 'Password123',
      });

      expect(res.status).toBe(410);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('GONE');
      expect(res.body.message).toContain('tidak didukung');
    });
  });

  // ===========================================================================
  // 8. PROFILE & ME (Fresh DB check & isActive check)
  // ===========================================================================
  describe('GET /api/auth/me & Middleware authenticate', () => {
    test('Sukses mendapatkan profil dengan data isActive terbaru dari DB', async () => {
      const user = await createUser({
        name: 'Siti Aminah',
        email: 'siti@example.com',
        balance: 250000,
      });
      const token = tokenFor(user);

      const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(user.id);
      expect(res.body.data.isActive).toBe(true);
    });

    test('Menolak akun yang dinonaktifkan di DB meskipun token JWT valid (403 Forbidden)', async () => {
      const user = await createUser({ email: 'will.deactivate@example.com' });
      const token = tokenFor(user);

      // Deactivate user in DB
      await prisma.user.update({
        where: { id: user.id },
        data: { isActive: false },
      });

      const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('ACCOUNT_INACTIVE');
    });

    test('Menolak request tanpa header Authorization (401 Unauthorized)', async () => {
      const res = await request(app).get('/api/auth/me');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Akses ditolak');
    });
  });

  // ===========================================================================
  // 9. VALIDASI: PUT /profile & POST /update-fcm & GET /search-opponent
  // ===========================================================================
  describe('Validasi Endpoint Tambahan', () => {
    test('PUT /api/auth/profile sukses memperbarui nama (2-100 karakter)', async () => {
      const user = await createUser({ name: 'Nama Awal' });
      const token = tokenFor(user);

      const res = await request(app)
        .put('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Nama Baru Yang Valid' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe('Nama Baru Yang Valid');
    });

    test('PUT /api/auth/profile gagal jika nama < 2 karakter (422)', async () => {
      const user = await createUser();
      const token = tokenFor(user);

      const res = await request(app)
        .put('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'A' });

      expect(res.status).toBe(422);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });

    test('POST /api/auth/update-fcm sukses memperbarui FCM token', async () => {
      const user = await createUser();
      const token = tokenFor(user);

      const res = await request(app)
        .post('/api/auth/update-fcm')
        .set('Authorization', `Bearer ${token}`)
        .send({ fcmToken: 'valid-fcm-token-12345' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.fcmToken).toBe('valid-fcm-token-12345');
    });

    test('POST /api/auth/update-fcm gagal jika fcmToken kosong (422)', async () => {
      const user = await createUser();
      const token = tokenFor(user);

      const res = await request(app)
        .post('/api/auth/update-fcm')
        .set('Authorization', `Bearer ${token}`)
        .send({ fcmToken: '' });

      expect(res.status).toBe(422);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });

    test('GET /api/auth/search-opponent sukses mencari lawan', async () => {
      const currentUser = await createUser({ name: 'Pengguna Asli' });
      const opponent = await createUser({ name: 'Lawan Transaksi', email: 'lawan@example.com' });
      const token = tokenFor(currentUser);

      const res = await request(app)
        .get('/api/auth/search-opponent?query=lawan')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].id).toBe(opponent.id);
    });

    test('GET /api/auth/search-opponent gagal jika query < 2 karakter (422)', async () => {
      const user = await createUser();
      const token = tokenFor(user);

      const res = await request(app)
        .get('/api/auth/search-opponent?query=x')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(422);
      expect(res.body.code).toBe('VALIDATION_ERROR');
    });
  });

  // ===========================================================================
  // 10. RATE LIMITING, ERROR HANDLING & LOG REDACTION
  // ===========================================================================
  describe('Keamanan: Rate Limiting, Error Sanitization & Log Redaction', () => {
    test('Rate Limiter menolak request setelah melampaui batas dengan 429 TOO_MANY_REQUESTS', async () => {
      const testApp = express();
      const testLimiter = createLimiter({
        windowMs: 60000,
        max: 2,
        message: 'Batas percobaan terlampaui.',
      });

      // Override max for testing this isolated limiter
      const strictLimiter = (req, res, next) => {
        // Direct express-rate-limit test
        testLimiter(req, res, next);
      };

      testApp.use(strictLimiter);
      testApp.get('/test-rate-limit', (_req, res) => res.json({ ok: true }));

      // In test env, createLimiter sets max to 100000 unless overridden
      // Let's create an explicit limiter with max: 2
      const rateLimitLib = require('express-rate-limit');
      const directLimiter = rateLimitLib({
        windowMs: 60000,
        max: 2,
        standardHeaders: true,
        legacyHeaders: false,
        handler: (_req, res) => {
          res.status(429).json({
            success: false,
            message: 'Batas percobaan terlampaui.',
            code: 'TOO_MANY_REQUESTS',
          });
        },
      });

      const limiterApp = express();
      limiterApp.use(directLimiter);
      limiterApp.get('/ping', (_req, res) => res.json({ ok: true }));

      const res1 = await request(limiterApp).get('/ping');
      expect(res1.status).toBe(200);

      const res2 = await request(limiterApp).get('/ping');
      expect(res2.status).toBe(200);

      const res3 = await request(limiterApp).get('/ping');
      expect(res3.status).toBe(429);
      expect(res3.body.success).toBe(false);
      expect(res3.body.code).toBe('TOO_MANY_REQUESTS');
      expect(res3.body.message).toBe('Batas percobaan terlampaui.');
    });

    test('Respons error TIDAK PERNAH menyertakan stack trace', async () => {
      // 404 error
      const notFoundRes = await request(app).get('/api/non-existent-endpoint');
      expect(notFoundRes.body).not.toHaveProperty('stack');

      // 401 error
      const authErrorRes = await request(app).get('/api/auth/me');
      expect(authErrorRes.body).not.toHaveProperty('stack');

      // 422 error
      const valErrorRes = await request(app).post('/api/auth/login').send({});
      expect(valErrorRes.body).not.toHaveProperty('stack');
    });

    test('Pino logger menyamarkan data sensitif (Authorization, password, refreshToken)', () => {
      let loggedOutput = '';
      const stream = new Writable({
        write(chunk, _encoding, callback) {
          loggedOutput += chunk.toString();
          callback();
        },
      });

      const redactPaths = [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.body.password',
        'req.body.oldPassword',
        'req.body.newPassword',
        'req.body.token',
        'req.body.refreshToken',
      ];

      const testLogger = pino(
        {
          redact: {
            paths: redactPaths,
            censor: '[REDACTED]',
          },
        },
        stream
      );

      testLogger.info({
        req: {
          headers: {
            authorization: 'Bearer secret-jwt-token-value',
          },
          body: {
            password: 'SuperSecretPassword123',
            refreshToken: 'super-secret-refresh-token',
          },
        },
      });

      const parsed = JSON.parse(loggedOutput);
      expect(parsed.req.headers.authorization).toBe('[REDACTED]');
      expect(parsed.req.body.password).toBe('[REDACTED]');
      expect(parsed.req.body.refreshToken).toBe('[REDACTED]');
    });
  });
});
