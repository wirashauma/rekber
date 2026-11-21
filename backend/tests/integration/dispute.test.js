// =============================================================================
// Integration Tests: Dispute Management & Resolution (Prompt 11)
// =============================================================================

const request = require('supertest');
const sharp = require('sharp');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');

describe('Dispute Management & Resolution System (Prompt 11)', () => {
  let app;
  let buyer;
  let seller;
  let stranger;
  let admin;
  let buyerToken;
  let sellerToken;
  let strangerToken;
  let adminToken;

  let validImageBuffer;

  beforeAll(async () => {
    app = createApp();
    await resetDb();

    validImageBuffer = await sharp({
      create: { width: 100, height: 100, channels: 3, background: { r: 255, g: 0, b: 0 } },
    })
      .jpeg()
      .toBuffer();
  });

  beforeEach(async () => {
    await resetDb();

    buyer = await createUser({ name: 'Buyer Dispute', balance: 500000 });
    seller = await createUser({ name: 'Seller Dispute', balance: 100000 });
    stranger = await createUser({ name: 'Stranger User', balance: 50000 });
    admin = await createUser({ name: 'Admin Dispute', role: 'ADMIN' });

    buyerToken = tokenFor(buyer);
    sellerToken = tokenFor(seller);
    strangerToken = tokenFor(stranger);
    adminToken = tokenFor(admin);
  });

  afterAll(async () => {
    await disconnectDb();
  });

  // Helper to create uploaded file asset
  const uploadDisputeFile = async (user, token) => {
    const res = await request(app)
      .post('/api/files')
      .set('Authorization', `Bearer ${token}`)
      .field('purpose', 'DISPUTE_EVIDENCE')
      .attach('file', validImageBuffer, 'dispute-proof.jpg');

    expect(res.status).toBe(201);
    return res.body.data;
  };

  describe('1. Pengajuan Sengketa (POST /transactions/:id/dispute)', () => {
    it('Pembeli dapat mengajukan sengketa saat transaksi berstatus PAID', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 200000,
        buyerFee: 2000,
        sellerFee: 2000,
        status: 'PAID',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Barang tidak kunjung dikirim oleh penjual setelah 3 hari berturut-turut.',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('OPEN');
      expect(res.body.data.reason).toBe('NOT_RECEIVED');
      expect(res.body.data.openedById).toBe(buyer.id);

      // Verify transaction status changed to DISPUTED
      const updatedTx = await prisma.transaction.findUnique({ where: { id: tx.id } });
      expect(updatedTx.status).toBe('DISPUTED');
      expect(updatedTx.autoReleaseAt).toBeNull();
    });

    it('Pembeli dapat mengajukan sengketa saat transaksi berstatus SHIPPED dan autoReleaseAt dikosongkan', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 150000,
        status: 'SHIPPED',
      });

      // Set initial autoReleaseAt
      await prisma.transaction.update({
        where: { id: tx.id },
        data: { autoReleaseAt: new Date(Date.now() + 72 * 3600 * 1000) },
      });

      const fileAsset = await uploadDisputeFile(buyer, buyerToken);

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'DEFECTIVE',
          description: 'Barang yang saya terima rusak parah dan kemasan robek total saat unboxing.',
          fileIds: [fileAsset.id],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('OPEN');
      expect(res.body.data.evidences).toHaveLength(1);
      expect(res.body.data.evidences[0].fileIds).toContain(fileAsset.id);

      const updatedTx = await prisma.transaction.findUnique({ where: { id: tx.id } });
      expect(updatedTx.status).toBe('DISPUTED');
      expect(updatedTx.autoReleaseAt).toBeNull(); // auto-release dibatalkan
    });

    it('Penjual ditolak saat mencoba mengajukan sengketa (403 Forbidden)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          reason: 'OTHER',
          description: 'Penjual ingin mengajukan sengketa karena pembeli tidak kooperatif.',
        });

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/Hanya pembeli/i);
    });

    it('Pihak ketiga ditolak saat mencoba mengajukan sengketa (403 Forbidden)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${strangerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Pihak asing mencoba menyengketakan transaksi orang lain.',
        });

      expect(res.status).toBe(403);
    });

    it('Ditolak jika transaksi masih berstatus PENDING (400 Bad Request)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PENDING',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'OTHER',
          description: 'Belum bayar tapi mencoba menyengketakan transaksi sekarang.',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/PAID atau SHIPPED/i);
    });

    it('Ditolak jika transaksi sudah COMPLETED atau CANCELLED (400 Bad Request)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'COMPLETED',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_AS_DESCRIBED',
          description: 'Transaksi sudah selesai tetapi dicoba disengketakan kembali.',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/PAID atau SHIPPED/i);
    });

    it('Validasi enum: alasan (reason) tidak valid ditolak (422)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'INVALID_REASON',
          description: 'Deskripsi sengketa yang cukup panjang untuk validasi.',
        });

      expect(res.status).toBe(422);
    });

    it('Validasi karakter: deskripsi kurang dari 20 karakter ditolak (422)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Terlalu pendek',
        });

      expect(res.status).toBe(422);
    });

    it('Pengajuan sengketa ganda pada transaksi yang sama menghasilkan 409 Conflict', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      // First dispute
      const res1 = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Pengajuan pertama sengketa transaksi karena barang belum sampai.',
        });
      expect(res1.status).toBe(201);

      // Second dispute attempt
      const res2 = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'OTHER',
          description: 'Pengajuan kedua sengketa transaksi yang sama seharusnya ditolak 409.',
        });

      expect(res2.status).toBe(409);
      expect(res2.body.message).toMatch(/sudah ada|sudah disengketakan/i);
    });

    it('Mengajukan dengan fileIds milik user lain ditolak (400 Bad Request)', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PAID',
      });

      // Upload file as stranger
      const strangerFile = await uploadDisputeFile(stranger, strangerToken);

      const res = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Pembeli memakai fileId yang diunggah oleh pengguna lain.',
          fileIds: [strangerFile.id],
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/bukan milik Anda/i);
    });
  });

  describe('2. Penyerahan Bukti Sengketa (POST /disputes/:id/evidence)', () => {
    let disputedTx;
    let disputeId;

    beforeEach(async () => {
      disputedTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 250000,
        buyerFee: 2500,
        sellerFee: 2500,
        status: 'SHIPPED',
      });

      const disputeRes = await request(app)
        .post(`/api/transactions/${disputedTx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_AS_DESCRIBED',
          description: 'Warna barang yang dikirim tidak sesuai dengan kesepakatan awal.',
        });

      disputeId = disputeRes.body.data.id;
    });

    it('Pembeli dapat menambahkan bukti tambahan berupa catatan dan berkas', async () => {
      const file = await uploadDisputeFile(buyer, buyerToken);

      const res = await request(app)
        .post(`/api/disputes/${disputeId}/evidence`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          note: 'Berikut adalah foto perbandingan warna barang asli vs etalase.',
          fileIds: [file.id],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.note).toContain('foto perbandingan');
      expect(res.body.data.fileIds).toContain(file.id);
      expect(res.body.data.submittedBy.id).toBe(buyer.id);
    });

    it('Penjual dapat menambahkan bukti pembelaan', async () => {
      const file = await uploadDisputeFile(seller, sellerToken);

      const res = await request(app)
        .post(`/api/disputes/${disputeId}/evidence`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          note: 'Saya sudah mengonfirmasi warna sebelum pengiriman lewat chat.',
          fileIds: [file.id],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.submittedBy.id).toBe(seller.id);
    });

    it('Pihak ketiga ditolak saat menambahkan bukti (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/disputes/${disputeId}/evidence`)
        .set('Authorization', `Bearer ${strangerToken}`)
        .send({
          note: 'Pihak asing ikut campur dalam sengketa.',
        });

      expect(res.status).toBe(403);
    });

    it('Menegakkan batas maksimal 10 bukti per pihak', async () => {
      // Submit 10 evidences as seller
      for (let i = 1; i <= 10; i++) {
        const res = await request(app)
          .post(`/api/disputes/${disputeId}/evidence`)
          .set('Authorization', `Bearer ${sellerToken}`)
          .send({
            note: `Bukti pembelaan penjual nomor urut ke-${i}`,
          });
        expect(res.status).toBe(201);
      }

      // 11th evidence should be rejected
      const overLimitRes = await request(app)
        .post(`/api/disputes/${disputeId}/evidence`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          note: 'Bukti ke-11 yang melebihi batas kuota.',
        });

      expect(overLimitRes.status).toBe(400);
      expect(overLimitRes.body.message).toMatch(/Maksimal 10 bukti/i);
    });

    it('Ditolak jika mengirim bukti tanpa catatan (note) dan tanpa berkas (fileIds) (422)', async () => {
      const res = await request(app)
        .post(`/api/disputes/${disputeId}/evidence`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({});

      expect(res.status).toBe(422);
    });
  });

  describe('3. Akses Data Sengketa (GET /disputes/:id & GET /transactions/:id/dispute)', () => {
    let disputedTx;
    let disputeId;

    beforeEach(async () => {
      disputedTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 300000,
        status: 'PAID',
      });

      const disputeRes = await request(app)
        .post(`/api/transactions/${disputedTx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_RECEIVED',
          description: 'Pembeli belum menerima barang sama sekali sampai batas waktu.',
        });

      disputeId = disputeRes.body.data.id;
    });

    it('Peserta transaksi (pembeli & penjual) dan admin dapat melihat sengketa', async () => {
      // Buyer
      const resBuyer = await request(app)
        .get(`/api/disputes/${disputeId}`)
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(resBuyer.status).toBe(200);
      expect(resBuyer.body.data.id).toBe(disputeId);

      // Seller
      const resSeller = await request(app)
        .get(`/api/disputes/${disputeId}`)
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(resSeller.status).toBe(200);
      expect(resSeller.body.data.id).toBe(disputeId);

      // Admin
      const resAdmin = await request(app)
        .get(`/api/disputes/${disputeId}`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(resAdmin.status).toBe(200);
      expect(resAdmin.body.data.id).toBe(disputeId);
    });

    it('Pihak ketiga ditolak saat mengakses sengketa (403 Forbidden)', async () => {
      const res = await request(app)
        .get(`/api/disputes/${disputeId}`)
        .set('Authorization', `Bearer ${strangerToken}`);
      expect(res.status).toBe(403);
    });

    it('GET /api/transactions/:id/dispute mengembalikan sengketa untuk peserta', async () => {
      const res = await request(app)
        .get(`/api/transactions/${disputedTx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(disputeId);
    });
  });

  describe('4. Review & Resolusi Admin (Admin Dispute Routes)', () => {
    let disputedTx;
    let disputeId;

    beforeEach(async () => {
      disputedTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 1000000,
        buyerFee: 10000,
        sellerFee: 10000,
        heldAmount: 1010000,
        status: 'SHIPPED',
      });

      const disputeRes = await request(app)
        .post(`/api/transactions/${disputedTx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'DEFECTIVE',
          description:
            'Barang elektronik yang diterima mengalami korsleting saat pertama dinyalakan.',
        });

      disputeId = disputeRes.body.data.id;
    });

    it('User non-admin ditolak saat mengakses rute admin sengketa (403)', async () => {
      const res = await request(app)
        .get('/api/admin/disputes')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(res.status).toBe(403);
    });

    it('Admin dapat melihat daftar sengketa dan filter berdasarkan status', async () => {
      const res = await request(app)
        .get('/api/admin/disputes?status=OPEN')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data[0].status).toBe('OPEN');
    });

    it('Admin dapat mengubah status OPEN menjadi UNDER_REVIEW', async () => {
      const res = await request(app)
        .post(`/api/admin/disputes/${disputeId}/review`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('UNDER_REVIEW');

      // Review ulang saat sudah UNDER_REVIEW ditolak
      const repeatRes = await request(app)
        .post(`/api/admin/disputes/${disputeId}/review`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(repeatRes.status).toBe(400);
    });

    it('Validasi resolusi admin: catatan minimal 10 karakter dan keputusan valid (422)', async () => {
      // Catatan terlalu pendek
      const shortNoteRes = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'RELEASE_TO_SELLER',
          note: 'Pendek',
        });
      expect(shortNoteRes.status).toBe(422);

      // Keputusan tidak valid
      const invalidDecisionRes = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'SPLIT_MONEY',
          note: 'Catatan resolusi yang cukup panjang memenuhi syarat.',
        });
      expect(invalidDecisionRes.status).toBe(422);
    });

    it('Resolusi RELEASE_TO_SELLER: dana bergerak ke penjual, fee ke platform, transaksi COMPLETED', async () => {
      const initialSeller = await prisma.user.findUnique({ where: { id: seller.id } });
      const initialSellerBalance = initialSeller.balance;

      const res = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'RELEASE_TO_SELLER',
          note: 'Bukti dari penjual valid, barang terbukti sesuai deskripsi sebelum dikirim.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('RESOLVED_SELLER');
      expect(res.body.data.resolvedById).toBe(admin.id);

      // Verifikasi status transaksi
      const updatedTx = await prisma.transaction.findUnique({ where: { id: disputedTx.id } });
      expect(updatedTx.status).toBe('COMPLETED');
      expect(updatedTx.heldAmount).toBe(0n);

      // Verifikasi saldo penjual bertambah: amount - sellerFee = 1.000.000 - 10.000 = 990.000
      const finalSeller = await prisma.user.findUnique({ where: { id: seller.id } });
      expect(finalSeller.balance).toBe(initialSellerBalance + 990000n);

      // Verifikasi ledger entry platform fee tercatat
      const feeEntry = await prisma.ledgerEntry.findFirst({
        where: {
          transactionId: disputedTx.id,
          type: 'PLATFORM_FEE',
        },
      });
      expect(feeEntry).not.toBeNull();
      expect(feeEntry.amount).toBe(20000n); // buyerFee (10.000) + sellerFee (10.000)
    });

    it('Resolusi REFUND_TO_BUYER: dana dikembalikan penuh ke pembeli, transaksi REFUNDED', async () => {
      const initialBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
      const initialBuyerBalance = initialBuyer.balance;

      const res = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'REFUND_TO_BUYER',
          note: 'Bukti cacat unboxing pembeli sah, pengembalian dana penuh disetujui.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('RESOLVED_BUYER');

      // Verifikasi status transaksi
      const updatedTx = await prisma.transaction.findUnique({ where: { id: disputedTx.id } });
      expect(updatedTx.status).toBe('REFUNDED');
      expect(updatedTx.heldAmount).toBe(0n);

      // Verifikasi saldo pembeli kembali penuh: amount + buyerFee = 1.000.000 + 10.000 = 1.010.000
      const finalBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
      expect(finalBuyer.balance).toBe(initialBuyerBalance + 1010000n);

      // Verifikasi saldo penjual tidak berubah
      const finalSeller = await prisma.user.findUnique({ where: { id: seller.id } });
      expect(finalSeller.balance).toBe(seller.balance);
    });

    it('Resolusi ganda menghasilkan 409 Conflict', async () => {
      // First resolve
      const res1 = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'RELEASE_TO_SELLER',
          note: 'Resolusi pertama oleh admin.',
        });
      expect(res1.status).toBe(200);

      // Second resolve attempt
      const res2 = await request(app)
        .post(`/api/admin/disputes/${disputeId}/resolve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          decision: 'REFUND_TO_BUYER',
          note: 'Mencoba resolusi kedua pada sengketa yang sudah selesai.',
        });
      expect(res2.status).toBe(409);
    });

    it('Resolusi ganda paralel (konkurensi): tepat satu yang berhasil dan dana tidak bocor', async () => {
      // Send two concurrent resolve requests
      const [resA, resB] = await Promise.all([
        request(app)
          .post(`/api/admin/disputes/${disputeId}/resolve`)
          .set('Authorization', `Bearer ${adminToken}`)
          .send({
            decision: 'RELEASE_TO_SELLER',
            note: 'Eksekusi paralel A untuk rilis dana ke penjual.',
          }),
        request(app)
          .post(`/api/admin/disputes/${disputeId}/resolve`)
          .set('Authorization', `Bearer ${adminToken}`)
          .send({
            decision: 'REFUND_TO_BUYER',
            note: 'Eksekusi paralel B untuk pengembalian dana ke pembeli.',
          }),
      ]);

      const statuses = [resA.status, resB.status];
      expect(statuses).toContain(200);
      expect(statuses).toContain(409);

      // Exactly 1 success, 1 conflict
      const successCount = statuses.filter((s) => s === 200).length;
      const conflictCount = statuses.filter((s) => s === 409).length;
      expect(successCount).toBe(1);
      expect(conflictCount).toBe(1);

      // Invariant: heldAmount must be exactly 0
      const txAfter = await prisma.transaction.findUnique({ where: { id: disputedTx.id } });
      expect(txAfter.heldAmount).toBe(0n);
    });
  });

  describe('5. Kebijakan Akses Berkas Bukti (fileAccessPolicies.DISPUTE_EVIDENCE)', () => {
    it('Pembeli, Penjual, dan Admin dapat mengakses URL unduh bukti sengketa; Pihak ketiga ditolak 403', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 200000,
        status: 'PAID',
      });

      // 1. Upload file as buyer
      const buyerFile = await uploadDisputeFile(buyer, buyerToken);

      // 2. Open dispute with this file
      const disputeRes = await request(app)
        .post(`/api/transactions/${tx.id}/dispute`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          reason: 'NOT_AS_DESCRIBED',
          description: 'Barang tidak sesuai deskripsi, berikut berkas bukti terlampir.',
          fileIds: [buyerFile.id],
        });
      expect(disputeRes.status).toBe(201);

      // 3. Buyer (owner) requests signed URL -> 200
      const buyerUrlRes = await request(app)
        .get(`/api/files/${buyerFile.id}/url`)
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(buyerUrlRes.status).toBe(200);
      expect(buyerUrlRes.body.data.url).toBeDefined();

      // 4. Seller (participant) requests signed URL -> 200
      const sellerUrlRes = await request(app)
        .get(`/api/files/${buyerFile.id}/url`)
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(sellerUrlRes.status).toBe(200);
      expect(sellerUrlRes.body.data.url).toBeDefined();

      // 5. Admin requests signed URL -> 200
      const adminUrlRes = await request(app)
        .get(`/api/files/${buyerFile.id}/url`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(adminUrlRes.status).toBe(200);
      expect(adminUrlRes.body.data.url).toBeDefined();

      // 6. Stranger requests signed URL -> 403 Forbidden
      const strangerUrlRes = await request(app)
        .get(`/api/files/${buyerFile.id}/url`)
        .set('Authorization', `Bearer ${strangerToken}`);
      expect(strangerUrlRes.status).toBe(403);
    });
  });
});
