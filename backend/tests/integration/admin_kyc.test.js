// =============================================================================
// Integration Tests: KYC, Admin APIs & Audit Logging (Prompt 14)
// =============================================================================

const request = require('supertest');
const app = require('../../src/app');
const prisma = require('../../src/config/prisma');
const {
  createUser,
  tokenFor,
  createTransaction,
  createDispute,
  resetDb,
  disconnectDb,
} = require('../helpers');
const { encrypt, decrypt } = require('../../src/utils/encryption');

describe('KYC, Admin APIs & Audit Logging (Prompt 14)', () => {
  let adminUser;
  let normalUser;
  let sellerUser;
  let adminToken;
  let userToken;
  let sellerToken;

  beforeAll(async () => {
    // Setup
  });

  afterAll(async () => {
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();

    adminUser = await createUser({
      name: 'Admin Platform',
      email: 'admin@rekber.com',
      role: 'ADMIN',
      kycStatus: 'APPROVED',
    });

    normalUser = await createUser({
      name: 'Budi Pembeli',
      email: 'budi@test.com',
      role: 'USER',
      balance: 500000n,
      kycStatus: 'NONE',
    });

    sellerUser = await createUser({
      name: 'Siti Penjual',
      email: 'siti@test.com',
      role: 'USER',
      balance: 100000n,
      kycStatus: 'APPROVED',
    });

    adminToken = tokenFor(adminUser);
    userToken = tokenFor(normalUser);
    sellerToken = tokenFor(sellerUser);
  });

  // Helper to create valid KYC files
  const createKycFiles = async (ownerId) => {
    const idFile = await prisma.fileAsset.create({
      data: {
        ownerId,
        purpose: 'KYC_ID',
        storageKey: `kyc/id_${ownerId}.jpg`,
        mime: 'image/jpeg',
        size: 50000,
        sha256: 'hash_ktp_test_123',
      },
    });

    const selfieFile = await prisma.fileAsset.create({
      data: {
        ownerId,
        purpose: 'KYC_SELFIE',
        storageKey: `kyc/selfie_${ownerId}.jpg`,
        mime: 'image/jpeg',
        size: 60000,
        sha256: 'hash_selfie_test_123',
      },
    });

    return { idFile, selfieFile };
  };

  // ===========================================================================
  // 1. ENDPOINT PROTECTION: 401 TANPA TOKEN & 403 UNTUK USER
  // ===========================================================================
  describe('1. Proteksi Endpoint Admin (401 & 403)', () => {
    const adminEndpoints = [
      { method: 'get', path: '/api/admin/metrics' },
      { method: 'get', path: '/api/admin/users' },
      { method: 'get', path: '/api/admin/kyc' },
      { method: 'get', path: '/api/admin/settings' },
      { method: 'get', path: '/api/admin/transactions' },
      { method: 'get', path: '/api/admin/audit-logs' },
    ];

    for (const ep of adminEndpoints) {
      it(`${ep.method.toUpperCase()} ${ep.path} menghasilkan 401 tanpa token`, async () => {
        const res = await request(app)[ep.method](ep.path);
        expect(res.status).toBe(401);
      });

      it(`${ep.method.toUpperCase()} ${ep.path} menghasilkan 403 untuk USER biasa`, async () => {
        const res = await request(app)
          [ep.method](ep.path)
          .set('Authorization', `Bearer ${userToken}`);
        expect(res.status).toBe(403);
      });
    }
  });

  // ===========================================================================
  // 2. WORKFLOW KYC: SUBMIT, ENCRYPT, RESUBMIT, APPROVE, REJECT
  // ===========================================================================
  describe('2. Alur Pengajuan KYC & Verifikasi Admin', () => {
    it('Pengguna dapat mengajukan KYC, NIK terenkripsi di DB dan tersamarkan di respons', async () => {
      const { idFile, selfieFile } = await createKycFiles(normalUser.id);
      const rawNik = '3171012345670001';

      const submitRes = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Pembeli Santoso',
          nik: rawNik,
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });

      expect(submitRes.status).toBe(201);
      expect(submitRes.body.success).toBe(true);
      expect(submitRes.body.data.nikMasked).toBe('3171********0001');
      expect(submitRes.body.data.status).toBe('PENDING');

      // Verifikasi di database: NIK terenkripsi (bukan plaintext dan dapat didekripsi)
      const submissionInDb = await prisma.kycSubmission.findUnique({
        where: { id: submitRes.body.data.id },
      });
      expect(submissionInDb.nikEnc).not.toBe(rawNik);
      expect(submissionInDb.nikEnc).toContain(':');
      expect(decrypt(submissionInDb.nikEnc)).toBe(rawNik);

      // Verifikasi status user diperbarui menjadi PENDING
      const userInDb = await prisma.user.findUnique({ where: { id: normalUser.id } });
      expect(userInDb.kycStatus).toBe('PENDING');

      // Cek GET /api/kyc/me
      const meRes = await request(app)
        .get('/api/kyc/me')
        .set('Authorization', `Bearer ${userToken}`);
      expect(meRes.status).toBe(200);
      expect(meRes.body.data.kycStatus).toBe('PENDING');
      expect(meRes.body.data.submission.nikMasked).toBe('3171********0001');
    });

    it('Pengguna ditolak mengajukan ulang saat status masih PENDING atau APPROVED', async () => {
      const { idFile, selfieFile } = await createKycFiles(normalUser.id);
      await request(app).post('/api/kyc').set('Authorization', `Bearer ${userToken}`).send({
        fullName: 'Budi Santoso',
        nik: '3171012345670001',
        idFileId: idFile.id,
        selfieFileId: selfieFile.id,
      });

      // Submit ulang saat PENDING -> ditolak (400)
      const resPending = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Santoso',
          nik: '3171012345670001',
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });
      expect(resPending.status).toBe(400);
      expect(resPending.body.message).toContain('sedang ditinjau');

      // Ubah status jadi APPROVED -> ditolak (400)
      await prisma.user.update({
        where: { id: normalUser.id },
        data: { kycStatus: 'APPROVED' },
      });

      const resApproved = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Santoso',
          nik: '3171012345670001',
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });
      expect(resApproved.status).toBe(400);
      expect(resApproved.body.message).toContain('sudah terverifikasi');
    });

    it('Admin dapat meninjau (GET /admin/kyc/:id) dan menyetujui (APPROVE) KYC', async () => {
      const { idFile, selfieFile } = await createKycFiles(normalUser.id);
      const submitRes = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Santoso',
          nik: '3171012345670001',
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });

      const submissionId = submitRes.body.data.id;

      // Admin melihat detail submission
      const detailRes = await request(app)
        .get(`/api/admin/kyc/${submissionId}`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(detailRes.status).toBe(200);
      expect(detailRes.body.data.nikMasked).toBe('3171********0001');

      // Admin menyetujui KYC
      const approveRes = await request(app)
        .post(`/api/admin/kyc/${submissionId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(approveRes.status).toBe(200);
      expect(approveRes.body.success).toBe(true);
      expect(approveRes.body.data.status).toBe('APPROVED');

      // User kycStatus menjadi APPROVED
      const updatedUser = await prisma.user.findUnique({ where: { id: normalUser.id } });
      expect(updatedUser.kycStatus).toBe('APPROVED');

      // Audit log tercatat
      const audit = await prisma.auditLog.findFirst({
        where: { action: 'KYC_APPROVE', targetId: submissionId },
      });
      expect(audit).not.toBeNull();
      expect(audit.actorId).toBe(adminUser.id);
    });

    it('Admin dapat menolak (REJECT) KYC dan pengguna dapat mengajukan ulang', async () => {
      const { idFile, selfieFile } = await createKycFiles(normalUser.id);
      const submitRes = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Santoso',
          nik: '3171012345670001',
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });

      const submissionId = submitRes.body.data.id;

      // Admin menolak dengan alasan foto KTP buram
      const rejectRes = await request(app)
        .post(`/api/admin/kyc/${submissionId}/reject`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Foto KTP terlalu buram dan tidak terbaca jelas' });

      expect(rejectRes.status).toBe(200);
      expect(rejectRes.body.data.status).toBe('REJECTED');

      const userAfterReject = await prisma.user.findUnique({ where: { id: normalUser.id } });
      expect(userAfterReject.kycStatus).toBe('REJECTED');

      // Pengguna kini DIIZINKAN mengajukan ulang karena statusnya REJECTED
      const resubmitRes = await request(app)
        .post('/api/kyc')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          fullName: 'Budi Santoso',
          nik: '3171012345670001',
          idFileId: idFile.id,
          selfieFileId: selfieFile.id,
        });

      expect(resubmitRes.status).toBe(201);
      expect(resubmitRes.body.data.status).toBe('PENDING');
    });
  });

  // ===========================================================================
  // 3. PENARIKAN TANPA KYC DITOLAK
  // ===========================================================================
  describe('3. Syarat KYC pada Penarikan Dana (Prompt 9 Assertion Update)', () => {
    it('Pengguna dengan kycStatus !== APPROVED ditolak melakukan penarikan (403)', async () => {
      // Buat rekening bank untuk normalUser (kycStatus: NONE)
      const bankAccount = await prisma.bankAccount.create({
        data: {
          userId: normalUser.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Budi Santoso',
        },
      });

      const withdrawRes = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${userToken}`)
        .set('Idempotency-Key', 'wd-kyc-check-001')
        .send({
          bankAccountId: bankAccount.id,
          amount: 100000,
        });

      expect(withdrawRes.status).toBe(403);
      expect(withdrawRes.body.message).toContain('terverifikasi KYC (APPROVED)');
    });

    it('Pengguna dengan kycStatus === APPROVED diizinkan melakukan penarikan', async () => {
      const bankAccount = await prisma.bankAccount.create({
        data: {
          userId: sellerUser.id,
          bankCode: 'MANDIRI',
          accountNumberEnc: encrypt('0987654321'),
          accountLast4: '4321',
          accountName: 'Siti Penjual',
        },
      });

      const withdrawRes = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${sellerToken}`)
        .set('Idempotency-Key', 'wd-kyc-check-002')
        .send({
          bankAccountId: bankAccount.id,
          amount: 50000,
        });

      expect(withdrawRes.status).toBe(201);
      expect(withdrawRes.body.success).toBe(true);
      expect(withdrawRes.body.data.status).toBe('PENDING_REVIEW');
    });
  });

  // ===========================================================================
  // 4. MANAJEMEN USER & PEMBLOKIRAN (BAN / UNBAN)
  // ===========================================================================
  describe('4. Pemblokiran Akun User (Ban & Unban)', () => {
    it('Admin dapat memblokir user: isActive false, refresh token dicabut, dan audit tercatat', async () => {
      // Simulasikan user memiliki refresh token aktif
      await prisma.refreshToken.create({
        data: {
          userId: normalUser.id,
          tokenHash: 'dummy_hash_token_user_1',
          expiresAt: new Date(Date.now() + 86400000),
        },
      });

      const banRes = await request(app)
        .post(`/api/admin/users/${normalUser.id}/ban`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Terlibat indikasi penipuan' });

      expect(banRes.status).toBe(200);
      expect(banRes.body.data.isActive).toBe(false);

      // Verifikasi isActive di DB
      const userInDb = await prisma.user.findUnique({ where: { id: normalUser.id } });
      expect(userInDb.isActive).toBe(false);

      // Verifikasi refresh token dicabut
      const revokedTokens = await prisma.refreshToken.findMany({
        where: { userId: normalUser.id, revokedAt: { not: null } },
      });
      expect(revokedTokens.length).toBe(1);

      // Verifikasi audit log
      const audit = await prisma.auditLog.findFirst({
        where: { action: 'USER_BAN', targetId: normalUser.id },
      });
      expect(audit).not.toBeNull();
      expect(audit.after.reason).toBe('Terlibat indikasi penipuan');
    });

    it('Admin ditolak memblokir akun diri sendiri atau sesama admin (400)', async () => {
      // Ban diri sendiri
      const banSelf = await request(app)
        .post(`/api/admin/users/${adminUser.id}/ban`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Iseng ban diri sendiri' });

      expect(banSelf.status).toBe(400);
      expect(banSelf.body.message).toContain('Anda sendiri');

      // Ban sesama admin
      const otherAdmin = await createUser({
        name: 'Admin Dua',
        email: 'admin2@rekber.com',
        role: 'ADMIN',
      });

      const banOtherAdmin = await request(app)
        .post(`/api/admin/users/${otherAdmin.id}/ban`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Konflik internal' });

      expect(banOtherAdmin.status).toBe(400);
      expect(banOtherAdmin.body.message).toContain('sesama administrator');
    });

    it('Admin dapat membuka pemblokiran akun user (unban)', async () => {
      await prisma.user.update({
        where: { id: normalUser.id },
        data: { isActive: false },
      });

      const unbanRes = await request(app)
        .post(`/api/admin/users/${normalUser.id}/unban`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(unbanRes.status).toBe(200);
      expect(unbanRes.body.data.isActive).toBe(true);

      const audit = await prisma.auditLog.findFirst({
        where: { action: 'USER_UNBAN', targetId: normalUser.id },
      });
      expect(audit).not.toBeNull();
    });
  });

  // ===========================================================================
  // 5. PENGATURAN PLATFORM (SETTINGS)
  // ===========================================================================
  describe('5. Pengaturan Platform (Platform Settings)', () => {
    it('Admin dapat membaca GET /admin/settings', async () => {
      const res = await request(app)
        .get('/api/admin/settings')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.fee_percent).toBeDefined();
      expect(res.body.data.withdraw_min).toBeDefined();
    });

    it('PUT /admin/settings: Menolak key yang tidak dikenal atau nilai di luar rentang', async () => {
      // Key liar tidak diizinkan
      const resInvalidKey = await request(app)
        .put('/api/admin/settings')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ key: 'unknown_fake_key', value: '123' });

      expect(resInvalidKey.status).toBe(400);

      // fee_percent di luar rentang (misal 99%)
      const resInvalidRange = await request(app)
        .put('/api/admin/settings')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ key: 'fee_percent', value: '99' });

      expect(resInvalidRange.status).toBe(422);
    });

    it('PUT /admin/settings: Mengupdate setting valid dan mencatat audit log', async () => {
      const updateRes = await request(app)
        .put('/api/admin/settings')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ key: 'auto_release_hours', value: '48' });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.data.auto_release_hours).toBe('48');

      // Audit log tercatat
      const audit = await prisma.auditLog.findFirst({
        where: { action: 'SETTING_UPDATE', targetId: 'auto_release_hours' },
      });
      expect(audit).not.toBeNull();
      expect(audit.after.value).toBe('48');
    });
  });

  // ===========================================================================
  // 6. METRIK ANALITIK & TRANSAKSI ADMIN
  // ===========================================================================
  describe('6. Metrik Platform (GET /admin/metrics) & Transaksi (GET /admin/transactions)', () => {
    it('Metrik platform cocok dengan data fixture yang ada', async () => {
      // Buat 1 transaksi COMPLETED bernilai Rp 200.000 dengan fee Rp 4.000
      await createTransaction({
        buyerId: normalUser.id,
        sellerId: sellerUser.id,
        amount: 200000,
        buyerFee: 2000,
        sellerFee: 2000,
        status: 'COMPLETED',
      });

      // Buat 1 sengketa OPEN
      const disputedTx = await createTransaction({
        buyerId: normalUser.id,
        sellerId: sellerUser.id,
        amount: 100000,
        status: 'DISPUTED',
      });
      await createDispute({
        transactionId: disputedTx.id,
        openedById: normalUser.id,
        status: 'OPEN',
      });

      // Buat 1 penarikan PENDING_REVIEW
      const bank = await prisma.bankAccount.create({
        data: {
          userId: sellerUser.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1122334455'),
          accountLast4: '4455',
          accountName: 'Siti Penjual',
        },
      });
      await prisma.withdrawalRequest.create({
        data: {
          userId: sellerUser.id,
          bankAccountId: bank.id,
          amount: 50000n,
          status: 'PENDING_REVIEW',
        },
      });

      const metricsRes = await request(app)
        .get('/api/admin/metrics')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(metricsRes.status).toBe(200);
      const metrics = metricsRes.body.data;
      expect(metrics.gmv).toBe(200000);
      expect(metrics.platformFeeRevenue).toBe(4000);
      expect(metrics.openDisputes).toBeGreaterThanOrEqual(1);
      expect(metrics.pendingWithdrawals).toBeGreaterThanOrEqual(1);
      expect(metrics.transactionsByStatus.COMPLETED).toBeGreaterThanOrEqual(1);
      expect(metrics.transactionsByStatus.DISPUTED).toBeGreaterThanOrEqual(1);
    });

    it('GET /admin/transactions mendukung filter status dan user', async () => {
      const res = await request(app)
        .get(`/api/admin/transactions?userId=${normalUser.id}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });
  });

  // ===========================================================================
  // 7. AUDIT LOGS INQUIRY (GET /admin/audit-logs)
  // ===========================================================================
  describe('7. Riwayat Audit Log (GET /admin/audit-logs)', () => {
    it('Admin dapat melihat dan memfilter riwayat audit log berdasarkan action', async () => {
      // Pastikan ada audit log
      await prisma.auditLog.create({
        data: {
          actorId: adminUser.id,
          action: 'TEST_AUDIT_ACTION',
          targetType: 'SYSTEM',
          targetId: 'sys-001',
          before: { state: 'old' },
          after: { state: 'new' },
        },
      });

      const res = await request(app)
        .get('/api/admin/audit-logs?action=TEST_AUDIT_ACTION')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data[0].action).toBe('TEST_AUDIT_ACTION');
      expect(res.body.data[0].actor.email).toBe(adminUser.email);
    });
  });
});
