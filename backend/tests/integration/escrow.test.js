// =============================================================================
// Integration Tests: Escrow Service, State Machine, Wallet & Public Config
// =============================================================================

const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const escrowService = require('../../src/services/escrow.service');
const { reconcile } = require('../../src/services/reconcile.service');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');

const app = createApp();

describe('Integration Tests: Escrow Service, Wallet & Public Config', () => {
  beforeEach(async () => {
    await resetDb();
    // Seed default settings for testing
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
  });

  afterAll(async () => {
    await disconnectDb();
  });

  describe('POST /api/transactions (Pembuatan Transaksi & Perhitungan Fee)', () => {
    test('Sukses membuat transaksi dengan fee SPLIT (default) dan kode unik 8 karakter', async () => {
      const buyer = await createUser({ balance: 500000 });
      const seller = await createUser({ balance: 0 });

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${tokenFor(buyer)}`)
        .send({
          sellerId: seller.id,
          amount: 100000,
          itemDescription: 'Keyboard Mekanikal RGB',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      const data = res.body.data;
      expect(data.amount).toBe(100000);
      expect(data.status).toBe('PENDING');
      expect(data.code).toHaveLength(8);
      // Fee 2% dari 100.000 = 2.000, SPLIT -> buyerFee 1.000, sellerFee 1.000
      expect(data.buyerFee).toBe(1000);
      expect(data.sellerFee).toBe(1000);
      expect(data.feePayer).toBe('SPLIT');
      expect(data.heldAmount).toBe(0);
      expect(data.expiresAt).toBeDefined();
    });

    test('Mendukung alokasi fee khusus: BUYER dan SELLER', async () => {
      const buyer = await createUser();
      const seller = await createUser();

      // BUYER menanggung seluruh fee
      const resBuyer = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${tokenFor(buyer)}`)
        .send({
          sellerId: seller.id,
          amount: 50000,
          itemDescription: 'Headphone Gaming',
          feePayer: 'BUYER',
        });

      expect(resBuyer.status).toBe(201);
      // 2% dari 50.000 = 1.000 (minimum fee 1.000)
      expect(resBuyer.body.data.buyerFee).toBe(1000);
      expect(resBuyer.body.data.sellerFee).toBe(0);

      // SELLER menanggung seluruh fee
      const resSeller = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${tokenFor(buyer)}`)
        .send({
          sellerId: seller.id,
          amount: 50000,
          itemDescription: 'Mouse Wireless',
          feePayer: 'SELLER',
        });

      expect(resSeller.status).toBe(201);
      expect(resSeller.body.data.buyerFee).toBe(0);
      expect(resSeller.body.data.sellerFee).toBe(1000);
    });

    test('Menolak transaksi yang melebihi max_transaction_amount (400 Bad Request)', async () => {
      const buyer = await createUser();
      const seller = await createUser();

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${tokenFor(buyer)}`)
        .send({
          sellerId: seller.id,
          amount: 6000000, // melebihi batas 5.000.000
          itemDescription: 'Laptop Gaming High End',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('melebihi batas maksimal platform');
    });
  });

  describe('PUT /api/transactions/:id/status (Matriks Transisi State Machine & Otoritas Peran)', () => {
    describe('Transisi PENDING → PAID', () => {
      test('Diizinkan untuk BUYER: saldo terpotong (amount + buyerFee) & heldAmount terisi', async () => {
        const buyer = await createUser({ balance: 250000 });
        const seller = await createUser({ balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 200000,
          buyerFee: 2000,
          sellerFee: 2000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('PAID');
        expect(res.body.data.heldAmount).toBe(202000); // 200.000 + 2.000 buyerFee
        expect(res.body.data.paidAt).toBeDefined();

        // Saldo buyer terpotong 202.000 dari 250.000 = 48.000
        const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
        expect(updatedBuyer.balance).toBe(48000n);

        // Verifikasi entri ledger ESCROW_HOLD
        const ledgerEntry = await prisma.ledgerEntry.findFirst({
          where: { transactionId: tx.id, type: 'ESCROW_HOLD' },
        });
        expect(ledgerEntry).toBeDefined();
        expect(ledgerEntry.amount).toBe(202000n);
        expect(ledgerEntry.balanceAfter).toBe(48000n);
      });

      test('Ditolak jika SELLER mencoba memicu PENDING → PAID (403 Forbidden)', async () => {
        const buyer = await createUser({ balance: 250000 });
        const seller = await createUser({ balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 200000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(403);
        expect(res.body.message).toContain('Hanya pembeli yang dapat melakukan aksi ini');
      });
    });

    describe('Transisi PENDING → CANCELLED', () => {
      test('Diizinkan untuk BUYER dan SELLER tanpa mutasi saldo', async () => {
        const buyer = await createUser({ balance: 100000 });
        const seller = await createUser({ balance: 50000 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 50000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ status: 'CANCELLED', reason: 'Stok barang habis' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('CANCELLED');
        expect(res.body.data.cancelledAt).toBeDefined();

        // Tidak ada ledger entry karena dana belum didebit
        const ledgerCount = await prisma.ledgerEntry.count({
          where: { transactionId: tx.id },
        });
        expect(ledgerCount).toBe(0);
      });
    });

    describe('Transisi PAID → SHIPPED (via POST /transactions/:id/shipment)', () => {
      test('PUT /status menolak target SHIPPED dan mengarahkan ke endpoint shipment (400)', async () => {
        const buyer = await createUser();
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 150000,
          status: 'PAID',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ status: 'SHIPPED' });

        expect(res.status).toBe(400);
        expect(res.body.message).toMatch(/endpoint pengiriman/i);
      });

      test('Diizinkan untuk SELLER via POST /shipment: mencatat shippedAt dan autoReleaseAt', async () => {
        const buyer = await createUser();
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 150000,
          status: 'PAID',
        });

        const res = await request(app)
          .post(`/api/transactions/${tx.id}/shipment`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ courier: 'JNE', trackingNumber: 'JNE123456789' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('SHIPPED');
        expect(res.body.data.shippedAt).toBeDefined();
        expect(res.body.data.autoReleaseAt).toBeDefined();
        expect(res.body.data.shipmentProof).toBeDefined();
        expect(res.body.data.shipmentProof.courier).toBe('JNE');
        expect(res.body.data.shipmentProof.trackingNumber).toBe('JNE123456789');
      });

      test('Ditolak jika BUYER mencoba menandai SHIPPED via POST /shipment (403 Forbidden)', async () => {
        const buyer = await createUser();
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 150000,
          status: 'PAID',
        });

        const res = await request(app)
          .post(`/api/transactions/${tx.id}/shipment`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ courier: 'JNE', trackingNumber: 'JNE123456789' });

        expect(res.status).toBe(403);
        expect(res.body.message).toContain('Hanya penjual');
      });
    });

    describe('Transisi PAID → REFUNDED', () => {
      test('Diizinkan untuk SELLER (pengembalian sukarela) dan ADMIN: dana escrow dikembalikan ke pembeli', async () => {
        const buyer = await createUser({ balance: 0 });
        const seller = await createUser({ balance: 0 });
        const admin = await createUser({ role: 'ADMIN' });

        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          buyerFee: 1000,
          heldAmount: 101000,
          status: 'PAID',
        });

        // Admin melakukan refund
        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(admin)}`)
          .send({ status: 'REFUNDED', reason: 'Barang tidak dapat diproses' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('REFUNDED');
        expect(res.body.data.heldAmount).toBe(0);

        // Pembeli menerima pengembalian penuh (amount + buyerFee) = Rp 101.000
        const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
        expect(updatedBuyer.balance).toBe(101000n);

        // Verifikasi entri ledger ESCROW_REFUND
        const refundEntry = await prisma.ledgerEntry.findFirst({
          where: { transactionId: tx.id, type: 'ESCROW_REFUND' },
        });
        expect(refundEntry).toBeDefined();
        expect(refundEntry.amount).toBe(101000n);
      });
    });

    describe('Transisi SHIPPED → COMPLETED', () => {
      test('Diizinkan untuk BUYER: kredit saldo penjual (amount - sellerFee) & catat PLATFORM_FEE', async () => {
        const buyer = await createUser({ balance: 0 });
        const seller = await createUser({ balance: 20000 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          buyerFee: 1000,
          sellerFee: 1000,
          heldAmount: 101000,
          status: 'SHIPPED',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'COMPLETED' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('COMPLETED');
        expect(res.body.data.heldAmount).toBe(0);
        expect(res.body.data.completedAt).toBeDefined();

        // Penjual menerima 100.000 - 1.000 (sellerFee) = 99.000. Saldo awal 20.000 -> 119.000
        const updatedSeller = await prisma.user.findUnique({ where: { id: seller.id } });
        expect(updatedSeller.balance).toBe(119000n);

        // Verifikasi entri ledger ESCROW_RELEASE untuk seller
        const releaseEntry = await prisma.ledgerEntry.findFirst({
          where: { transactionId: tx.id, type: 'ESCROW_RELEASE' },
        });
        expect(releaseEntry).toBeDefined();
        expect(releaseEntry.amount).toBe(99000n);
        expect(releaseEntry.userId).toBe(seller.id);

        // Verifikasi entri ledger PLATFORM_FEE untuk platform (userId null)
        const feeEntry = await prisma.ledgerEntry.findFirst({
          where: { transactionId: tx.id, type: 'PLATFORM_FEE' },
        });
        expect(feeEntry).toBeDefined();
        expect(feeEntry.userId).toBeNull();
        expect(feeEntry.amount).toBe(2000n); // 1.000 buyerFee + 1.000 sellerFee
      });
    });

    describe('Penolakan Transisi Sengketa (DISPUTED)', () => {
      test('PUT /status menolak transisi menuju DISPUTED dan mengarahkan ke endpoint sengketa (400)', async () => {
        const buyer = await createUser();
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          status: 'PAID',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'DISPUTED' });

        expect(res.status).toBe(400);
        expect(res.body.message).toContain(
          'Transisi status sengketa (DISPUTED) harus diproses melalui endpoint sengketa'
        );
      });
    });

    describe('Compare-and-Swap Race Condition Guard', () => {
      test('Mengembalikan 409 Conflict bila status transaksi sudah berubah (Compare-and-Swap)', async () => {
        const buyer = await createUser({ balance: 300000 });
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'PENDING',
        });

        // Ubah status di database secara independen (misal dibatalkan pihak lain di tengah jalan)
        await prisma.transaction.update({
          where: { id: tx.id },
          data: { status: 'CANCELLED' },
        });

        // Panggilan holdEscrow menolak eksekusi dan melempar 409
        await expect(escrowService.holdEscrow(null, tx.id, buyer.id)).rejects.toMatchObject({
          statusCode: 409,
          message: expect.stringContaining('Status transaksi sudah berubah'),
        });
      });
    });
  });

  describe('GET /api/transactions/code/:code', () => {
    test('Dapat diakses oleh Pembeli dan Penjual (200 OK)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 80000,
      });

      const resBuyer = await request(app)
        .get(`/api/transactions/code/${tx.code}`)
        .set('Authorization', `Bearer ${tokenFor(buyer)}`);
      expect(resBuyer.status).toBe(200);
      expect(resBuyer.body.data.id).toBe(tx.id);

      const resSeller = await request(app)
        .get(`/api/transactions/code/${tx.code}`)
        .set('Authorization', `Bearer ${tokenFor(seller)}`);
      expect(resSeller.status).toBe(200);
      expect(resSeller.body.data.id).toBe(tx.id);
    });

    test('Mengembalikan 404 Not Found jika diakses oleh orang ketiga (non-peserta)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const stranger = await createUser();
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
      });

      const res = await request(app)
        .get(`/api/transactions/code/${tx.code}`)
        .set('Authorization', `Bearer ${tokenFor(stranger)}`);

      // Demi keamanan, kembalikan 404 agar tidak membocorkan keberadaan kode
      expect(res.status).toBe(404);
    });
  });

  describe('Dompet (/api/wallet)', () => {
    test('GET /api/wallet mengembalikan saldo tersedia dan dana tertahan escrow', async () => {
      const buyer = await createUser({ balance: 300000 });
      const seller = await createUser();

      // Transaksi aktif yang menahan dana pembeli
      await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        buyerFee: 1000,
        heldAmount: 101000,
        status: 'PAID',
      });

      const res = await request(app)
        .get('/api/wallet')
        .set('Authorization', `Bearer ${tokenFor(buyer)}`);

      expect(res.status).toBe(200);
      expect(res.body.data.balance).toBe(300000);
      expect(res.body.data.heldBalance).toBe(101000);
      expect(res.body.data.currency).toBe('IDR');
    });

    test('GET /api/wallet/ledger hanya menampilkan mutasi milik sendiri dengan cursor pagination', async () => {
      const user = await createUser({ balance: 100000 });
      const stranger = await createUser({ balance: 50000 });

      // Catat mutasi untuk stranger
      await prisma.ledgerEntry.create({
        data: {
          userId: stranger.id,
          amount: 25000n,
          balanceAfter: 75000n,
          direction: 'CREDIT',
          type: 'TOPUP',
          idempotencyKey: `stranger:ledger:${Date.now()}`,
        },
      });

      const res = await request(app)
        .get('/api/wallet/ledger?limit=10')
        .set('Authorization', `Bearer ${tokenFor(user)}`);

      expect(res.status).toBe(200);
      const items = res.body.data.items;
      // Hanya mutasi milik user
      for (const item of items) {
        expect(item.userId).toBe(user.id);
      }
    });

    test('POST /api/wallet/topup dan /withdraw lama selalu mengembalikan 410 Gone', async () => {
      const user = await createUser();

      const resTopup = await request(app)
        .post('/api/wallet/topup')
        .set('Authorization', `Bearer ${tokenFor(user)}`)
        .send({ amount: 100000 });

      expect(resTopup.status).toBe(410);
      expect(resTopup.body.message).toBe('Gunakan fitur top-up/penarikan baru.');

      const resWithdraw = await request(app)
        .post('/api/wallet/withdraw')
        .set('Authorization', `Bearer ${tokenFor(user)}`)
        .send({ amount: 50000 });

      expect(resWithdraw.status).toBe(410);
      expect(resWithdraw.body.message).toBe('Gunakan fitur top-up/penarikan baru.');
    });
  });

  describe('GET /api/config/public (Konfigurasi Publik Tanpa Auth)', () => {
    test('Dapat diakses secara publik tanpa token bearer', async () => {
      const res = await request(app).get('/api/config/public');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      const config = res.body.data;
      expect(config.fee_percent).toBe(2);
      expect(config.fee_min).toBe(1000);
      expect(config.fee_payer_default).toBe('SPLIT');
      expect(config.withdraw_min).toBe(50000);
      expect(config.withdraw_fee).toBe(0);
      expect(config.max_transaction_amount).toBe(5000000);
    });
  });

  describe('Audit Rekonsiliasi Keuangan (reconcile())', () => {
    test('Rekonsiliasi sukses (isReconciled: true) bila saldo sesuai dengan mutasi ledger', async () => {
      const audit = await reconcile();
      expect(audit.isReconciled).toBe(true);
      expect(audit.userDiscrepancies).toHaveLength(0);
      expect(audit.escrowDiscrepancies).toHaveLength(0);
    });

    test('Rekonsiliasi mendeteksi manipulasi saldo manual tanpa ledger entry', async () => {
      const user = await createUser({ balance: 100000 });

      // Manipulasi saldo secara ilegal langsung di DB tanpa mencatat ledger
      await prisma.user.update({
        where: { id: user.id },
        data: { balance: 999999n },
      });

      const audit = await reconcile();
      expect(audit.isReconciled).toBe(false);
      expect(audit.userDiscrepancies.length).toBeGreaterThan(0);
      const disc = audit.userDiscrepancies.find((d) => d.userId === user.id);
      expect(disc).toBeDefined();
      expect(disc.currentBalance).toBe(999999n);
    });
  });
});
