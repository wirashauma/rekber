// =============================================================================
// Integration Tests: Bank Accounts, Withdrawals & Payout System (Prompt 9)
// =============================================================================

const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, resetDb, disconnectDb } = require('../helpers');
const { encrypt, decrypt } = require('../../src/utils/encryption');
const { getPaymentProvider } = require('../../src/providers/payment');

describe('Bank Accounts, Withdrawals & Payout System (Prompt 9)', () => {
  let app;
  let user1;
  let user2;
  let admin;
  let token1;
  let token2;
  let adminToken;
  const fakeProvider = getPaymentProvider('fake');

  beforeAll(async () => {
    app = createApp();
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();

    // Default platform settings
    await prisma.platformSetting.createMany({
      data: [
        { key: 'withdraw_min', value: '50000' },
        { key: 'withdraw_fee', value: '4500' },
        { key: 'withdraw_daily_limit', value: '10000000' },
      ],
      skipDuplicates: true,
    });

    user1 = await createUser({
      name: 'Budi Santoso',
      email: 'budi@example.com',
      role: 'USER',
      balance: 500000n, // Rp 500.000
    });

    user2 = await createUser({
      name: 'Siti Aminah',
      email: 'siti@example.com',
      role: 'USER',
      balance: 100000n, // Rp 100.000
    });

    admin = await createUser({
      name: 'Super Admin',
      email: 'admin@example.com',
      role: 'ADMIN',
      balance: 0n,
    });

    token1 = tokenFor(user1);
    token2 = tokenFor(user2);
    adminToken = tokenFor(admin);
  });

  // ===========================================================================
  // 1. REKENING BANK (BANK ACCOUNT)
  // ===========================================================================
  describe('1. Pengelolaan Rekening Bank (/bank-accounts)', () => {
    test('Berhasil menambahkan rekening bank baru dengan nomor terenkripsi dan nomor tersamarkan', async () => {
      const res = await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          bankCode: 'BCA',
          accountNumber: '1234567890',
          accountName: 'Budi Santoso',
          isDefault: true,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.bankCode).toBe('BCA');
      expect(res.body.data.accountLast4).toBe('7890');
      expect(res.body.data.accountNumberMasked).toBe('••••••7890');
      // Respons tidak boleh memuat nomor plaintext lengkap
      expect(res.body.data).not.toHaveProperty('accountNumber');
      expect(res.body.data).not.toHaveProperty('accountNumberEnc');

      // Verifikasi di database: tersimpan sebagai ciphertext terenkripsi
      const dbAccount = await prisma.bankAccount.findUnique({
        where: { id: res.body.data.id },
      });
      expect(dbAccount.accountNumberEnc).toBeDefined();
      expect(dbAccount.accountNumberEnc).not.toBe('1234567890');
      expect(decrypt(dbAccount.accountNumberEnc)).toBe('1234567890');
    });

    test('Menolak penambahan rekening dengan kode bank yang tidak terdaftar (422)', async () => {
      const res = await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          bankCode: 'BANK_GHAIB',
          accountNumber: '1234567890',
          accountName: 'Budi Santoso',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].message).toMatch(/kode bank tidak didukung/i);
    });

    test('Maksimum 3 rekening aktif per pengguna; penambahan ke-4 ditolak (400)', async () => {
      // Tambah 3 rekening
      await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'BCA', accountNumber: '1111111111', accountName: 'Budi Satu' });
      await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'BNI', accountNumber: '2222222222', accountName: 'Budi Dua' });
      await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'BRI', accountNumber: '3333333333', accountName: 'Budi Tiga' });

      // Coba tambah rekening ke-4
      const res4 = await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'MANDIRI', accountNumber: '4444444444', accountName: 'Budi Empat' });

      expect(res4.status).toBe(400);
      expect(res4.body.success).toBe(false);
      expect(res4.body.message).toMatch(/maksimal 3 rekening bank aktif/i);
    });

    test('Soft delete rekening bank; setelah dihapus tidak muncul di GET dan slot terbuka kembali', async () => {
      const createRes = await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'BCA', accountNumber: '1234567890', accountName: 'Budi Santoso' });
      const accountId = createRes.body.data.id;

      // Hapus rekening
      const delRes = await request(app)
        .delete(`/api/bank-accounts/${accountId}`)
        .set('Authorization', `Bearer ${token1}`);

      expect(delRes.status).toBe(200);
      expect(delRes.body.success).toBe(true);

      // Verifikasi di DB: deletedAt terisi
      const inDb = await prisma.bankAccount.findUnique({ where: { id: accountId } });
      expect(inDb.deletedAt).not.toBeNull();

      // List rekening user1 sekarang kosong
      const listRes = await request(app)
        .get('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`);
      expect(listRes.body.data).toHaveLength(0);
    });

    test('IDOR Protection: Pengguna tidak dapat menghapus rekening milik orang lain (404)', async () => {
      const createRes = await request(app)
        .post('/api/bank-accounts')
        .set('Authorization', `Bearer ${token1}`)
        .send({ bankCode: 'BCA', accountNumber: '1234567890', accountName: 'Budi Santoso' });

      const res = await request(app)
        .delete(`/api/bank-accounts/${createRes.body.data.id}`)
        .set('Authorization', `Bearer ${token2}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toMatch(/tidak ditemukan/i);
    });
  });

  // ===========================================================================
  // 2. PENARIKAN DANA USER (POST /wallet/withdrawals)
  // ===========================================================================
  describe('2. Inisiasi Penarikan Dana Pengguna (/wallet/withdrawals)', () => {
    let bankAccount1;

    beforeEach(async () => {
      bankAccount1 = await prisma.bankAccount.create({
        data: {
          userId: user1.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Budi Santoso',
          isDefault: true,
        },
      });
    });

    test('Wajib menyertakan header Idempotency-Key (422)', async () => {
      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          bankAccountId: bankAccount1.id,
          amount: 100000,
        });

      expect(res.status).toBe(422);
      expect(res.body.errors[0].message).toMatch(/header idempotency-key wajib/i);
    });

    test('Menolak penarikan di bawah batas minimum withdraw_min (400)', async () => {
      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', 'test-key-min-001')
        .send({
          bankAccountId: bankAccount1.id,
          amount: 40000, // min adalah 50.000
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/minimal Rp 50\.000/i);
    });

    test('Menolak penarikan bila saldo tidak cukup untuk nominal + biaya penarikan (400)', async () => {
      // Saldo user2 = 100.000, coba tarik 100.000 (total butuh 104.500)
      const user2Bank = await prisma.bankAccount.create({
        data: {
          userId: user2.id,
          bankCode: 'BRI',
          accountNumberEnc: encrypt('9999888877'),
          accountLast4: '8877',
          accountName: 'Siti Aminah',
        },
      });

      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token2}`)
        .set('Idempotency-Key', 'test-key-insufficient-001')
        .send({
          bankAccountId: user2Bank.id,
          amount: 100000,
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/saldo tidak mencukupi/i);
    });

    test('Penarikan sukses: status PENDING_REVIEW dan saldo terpotong seketika (WITHDRAWAL_RESERVE)', async () => {
      const initialUser = await prisma.user.findUnique({ where: { id: user1.id } });
      const initialBalance = initialUser.balance; // 500.000n

      const withdrawAmount = 100000;
      const withdrawFee = 4500;
      const totalDebit = BigInt(withdrawAmount + withdrawFee);

      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', 'test-key-success-001')
        .send({
          bankAccountId: bankAccount1.id,
          amount: withdrawAmount,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('PENDING_REVIEW');
      expect(res.body.data.amount).toBe(withdrawAmount);
      expect(res.body.data.fee).toBe(withdrawFee);

      // Verifikasi saldo user terpotong seketika
      const updatedUser = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(updatedUser.balance).toBe(initialBalance - totalDebit);

      // Verifikasi tercatat di LedgerEntry dengan tipe WITHDRAWAL_RESERVE
      const ledger = await prisma.ledgerEntry.findFirst({
        where: {
          userId: user1.id,
          type: 'WITHDRAWAL_RESERVE',
          referenceId: res.body.data.id,
        },
      });
      expect(ledger).not.toBeNull();
      expect(ledger.amount).toBe(totalDebit);
      expect(ledger.direction).toBe('DEBIT');
      expect(ledger.balanceAfter).toBe(updatedUser.balance);
    });

    test('Replay Idempotency-Key: mengembalikan record yang ada tanpa mendebit saldo dua kali', async () => {
      const key = 'test-key-replay-001';
      const initialUser = await prisma.user.findUnique({ where: { id: user1.id } });

      const res1 = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', key)
        .send({ bankAccountId: bankAccount1.id, amount: 100000 });

      const res2 = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', key)
        .send({ bankAccountId: bankAccount1.id, amount: 100000 });

      expect(res1.status).toBe(201);
      expect(res2.status).toBe(201);
      expect(res1.body.data.id).toBe(res2.body.data.id);

      // Saldo hanya terpotong tepat sekali (104.500)
      const finalUser = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(finalUser.balance).toBe(initialUser.balance - 104500n);
    });
  });

  // ===========================================================================
  // 3. KONKURENSI: 5 PENARIKAN PARALEL MELEBIHI SALDO
  // ===========================================================================
  describe('3. Konkurensi: 5 Penarikan Paralel Melebihi Saldo', () => {
    test('Pengguna bersaldo cukup untuk 1 penarikan melakukan 5 penarikan paralel: tepat 1 berhasil', async () => {
      // Siapkan user dengan saldo tepat untuk 1 penarikan: 100.000 + 4.500 = 104.500
      const tightUser = await createUser({
        name: 'Tight Balance User',
        email: 'tight@example.com',
        role: 'USER',
        balance: 104500n,
      });
      const tightToken = tokenFor(tightUser);
      const bank = await prisma.bankAccount.create({
        data: {
          userId: tightUser.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1122334455'),
          accountLast4: '4455',
          accountName: 'Tight Balance User',
        },
      });

      // Luncurkan 5 permintaan paralel secara simultan dengan idempotency-key berbeda
      const requests = Array.from({ length: 5 }, (_, i) =>
        request(app)
          .post('/api/wallet/withdrawals')
          .set('Authorization', `Bearer ${tightToken}`)
          .set('Idempotency-Key', `tight-parallel-key-${i}`)
          .send({ bankAccountId: bank.id, amount: 100000 })
      );

      const responses = await Promise.all(requests);

      const successes = responses.filter((r) => r.status === 201);
      const rejections = responses.filter((r) => r.status === 400);

      // Tepat 1 berhasil, 4 ditolak
      expect(successes).toHaveLength(1);
      expect(rejections).toHaveLength(4);

      // Saldo akhir harus tepat 0, tidak boleh negatif
      const afterUser = await prisma.user.findUnique({ where: { id: tightUser.id } });
      expect(afterUser.balance).toBe(0n);
    });
  });

  // ===========================================================================
  // 4. BATALKAN PENARIKAN (CANCEL) OLEH USER
  // ===========================================================================
  describe('4. Pembatalan Penarikan oleh Pengguna (/wallet/withdrawals/:id/cancel)', () => {
    let bankAccount;
    let withdrawal;

    beforeEach(async () => {
      bankAccount = await prisma.bankAccount.create({
        data: {
          userId: user1.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Budi Santoso',
        },
      });

      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', 'test-cancel-init')
        .send({ bankAccountId: bankAccount.id, amount: 100000 });

      withdrawal = res.body.data;
    });

    test('Pengguna berhasil membatalkan penarikan PENDING_REVIEW; dana dikembalikan penuh (WITHDRAWAL_RELEASE)', async () => {
      const balanceBeforeCancel = (await prisma.user.findUnique({ where: { id: user1.id } }))
        .balance;

      const res = await request(app)
        .post(`/api/wallet/withdrawals/${withdrawal.id}/cancel`)
        .set('Authorization', `Bearer ${token1}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Saldo dikembalikan penuh (100.000 + 4.500)
      const balanceAfterCancel = (await prisma.user.findUnique({ where: { id: user1.id } }))
        .balance;
      expect(balanceAfterCancel).toBe(balanceBeforeCancel + 104500n);

      // Verifikasi LedgerEntry WITHDRAWAL_RELEASE
      const releaseLedger = await prisma.ledgerEntry.findFirst({
        where: {
          userId: user1.id,
          type: 'WITHDRAWAL_RELEASE',
          referenceId: withdrawal.id,
        },
      });
      expect(releaseLedger).not.toBeNull();
      expect(releaseLedger.direction).toBe('CREDIT');
      expect(releaseLedger.amount).toBe(104500n);
    });

    test('Tidak dapat membatalkan penarikan milik pengguna lain (404)', async () => {
      const res = await request(app)
        .post(`/api/wallet/withdrawals/${withdrawal.id}/cancel`)
        .set('Authorization', `Bearer ${token2}`);

      expect(res.status).toBe(404);
    });
  });

  // ===========================================================================
  // 5. REVIEW & TINDAKAN ADMIN (/admin/withdrawals)
  // ===========================================================================
  describe('5. Peninjauan & Aksi Admin (/admin/withdrawals)', () => {
    let bankAccount;
    let withdrawal;

    beforeEach(async () => {
      bankAccount = await prisma.bankAccount.create({
        data: {
          userId: user1.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Budi Santoso',
        },
      });

      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', 'test-admin-init')
        .send({ bankAccountId: bankAccount.id, amount: 100000 });

      withdrawal = res.body.data;
    });

    test('User non-admin dilarang mengakses rute admin (403 Forbidden)', async () => {
      const res = await request(app)
        .get('/api/admin/withdrawals')
        .set('Authorization', `Bearer ${token1}`);

      expect(res.status).toBe(403);
    });

    test('Admin melihat daftar penarikan lengkap dengan kalkulasi nameMatch', async () => {
      const res = await request(app)
        .get('/api/admin/withdrawals?status=PENDING_REVIEW')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.items).toBeInstanceOf(Array);
      expect(res.body.data.items.length).toBeGreaterThanOrEqual(1);

      const item = res.body.data.items.find((i) => i.id === withdrawal.id);
      expect(item).toBeDefined();
      expect(item.nameMatch.score).toBeGreaterThanOrEqual(0.9); // Nama 'Budi Santoso' sama persis
      expect(item.nameMatch.confidence).toBe('HIGH');
      expect(item.bankAccount.accountNumberMasked).toBe('••••••7890');
    });

    test('Admin menolak penarikan (reject): status REJECTED dan dana dikembalikan (WITHDRAWAL_RELEASE)', async () => {
      const balanceBefore = (await prisma.user.findUnique({ where: { id: user1.id } })).balance;

      const res = await request(app)
        .post(`/api/admin/withdrawals/${withdrawal.id}/reject`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Nama rekening terindikasi mencurigakan.' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const dbWithdrawal = await prisma.withdrawalRequest.findUnique({
        where: { id: withdrawal.id },
      });
      expect(dbWithdrawal.status).toBe('REJECTED');
      expect(dbWithdrawal.failureReason).toBe('Nama rekening terindikasi mencurigakan.');
      expect(dbWithdrawal.reviewedById).toBe(admin.id);

      // Saldo dikembalikan
      const balanceAfter = (await prisma.user.findUnique({ where: { id: user1.id } })).balance;
      expect(balanceAfter).toBe(balanceBefore + 104500n);
    });

    test('Admin menyetujui penarikan (approve): status PROCESSING dan memanggil createPayout', async () => {
      const res = await request(app)
        .post(`/api/admin/withdrawals/${withdrawal.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const dbWithdrawal = await prisma.withdrawalRequest.findUnique({
        where: { id: withdrawal.id },
      });
      expect(['PROCESSING', 'COMPLETED']).toContain(dbWithdrawal.status);
      expect(dbWithdrawal.reviewedById).toBe(admin.id);
    });
  });

  // ===========================================================================
  // 6. WEBHOOK PAYOUT GATEWAY & REPLAY IDEMPOTEN
  // ===========================================================================
  describe('6. Webhook Payout Gateway & Replay Idempoten', () => {
    let bankAccount;
    let withdrawal;

    beforeEach(async () => {
      bankAccount = await prisma.bankAccount.create({
        data: {
          userId: user1.id,
          bankCode: 'BCA',
          accountNumberEnc: encrypt('1234567890'),
          accountLast4: '7890',
          accountName: 'Budi Santoso',
        },
      });

      const res = await request(app)
        .post('/api/wallet/withdrawals')
        .set('Authorization', `Bearer ${token1}`)
        .set('Idempotency-Key', 'test-webhook-init')
        .send({ bankAccountId: bankAccount.id, amount: 100000 });

      withdrawal = res.body.data;

      // Pindahkan status ke PROCESSING seolah-olah sudah di-approve admin
      await prisma.withdrawalRequest.update({
        where: { id: withdrawal.id },
        data: { status: 'PROCESSING', reviewedById: admin.id, reviewedAt: new Date() },
      });
    });

    test('Webhook status COMPLETED: update status menjadi COMPLETED tanpa mutasi saldo baru', async () => {
      const userBefore = await prisma.user.findUnique({ where: { id: user1.id } });
      const ledgerCountBefore = await prisma.ledgerEntry.count({
        where: { referenceId: withdrawal.id },
      });

      const sim = fakeProvider.simulatePayoutWebhook({
        referenceId: withdrawal.id,
        amount: 100000,
        status: 'COMPLETED',
        eventId: 'evt_payout_success_1',
      });

      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Status withdrawal menjadi COMPLETED
      const updated = await prisma.withdrawalRequest.findUnique({
        where: { id: withdrawal.id },
      });
      expect(updated.status).toBe('COMPLETED');

      // TIDAK ADA mutasi saldo baru pada sukses (saldo sudah didebit saat inisiasi)
      const userAfter = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(userAfter.balance).toBe(userBefore.balance);

      const ledgerCountAfter = await prisma.ledgerEntry.count({
        where: { referenceId: withdrawal.id },
      });
      expect(ledgerCountAfter).toBe(ledgerCountBefore);
    });

    test('Webhook status FAILED: update status menjadi FAILED dan kembalikan dana penuh (WITHDRAWAL_RELEASE)', async () => {
      const userBefore = await prisma.user.findUnique({ where: { id: user1.id } });

      const sim = fakeProvider.simulatePayoutWebhook({
        referenceId: withdrawal.id,
        amount: 100000,
        status: 'FAILED',
        failureReason: 'ACCOUNT_CLOSED',
        eventId: 'evt_payout_failed_1',
      });

      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Status withdrawal menjadi FAILED
      const updated = await prisma.withdrawalRequest.findUnique({
        where: { id: withdrawal.id },
      });
      expect(updated.status).toBe('FAILED');
      expect(updated.failureReason).toContain('ACCOUNT_CLOSED');

      // Saldo dikembalikan penuh
      const userAfter = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(userAfter.balance).toBe(userBefore.balance + 104500n);

      // Ledger entry release tercatat
      const releaseEntry = await prisma.ledgerEntry.findFirst({
        where: {
          referenceId: withdrawal.id,
          type: 'WITHDRAWAL_RELEASE',
        },
      });
      expect(releaseEntry).not.toBeNull();
      expect(releaseEntry.amount).toBe(104500n);
    });

    test('Replay webhook idempoten: pengiriman webhook berulang tetap 200 OK tanpa efek ganda', async () => {
      const sim = fakeProvider.simulatePayoutWebhook({
        referenceId: withdrawal.id,
        amount: 100000,
        status: 'COMPLETED',
        eventId: 'evt_payout_replay_1',
      });

      const res1 = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      const res2 = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res1.status).toBe(200);
      expect(res2.status).toBe(200);
      expect(res2.body.message).toMatch(/telah diproses sebelumnya/i);
    });
  });
});
