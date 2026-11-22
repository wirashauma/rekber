// =============================================================================
// E2E Test Suite: Complete Escrow Flow, Background Worker, Security & Edge Cases
// Prompt 19 Deliverable 1
// =============================================================================

const request = require('supertest');
const sharp = require('sharp');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, resetDb, disconnectDb } = require('../helpers');
const { runAutoRelease, runExpirePending } = require('../../src/worker');
const { reconcile } = require('../../src/services/reconcile.service');
const { getPaymentProvider } = require('../../src/providers/payment');

const app = createApp();
const fakeProvider = getPaymentProvider('fake');

describe('E2E Escrow Flow & Critical Lifecycle Scenarios (Prompt 19)', () => {
  let admin;
  let adminToken;
  let testImageBuffer;

  beforeAll(async () => {
    // Generate valid 100x100 PNG image buffer for file upload tests
    testImageBuffer = await sharp({
      create: {
        width: 100,
        height: 100,
        channels: 4,
        background: { r: 50, g: 120, b: 220, alpha: 1 },
      },
    })
      .png()
      .toBuffer();
  });

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

    // Seed admin
    admin = await createUser({
      name: 'Super Admin E2E',
      email: 'admin.e2e@rekber.id',
      role: 'ADMIN',
      kycStatus: 'APPROVED',
    });
    adminToken = tokenFor(admin);
  });

  // ---------------------------------------------------------------------------
  // (a) Jalur Sukses Lengkap
  // ---------------------------------------------------------------------------
  test('(a) Jalur sukses: 2 user daftar -> top-up via webhook -> buat transaksi -> bayar -> kirim bukti -> konfirmasi -> KYC seller -> tarik dana -> webhook payout -> ledger reconcile 0 selisih', async () => {
    // 1. Registrasi 2 user melalui HTTP
    const regBuyer = await request(app).post('/api/auth/register').send({
      name: 'Pembeli Sukses',
      email: 'buyer.sukses@example.com',
      password: 'Password123!',
    });
    expect(regBuyer.status).toBe(201);
    const buyer = regBuyer.body.data.user;
    const buyerToken = regBuyer.body.data.accessToken;

    const regSeller = await request(app).post('/api/auth/register').send({
      name: 'Penjual Sukses',
      email: 'seller.sukses@example.com',
      password: 'Password123!',
    });
    expect(regSeller.status).toBe(201);
    const seller = regSeller.body.data.user;
    const sellerToken = regSeller.body.data.accessToken;

    // 2. Buyer top-up Rp 1.000.000 via webhook payment provider
    const topupRes = await request(app)
      .post('/api/wallet/topups')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        amount: 1000000,
        method: 'QRIS',
      });
    expect(topupRes.status).toBe(201);
    const topupIntent = topupRes.body.data;
    expect(topupIntent.status).toBe('PENDING');

    const topupWebhook = fakeProvider.simulateWebhook({
      referenceId: topupIntent.referenceId,
      amount: 1000000,
      status: 'PAID',
    });
    const webhookRes = await request(app)
      .post('/api/webhooks/payment/fake')
      .set(topupWebhook.headers)
      .send(topupWebhook.rawBody);
    expect(webhookRes.status).toBe(200);

    // Verifikasi saldo buyer menjadi Rp 1.000.000
    const buyerWallet = await request(app)
      .get('/api/wallet')
      .set('Authorization', `Bearer ${buyerToken}`);
    expect(buyerWallet.body.data.balance).toBe(1000000);

    // 3. Buyer buat transaksi Rp 500.000 (fee SPLIT 2% = 10.000, buyer 5.000, seller 5.000)
    const createTxRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 500000,
        itemDescription: 'Monitor Gaming 24 Inch 144Hz',
        feePayer: 'SPLIT',
      });
    expect(createTxRes.status).toBe(201);
    const tx = createTxRes.body.data;
    expect(tx.status).toBe('PENDING');
    expect(tx.buyerFee).toBe(5000);
    expect(tx.sellerFee).toBe(5000);

    // 4. Buyer bayar transaksi (mengunci Rp 505.000 ke escrow)
    const payRes = await request(app)
      .put(`/api/transactions/${tx.id}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'PAID' });
    expect(payRes.status).toBe(200);
    expect(payRes.body.data.status).toBe('PAID');
    expect(payRes.body.data.heldAmount).toBe(505000);

    // 5. Penjual unggah bukti pengiriman (SHIPMENT_PROOF) & submit nomor resi
    const uploadRes = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'SHIPMENT_PROOF')
      .attach('file', testImageBuffer, 'resi_pengiriman.png');
    expect(uploadRes.status).toBe(201);
    const proofFile = uploadRes.body.data;

    const shipRes = await request(app)
      .post(`/api/transactions/${tx.id}/shipment`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        courier: 'JNE',
        trackingNumber: 'JNE1234567890ID',
        note: 'Paket sudah diserahkan ke kurir dengan bubble wrap tebal.',
        fileIds: [proofFile.id],
      });
    expect(shipRes.status).toBe(200);
    expect(shipRes.body.data.status).toBe('SHIPPED');

    // 6. Pembeli konfirmasi penerimaan barang -> status COMPLETED, dana diteruskan ke penjual
    const confirmRes = await request(app)
      .put(`/api/transactions/${tx.id}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'COMPLETED' });
    expect(confirmRes.status).toBe(200);
    expect(confirmRes.body.data.status).toBe('COMPLETED');
    expect(confirmRes.body.data.heldAmount).toBe(0);

    // Cek saldo penjual: 500.000 - 5.000 fee = 495.000
    const sellerWallet = await request(app)
      .get('/api/wallet')
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(sellerWallet.body.data.balance).toBe(495000);

    // 7. Penjual verifikasi KYC (upload KTP & Selfie -> submit KYC -> admin approve)
    const ktpUpload = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'KYC_ID')
      .attach('file', testImageBuffer, 'ktp.png');
    expect(ktpUpload.status).toBe(201);

    const selfieUpload = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'KYC_SELFIE')
      .attach('file', testImageBuffer, 'selfie.png');
    expect(selfieUpload.status).toBe(201);

    const kycSubmit = await request(app)
      .post('/api/kyc')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        fullName: 'Penjual Sukses',
        nik: '3201123456789012',
        idFileId: ktpUpload.body.data.id,
        selfieFileId: selfieUpload.body.data.id,
      });
    expect(kycSubmit.status).toBe(201);
    const kycId = kycSubmit.body.data.id;

    const kycApprove = await request(app)
      .post(`/api/admin/kyc/${kycId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(kycApprove.status).toBe(200);

    // 8. Penjual daftarkan rekening bank & tarik dana (withdrawal)
    const bankRes = await request(app)
      .post('/api/bank-accounts')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        bankCode: 'BCA',
        accountNumber: '8877665544',
        accountName: 'Penjual Sukses',
      });
    expect(bankRes.status).toBe(201);
    const bankAccount = bankRes.body.data;

    const withdrawRes = await request(app)
      .post('/api/wallet/withdrawals')
      .set('Authorization', `Bearer ${sellerToken}`)
      .set('Idempotency-Key', `idem_withdraw_${Date.now()}`)
      .send({
        bankAccountId: bankAccount.id,
        amount: 400000,
      });
    expect(withdrawRes.status).toBe(201);
    const withdrawal = withdrawRes.body.data;
    expect(withdrawal.status).toBe('PENDING_REVIEW');

    // 9. Admin setujui penarikan dana -> status PROCESSING
    const approveWithdrawRes = await request(app)
      .post(`/api/admin/withdrawals/${withdrawal.id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(approveWithdrawRes.status).toBe(200);

    // 10. Webhook payout dari payment gateway -> status COMPLETED
    const payoutWebhook = fakeProvider.simulatePayoutWebhook({
      referenceId: withdrawal.id,
      amount: 400000,
      status: 'COMPLETED',
    });
    const payoutRes = await request(app)
      .post('/api/webhooks/payment/fake')
      .set(payoutWebhook.headers)
      .send(payoutWebhook.rawBody);
    expect(payoutRes.status).toBe(200);

    // 11. Verifikasi Rekonsiliasi dan Integritas Finansial: Nol Selisih!
    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
    expect(audit.userDiscrepancies).toHaveLength(0);
    expect(audit.escrowDiscrepancies).toHaveLength(0);
  });

  // ---------------------------------------------------------------------------
  // (b) Auto-release oleh Worker
  // ---------------------------------------------------------------------------
  test('(b) Auto-release oleh worker: transaksi SHIPPED dengan autoReleaseAt lampau otomatis diselesaikan', async () => {
    const buyer = await createUser({ balance: 300000n });
    const seller = await createUser({ balance: 0n });
    const buyerToken = tokenFor(buyer);
    const sellerToken = tokenFor(seller);

    // Buat & bayar transaksi
    const txRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 200000,
        itemDescription: 'Earphone TWS Bluetooth',
        feePayer: 'BUYER',
      });
    const txId = txRes.body.data.id;

    await request(app)
      .put(`/api/transactions/${txId}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'PAID' });

    // Unggah bukti & kirim
    const uploadRes = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'SHIPMENT_PROOF')
      .attach('file', testImageBuffer, 'resi.png');

    await request(app)
      .post(`/api/transactions/${txId}/shipment`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        courier: 'SiCepat',
        trackingNumber: '001234567890',
        fileIds: [uploadRes.body.data.id],
      });

    // Manipulasi autoReleaseAt ke 2 jam yang lalu
    await prisma.transaction.update({
      where: { id: txId },
      data: { autoReleaseAt: new Date(Date.now() - 2 * 60 * 60 * 1000) },
    });

    // Jalankan worker auto-release
    const workerResult = await runAutoRelease();
    expect(workerResult.processed).toBeGreaterThanOrEqual(1);

    // Verifikasi status transaksi telah menjadi COMPLETED & dana masuk ke penjual
    const updatedTx = await prisma.transaction.findUnique({ where: { id: txId } });
    expect(updatedTx.status).toBe('COMPLETED');
    expect(updatedTx.heldAmount).toBe(0n);

    const updatedSeller = await prisma.user.findUnique({ where: { id: seller.id } });
    expect(updatedSeller.balance).toBe(200000n);

    // Audit rekonsiliasi tetap nol selisih
    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // (c) Sengketa -> Admin Refund
  // ---------------------------------------------------------------------------
  test('(c) Sengketa -> admin refund: dana escrow dikembalikan utuh ke pembeli', async () => {
    const buyer = await createUser({ balance: 500000n });
    const seller = await createUser({ balance: 0n });
    const buyerToken = tokenFor(buyer);
    const sellerToken = tokenFor(seller);

    const txRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 250000,
        itemDescription: 'Jam Tangan Analog Pria',
        feePayer: 'BUYER',
      });
    const txId = txRes.body.data.id;

    await request(app)
      .put(`/api/transactions/${txId}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'PAID' });

    const uploadRes = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'SHIPMENT_PROOF')
      .attach('file', testImageBuffer, 'resi.png');

    await request(app)
      .post(`/api/transactions/${txId}/shipment`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        courier: 'J&T',
        trackingNumber: 'JT99887766',
        fileIds: [uploadRes.body.data.id],
      });

    // Pembeli ajukan sengketa
    const disputeRes = await request(app)
      .post(`/api/transactions/${txId}/dispute`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        reason: 'NOT_AS_DESCRIBED',
        description: 'Barang yang diterima retak dan warna tidak sesuai pesanan.',
      });
    expect(disputeRes.status).toBe(201);
    const disputeId = disputeRes.body.data.id;

    // Admin putuskan sengketa dengan REFUND_TO_BUYER
    const resolveRes = await request(app)
      .post(`/api/admin/disputes/${disputeId}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        decision: 'REFUND_TO_BUYER',
        note: 'Bukti pembeli terverifikasi barang retak parah saat diterima.',
      });
    expect(resolveRes.status).toBe(200);

    const updatedTx = await prisma.transaction.findUnique({ where: { id: txId } });
    expect(updatedTx.status).toBe('REFUNDED');
    expect(updatedTx.heldAmount).toBe(0n);

    // Saldo pembeli kembali semula
    const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
    expect(updatedBuyer.balance).toBe(500000n);

    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // (d) Sengketa -> Admin Release
  // ---------------------------------------------------------------------------
  test('(d) Sengketa -> admin release: dana escrow diteruskan ke penjual', async () => {
    const buyer = await createUser({ balance: 400000n });
    const seller = await createUser({ balance: 0n });
    const buyerToken = tokenFor(buyer);
    const sellerToken = tokenFor(seller);

    const txRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 300000,
        itemDescription: 'Sepatu Running Original',
        feePayer: 'BUYER',
      });
    const txId = txRes.body.data.id;

    await request(app)
      .put(`/api/transactions/${txId}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'PAID' });

    const uploadRes = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${sellerToken}`)
      .field('purpose', 'SHIPMENT_PROOF')
      .attach('file', testImageBuffer, 'resi.png');

    await request(app)
      .post(`/api/transactions/${txId}/shipment`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        courier: 'JNE',
        trackingNumber: 'JNE77665544',
        fileIds: [uploadRes.body.data.id],
      });

    const disputeRes = await request(app)
      .post(`/api/transactions/${txId}/dispute`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        reason: 'OTHER',
        description: 'Pembeli berubah pikiran ingin mengembalikan barang.',
      });
    expect(disputeRes.status).toBe(201);
    const disputeId = disputeRes.body.data.id;

    // Admin putuskan sengketa dengan RELEASE_TO_SELLER
    const resolveRes = await request(app)
      .post(`/api/admin/disputes/${disputeId}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        decision: 'RELEASE_TO_SELLER',
        note: 'Barang terkirim sesuai deskripsi; alasan pembeli tidak dapat diterima.',
      });
    expect(resolveRes.status).toBe(200);

    const updatedTx = await prisma.transaction.findUnique({ where: { id: txId } });
    expect(updatedTx.status).toBe('COMPLETED');
    expect(updatedTx.heldAmount).toBe(0n);

    // Penjual menerima 300.000 (karena fee ditanggung pembeli)
    const updatedSeller = await prisma.user.findUnique({ where: { id: seller.id } });
    expect(updatedSeller.balance).toBe(300000n);

    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // (e) PENDING Kedaluwarsa
  // ---------------------------------------------------------------------------
  test('(e) PENDING kedaluwarsa: transaksi PENDING melewati batas waktu otomatis dibatalkan worker', async () => {
    const buyer = await createUser({ balance: 100000n });
    const seller = await createUser({ balance: 0n });
    const buyerToken = tokenFor(buyer);

    const txRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 80000,
        itemDescription: 'Buku Pemrograman Node.js',
      });
    const txId = txRes.body.data.id;
    expect(txRes.body.data.status).toBe('PENDING');

    // Ubah expiresAt menjadi 2 jam lalu
    await prisma.transaction.update({
      where: { id: txId },
      data: { expiresAt: new Date(Date.now() - 2 * 60 * 60 * 1000) },
    });

    // Jalankan worker expire pending
    const workerResult = await runExpirePending();
    expect(workerResult.processed).toBeGreaterThanOrEqual(1);

    const updatedTx = await prisma.transaction.findUnique({ where: { id: txId } });
    expect(updatedTx.status).toBe('CANCELLED');
  });

  // ---------------------------------------------------------------------------
  // (f) Webhook Top-Up Duplikat (Idempotensi)
  // ---------------------------------------------------------------------------
  test('(f) Webhook top-up duplikat: callback berulang dengan eventId sama tidak menduplikasi kredit saldo', async () => {
    const buyer = await createUser({ balance: 0n });
    const buyerToken = tokenFor(buyer);

    const topupRes = await request(app)
      .post('/api/wallet/topups')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        amount: 150000,
        method: 'QRIS',
      });
    const refId = topupRes.body.data.referenceId;
    const fixedEventId = `fixed_evt_idempotent_${Date.now()}`;

    const topupWebhook = fakeProvider.simulateWebhook({
      referenceId: refId,
      amount: 150000,
      status: 'PAID',
      eventId: fixedEventId,
    });

    // Panggilan pertama
    const res1 = await request(app)
      .post('/api/webhooks/payment/fake')
      .set(topupWebhook.headers)
      .send(topupWebhook.rawBody);
    expect(res1.status).toBe(200);

    // Panggilan kedua dengan payload dan eventId yang persis sama
    const res2 = await request(app)
      .post('/api/webhooks/payment/fake')
      .set(topupWebhook.headers)
      .send(topupWebhook.rawBody);
    expect(res2.status).toBe(200);

    // Saldo harus tepat Rp 150.000, bukan Rp 300.000
    const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
    expect(updatedBuyer.balance).toBe(150000n);

    // Entri buku besar TOPUP untuk payment intent ini harus tepat 1
    const ledgerCount = await prisma.ledgerEntry.count({
      where: {
        userId: buyer.id,
        type: 'TOPUP',
      },
    });
    expect(ledgerCount).toBe(1);
  });

  // ---------------------------------------------------------------------------
  // (g) Rotasi dan Reuse Refresh Token
  // ---------------------------------------------------------------------------
  test('(g) Rotasi dan reuse refresh token: pemakaian token lama mencabut semua sesi pengguna', async () => {
    const regRes = await request(app).post('/api/auth/register').send({
      name: 'User Token Test',
      email: 'token.test@example.com',
      password: 'Password123!',
    });
    const initialRefreshToken = regRes.body.data.refreshToken;

    // 1. Rotasi pertama: tukar initialRefreshToken dengan token baru
    const refreshRes1 = await request(app).post('/api/auth/refresh').send({
      refreshToken: initialRefreshToken,
    });
    expect(refreshRes1.status).toBe(200);
    const newRefreshToken = refreshRes1.body.data.refreshToken;
    expect(newRefreshToken).toBeDefined();
    expect(newRefreshToken).not.toBe(initialRefreshToken);

    // 2. Simulasi pencurian token: penyerang mencoba memakai initialRefreshToken yang sudah dicabut
    const reuseAttempt = await request(app).post('/api/auth/refresh').send({
      refreshToken: initialRefreshToken,
    });
    expect(reuseAttempt.status).toBe(401);
    expect(reuseAttempt.body.code).toBe('TOKEN_THEFT_DETECTED');

    // 3. Konfirmasi konsekuensi: token yang sah (newRefreshToken) pun kini ikut dicabut demi keamanan
    const subsequentAttempt = await request(app).post('/api/auth/refresh').send({
      refreshToken: newRefreshToken,
    });
    expect(subsequentAttempt.status).toBe(401);
  });

  // ---------------------------------------------------------------------------
  // (h) User Di-Ban Saat Transaksi Berjalan
  // ---------------------------------------------------------------------------
  test('(h) User di-ban saat transaksi berjalan: sesi terputus, saldo escrow tetap utuh tanpa kebocoran', async () => {
    const buyer = await createUser({ balance: 500000n });
    const seller = await createUser({ balance: 100000n });
    const buyerToken = tokenFor(buyer);

    // Buat & bayar transaksi Rp 200.000
    const txRes = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        sellerId: seller.id,
        amount: 200000,
        itemDescription: 'Konsol Game Portabel',
        feePayer: 'BUYER',
      });
    const txId = txRes.body.data.id;

    await request(app)
      .put(`/api/transactions/${txId}/status`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ status: 'PAID' });

    // Admin memblokir (ban) pembeli
    const banRes = await request(app)
      .post(`/api/admin/users/${buyer.id}/ban`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        reason: 'Terindikasi melakukan tindakan penipuan di platform lain.',
      });
    expect(banRes.status).toBe(200);

    // Pembeli mencoba mengakses API dengan token lamanya -> Ditolak 403 (ACCOUNT_INACTIVE)
    const accessAttempt = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${buyerToken}`);
    expect(accessAttempt.status).toBe(403);
    expect(accessAttempt.body.code).toBe('ACCOUNT_INACTIVE');

    // Pastikan dana escrow Rp 204.000 (200.000 + 4.000 fee) tetap aman terkunci di transaksi
    const txInDb = await prisma.transaction.findUnique({ where: { id: txId } });
    expect(txInDb.status).toBe('PAID');
    expect(txInDb.heldAmount).toBe(204000n);

    // Saldo penjual tidak terganggu
    const sellerInDb = await prisma.user.findUnique({ where: { id: seller.id } });
    expect(sellerInDb.balance).toBe(100000n);

    // Audit rekonsiliasi membuktikan seluruh saldo & escrow 100% konsisten
    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
    expect(audit.userDiscrepancies).toHaveLength(0);
    expect(audit.escrowDiscrepancies).toHaveLength(0);
  });
});
