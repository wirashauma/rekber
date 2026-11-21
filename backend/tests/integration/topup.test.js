// =============================================================================
// Integration Tests: Top-Up, Payment Gateway & Webhook Processing (Prompt 8)
// =============================================================================

const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, resetDb, disconnectDb } = require('../helpers');
const { getPaymentProvider } = require('../../src/providers/payment');
const topupService = require('../../src/services/topup.service');

describe('Payment Gateway: Top-Up & Webhook System (Prompt 8)', () => {
  let app;
  let user1;
  let user2;
  let token1;
  let token2;
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
    user1 = await createUser({
      name: 'User Satu',
      email: 'user1@example.com',
      role: 'USER',
      balance: 0n,
    });
    user2 = await createUser({
      name: 'User Dua',
      email: 'user2@example.com',
      role: 'USER',
      balance: 100000n,
    });
    token1 = tokenFor(user1);
    token2 = tokenFor(user2);
  });

  describe('1. Batas Nominal & Validasi Input Top-Up', () => {
    test('Menolak nominal di bawah batas minimum Rp 10.000 (422 Unprocessable Entity)', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 9999,
          method: 'QRIS',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].message).toMatch(/minimal Rp 10\.000/i);
    });

    test('Menolak nominal di atas batas maksimum Rp 20.000.000 (422 Unprocessable Entity)', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 20000001,
          method: 'QRIS',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].message).toMatch(/maksimal Rp 20\.000\.000/i);
    });

    test('Menolak nominal pecahan / desimal (422 Unprocessable Entity)', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 50000.75,
          method: 'QRIS',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].message).toMatch(/bilangan bulat/i);
    });

    test('Menolak metode pembayaran yang tidak didukung (422 Unprocessable Entity)', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 50000,
          method: 'CREDIT_CARD',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].message).toMatch(/Metode pembayaran tidak valid/i);
    });

    test('Menolak request tanpa token autentikasi (401 Unauthorized)', async () => {
      const res = await request(app).post('/api/wallet/topups').send({
        amount: 50000,
        method: 'QRIS',
      });

      expect(res.status).toBe(401);
    });

    test('Menolak pengguna nonaktif (isActive: false) (403 Forbidden)', async () => {
      const inactiveUser = await createUser({
        name: 'Inactive User',
        email: 'inactive@example.com',
        isActive: false,
      });
      const inactiveToken = tokenFor(inactiveUser);

      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${inactiveToken}`)
        .send({
          amount: 50000,
          method: 'QRIS',
        });

      expect(res.status).toBe(403);
    });
  });

  describe('2. Pembuatan Intent Top-Up (Happy Path via Fake Provider)', () => {
    test('Sukses membuat intent QRIS dengan format & status PENDING', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 50000,
          method: 'QRIS',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toMatchObject({
        userId: user1.id,
        amount: 50000,
        method: 'QRIS',
        status: 'PENDING',
      });
      expect(res.body.data.qrString).toBeDefined();
      expect(res.body.data.referenceId).toMatch(/^topup_/);
      expect(res.body.data.expiresAt).toBeDefined();

      // Verify in DB
      const dbIntent = await prisma.paymentIntent.findUnique({
        where: { id: res.body.data.id },
      });
      expect(dbIntent).not.toBeNull();
      expect(dbIntent.amount).toBe(50000n);
      expect(dbIntent.status).toBe('PENDING');
    });

    test('Sukses membuat intent Virtual Account dengan nomor VA dan kode bank', async () => {
      const res = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 150000,
          method: 'VIRTUAL_ACCOUNT',
          bankCode: 'BCA',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toMatchObject({
        userId: user1.id,
        amount: 150000,
        method: 'VIRTUAL_ACCOUNT',
        bankCode: 'BCA',
        status: 'PENDING',
      });
      expect(res.body.data.vaNumber).toBeDefined();
    });
  });

  describe('3. Detail & Riwayat Top-Up (GET /wallet/topups)', () => {
    test('Pemilik intent dapat membaca detail top-up miliknya (200 OK)', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 75000,
          method: 'QRIS',
        });

      const intentId = createRes.body.data.id;

      const detailRes = await request(app)
        .get(`/api/wallet/topups/${intentId}`)
        .set('Authorization', `Bearer ${token1}`);

      expect(detailRes.status).toBe(200);
      expect(detailRes.body.data.id).toBe(intentId);
      expect(detailRes.body.data.amount).toBe(75000);
    });

    test('IDOR: Pengguna lain menerima 404 Not Found saat mengakses ID top-up orang lain', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 75000,
          method: 'QRIS',
        });

      const intentId = createRes.body.data.id;

      // User2 attempts to access user1's top-up intent
      const idorRes = await request(app)
        .get(`/api/wallet/topups/${intentId}`)
        .set('Authorization', `Bearer ${token2}`);

      expect(idorRes.status).toBe(404);
      expect(idorRes.body.message).toMatch(/tidak ditemukan/i);
    });

    test('Daftar riwayat top-up mendukung paginasi kursor', async () => {
      for (let i = 1; i <= 3; i++) {
        await request(app)
          .post('/api/wallet/topups')
          .set('Authorization', `Bearer ${token1}`)
          .send({
            amount: 10000 * i,
            method: 'QRIS',
          });
      }

      const listRes1 = await request(app)
        .get('/api/wallet/topups?limit=2')
        .set('Authorization', `Bearer ${token1}`);

      expect(listRes1.status).toBe(200);
      expect(listRes1.body.data.items).toHaveLength(2);
      expect(listRes1.body.data.nextCursor).toBeDefined();

      const nextCursor = listRes1.body.data.nextCursor;
      const listRes2 = await request(app)
        .get(`/api/wallet/topups?cursor=${nextCursor}&limit=2`)
        .set('Authorization', `Bearer ${token1}`);

      expect(listRes2.status).toBe(200);
      expect(listRes2.body.data.items.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('4. Autentikasi & Verifikasi Webhook Signature / Callback Token', () => {
    test('Webhook tanpa token callback ditolak (401 Unauthorized)', async () => {
      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set('Content-Type', 'application/json')
        .send(JSON.stringify({ external_id: 'test_ref', amount: 50000 }));

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Unauthorized');
    });

    test('Webhook dengan token callback salah ditolak (401 Unauthorized)', async () => {
      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set('Content-Type', 'application/json')
        .set('x-callback-token', 'wrong_secret_token')
        .send(JSON.stringify({ external_id: 'test_ref', amount: 50000 }));

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('Unauthorized');
    });

    test('Webhook dengan token callback valid diterima (200 OK)', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 50000,
          method: 'QRIS',
        });

      const { referenceId } = createRes.body.data;
      const sim = fakeProvider.simulateWebhook({
        referenceId,
        amount: 50000,
        status: 'PAID',
      });

      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      // Verify user1 balance increased
      const updatedUser = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(updatedUser.balance).toBe(50000n);

      // Verify LedgerEntry created
      const ledger = await prisma.ledgerEntry.findFirst({
        where: { userId: user1.id, type: 'TOPUP' },
      });
      expect(ledger).not.toBeNull();
      expect(ledger.amount).toBe(50000n);
      expect(ledger.balanceAfter).toBe(50000n);
      expect(ledger.idempotencyKey).toBe(`topup:${createRes.body.data.id}`);

      // Verify WebhookEvent recorded
      const webhookEvent = await prisma.webhookEvent.findFirst({
        where: { provider: 'FAKE', status: 'PROCESSED' },
      });
      expect(webhookEvent).not.toBeNull();
    });
  });

  describe('5. Idempotensi & Replay Webhook Event', () => {
    test('Replay event valid yang sudah diproses tetap dibalas 200 tanpa kredit ganda', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 100000,
          method: 'QRIS',
        });

      const { referenceId } = createRes.body.data;
      const eventId = `fixed_event_${referenceId}`;
      const sim = fakeProvider.simulateWebhook({
        referenceId,
        amount: 100000,
        status: 'PAID',
        eventId,
      });

      // First webhook
      const res1 = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);
      expect(res1.status).toBe(200);

      // Second webhook (replay)
      const res2 = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);
      expect(res2.status).toBe(200);

      // Third webhook (replay)
      const res3 = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);
      expect(res3.status).toBe(200);

      // Saldo tetap tepat 100000 (tidak menjadi 200000 atau 300000)
      const user = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(user.balance).toBe(100000n);

      // Entri ledger hanya 1
      const count = await prisma.ledgerEntry.count({
        where: { userId: user1.id, type: 'TOPUP' },
      });
      expect(count).toBe(1);
    });

    test('10 webhook identik paralel → kredit tepat sekali & seluruh request sukses 200', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 250000,
          method: 'VIRTUAL_ACCOUNT',
          bankCode: 'BCA',
        });

      const { referenceId } = createRes.body.data;
      const eventId = `concurrent_event_${referenceId}`;
      const sim = fakeProvider.simulateWebhook({
        referenceId,
        amount: 250000,
        status: 'PAID',
        eventId,
      });

      // Fire 10 parallel webhook requests
      const promises = Array.from({ length: 10 }).map(() =>
        request(app).post('/webhooks/payment/fake').set(sim.headers).send(sim.rawBody)
      );

      const responses = await Promise.all(promises);

      // All 10 requests should succeed (200 OK)
      for (const res of responses) {
        expect(res.status).toBe(200);
      }

      // Saldo user1 harus bertambah tepat Rp 250.000
      const user = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(user.balance).toBe(250000n);

      // Ledger entry tepat 1
      const count = await prisma.ledgerEntry.count({
        where: { userId: user1.id, type: 'TOPUP' },
      });
      expect(count).toBe(1);
    });
  });

  describe('6. Validasi Jumlah Tidak Cocok (Amount Mismatch)', () => {
    test('Jumlah tidak cocok → tandai FAILED, JANGAN kredit, log warning', async () => {
      const createRes = await request(app)
        .post('/api/wallet/topups')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          amount: 100000,
          method: 'QRIS',
        });

      const { referenceId } = createRes.body.data;

      // Webhook payload sends mismatched amount (50000 instead of 100000)
      const sim = fakeProvider.simulateWebhook({
        referenceId,
        amount: 50000,
        status: 'PAID',
      });

      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res.status).toBe(200);

      // Verify intent is marked FAILED
      const intent = await prisma.paymentIntent.findUnique({
        where: { referenceId },
      });
      expect(intent.status).toBe('FAILED');

      // Verify user balance was NOT credited
      const user = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(user.balance).toBe(0n);

      // Verify no ledger entry created
      const ledger = await prisma.ledgerEntry.findFirst({
        where: { userId: user1.id, type: 'TOPUP' },
      });
      expect(ledger).toBeNull();

      // Verify WebhookEvent recorded status AMOUNT_MISMATCH
      const webhookEvent = await prisma.webhookEvent.findFirst({
        where: { status: 'AMOUNT_MISMATCH' },
      });
      expect(webhookEvent).not.toBeNull();
    });
  });

  describe('7. Kedaluwarsa Intent (expireStaleIntents)', () => {
    test('expireStaleIntents() mengubah status PENDING kedaluwarsa menjadi EXPIRED', async () => {
      // Create past intent manually
      const expiredIntent = await prisma.paymentIntent.create({
        data: {
          userId: user1.id,
          provider: 'FAKE',
          referenceId: 'topup_stale_1',
          amount: 50000n,
          method: 'QRIS',
          status: 'PENDING',
          expiresAt: new Date(Date.now() - 60000), // 1 minute in the past
        },
      });

      // Create active future intent
      const activeIntent = await prisma.paymentIntent.create({
        data: {
          userId: user1.id,
          provider: 'FAKE',
          referenceId: 'topup_active_1',
          amount: 50000n,
          method: 'QRIS',
          status: 'PENDING',
          expiresAt: new Date(Date.now() + 60000), // 1 minute in the future
        },
      });

      const result = await topupService.expireStaleIntents();
      expect(result.count).toBeGreaterThanOrEqual(1);

      // Expired intent is now EXPIRED
      const checkExpired = await prisma.paymentIntent.findUnique({
        where: { id: expiredIntent.id },
      });
      expect(checkExpired.status).toBe('EXPIRED');

      // Active intent is still PENDING
      const checkActive = await prisma.paymentIntent.findUnique({
        where: { id: activeIntent.id },
      });
      expect(checkActive.status).toBe('PENDING');
    });

    test('Webhook yang masuk pada intent EXPIRED tidak mengkredit saldo', async () => {
      const intent = await prisma.paymentIntent.create({
        data: {
          userId: user1.id,
          provider: 'FAKE',
          referenceId: 'topup_expired_intent',
          amount: 50000n,
          method: 'QRIS',
          status: 'EXPIRED',
          expiresAt: new Date(Date.now() - 60000),
        },
      });

      const sim = fakeProvider.simulateWebhook({
        referenceId: intent.referenceId,
        amount: 50000,
        status: 'PAID',
      });

      const res = await request(app)
        .post('/webhooks/payment/fake')
        .set(sim.headers)
        .send(sim.rawBody);

      expect(res.status).toBe(200);

      // Saldo user tetap 0
      const user = await prisma.user.findUnique({ where: { id: user1.id } });
      expect(user.balance).toBe(0n);
    });
  });

  describe('8. Unit Tests Xendit & Fake Provider Implementation', () => {
    test('XenditProvider verifyWebhook menggunakan timing-safe comparison', () => {
      const { XenditPaymentProvider } = require('../../src/providers/payment');
      const provider = new XenditPaymentProvider({
        webhookToken: 'secret_token_123',
      });

      expect(provider.verifyWebhook({ headers: { 'x-callback-token': 'secret_token_123' } })).toBe(
        true
      );
      expect(provider.verifyWebhook({ headers: { 'x-callback-token': 'wrong_token' } })).toBe(
        false
      );
      expect(provider.verifyWebhook({ headers: {} })).toBe(false);
    });

    test('XenditProvider parseWebhook mendukung berbagai struktur payload Xendit', () => {
      const { XenditPaymentProvider } = require('../../src/providers/payment');
      const provider = new XenditPaymentProvider();

      // Legacy QR callback
      const qrPayload = {
        id: 'qr_callback_1',
        external_id: 'topup_qr_ref',
        amount: 50000,
        status: 'COMPLETED',
      };
      const parsedQr = provider.parseWebhook({ body: qrPayload });
      expect(parsedQr.referenceId).toBe('topup_qr_ref');
      expect(parsedQr.amount).toBe(50000n);
      expect(parsedQr.status).toBe('PAID');

      // Legacy FVA callback
      const fvaPayload = {
        payment_id: 'fva_payment_1',
        external_id: 'topup_va_ref',
        amount: 100000,
        status: 'PAID',
      };
      const parsedFva = provider.parseWebhook({ body: fvaPayload });
      expect(parsedFva.referenceId).toBe('topup_va_ref');
      expect(parsedFva.amount).toBe(100000n);

      // Payment v3 callback
      const v3Payload = {
        event: 'payment.capture',
        data: {
          payment_id: 'v3_payment_1',
          reference_id: 'topup_v3_ref',
          request_amount: 200000,
          status: 'SUCCEEDED',
        },
      };
      const parsedV3 = provider.parseWebhook({ body: v3Payload });
      expect(parsedV3.referenceId).toBe('topup_v3_ref');
      expect(parsedV3.amount).toBe(200000n);
      expect(parsedV3.status).toBe('PAID');
    });
  });
});
