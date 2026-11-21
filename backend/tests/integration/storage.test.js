// =============================================================================
// Integration Tests: Storage, File Assets & Shipment Proof (Prompt 10)
// =============================================================================

const request = require('supertest');
const sharp = require('sharp');
const fs = require('fs');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');
const { getStorageProvider } = require('../../src/providers/storage');
const fileService = require('../../src/services/file.service');

describe('Storage, File Assets & Shipment Proof System (Prompt 10)', () => {
  let app;
  let buyer;
  let seller;
  let stranger;
  let admin;
  let buyerToken;
  let sellerToken;
  let strangerToken;
  let adminToken;

  let validJpg;
  let validPng;
  let validWebp;

  beforeAll(async () => {
    app = createApp();
    await resetDb();

    // Generate genuine valid image buffers using sharp
    validJpg = await sharp({
      create: { width: 120, height: 120, channels: 3, background: { r: 255, g: 0, b: 0 } },
    })
      .jpeg()
      .toBuffer();

    validPng = await sharp({
      create: {
        width: 120,
        height: 120,
        channels: 4,
        background: { r: 0, g: 255, b: 0, alpha: 1 },
      },
    })
      .png()
      .toBuffer();

    validWebp = await sharp({
      create: { width: 120, height: 120, channels: 3, background: { r: 0, g: 0, b: 255 } },
    })
      .webp()
      .toBuffer();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();

    buyer = await createUser({
      name: 'Pembeli Satu',
      email: 'buyer@example.com',
      balance: 500000n,
    });
    seller = await createUser({
      name: 'Penjual Satu',
      email: 'seller@example.com',
      balance: 100000n,
    });
    stranger = await createUser({
      name: 'Orang Asing',
      email: 'stranger@example.com',
      balance: 0n,
    });
    admin = await createUser({ name: 'Admin Rekber', email: 'admin@example.com', role: 'ADMIN' });

    buyerToken = tokenFor(buyer);
    sellerToken = tokenFor(seller);
    strangerToken = tokenFor(stranger);
    adminToken = tokenFor(admin);
  });

  // ===========================================================================
  // 1. VALIDASI UPLOAD & SANITASI GAMBAR (MAGIC BYTES & SHARP)
  // ===========================================================================
  describe('1. Validasi Berkas & Sanitasi Gambar (/files)', () => {
    test('Menolak berkas palsu (.exe diganti nama .jpg) melalui pengecekan Magic Bytes (400)', async () => {
      // Fake executable bytes (MZ header)
      const fakeExeBuffer = Buffer.from('4D5A90000300000004000000FFFF0000B8000000', 'hex');

      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', fakeExeBuffer, 'malicious.jpg');

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/magic bytes|tidak cocok|tidak valid/i);
    });

    test('Menolak unggahan melebihi batas ukuran 5 MB (400)', async () => {
      // 5.2 MB buffer
      const oversizedBuffer = Buffer.alloc(5.2 * 1024 * 1024, 0xff);

      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', oversizedBuffer, 'oversized.jpg');

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/melebihi batas maksimal 5 MB/i);
    });

    test('Menolak jika field purpose tidak diisi atau tidak valid (400)', async () => {
      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'INVALID_PURPOSE')
        .attach('file', validJpg, 'sample.jpg');

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/purpose.*tidak valid/i);
    });

    test('Sukses mengunggah gambar JPG/PNG/WebP asli dan menyimpan FileAsset (201)', async () => {
      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validJpg, 'resi.jpg');

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.purpose).toBe('SHIPMENT_PROOF');
      expect(res.body.data.mime).toBe('image/jpeg');
      expect(res.body.data.sha256).toBeDefined();

      const resWebp = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validWebp, 'resi.webp');
      expect(resWebp.status).toBe(201);
      expect(resWebp.body.data.mime).toBe('image/webp');

      // Verifikasi di database
      const dbFile = await prisma.fileAsset.findUnique({
        where: { id: res.body.data.id },
      });
      expect(dbFile).not.toBeNull();
      expect(dbFile.ownerId).toBe(seller.id);
      expect(dbFile.storageKey).toMatch(/^shipment_proof\//);
    });

    test('EXIF metadata terbuang setelah diproses oleh sharp', async () => {
      // Generate JPG with dummy EXIF metadata
      const imageWithExif = await sharp({
        create: { width: 100, height: 100, channels: 3, background: { r: 100, g: 100, b: 100 } },
      })
        .withMetadata({
          exif: {
            IFD0: {
              Software: 'SecretCameraApp',
            },
          },
        })
        .jpeg()
        .toBuffer();

      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', imageWithExif, 'camera.jpg');

      expect(res.status).toBe(201);

      // Baca berkas yang tersimpan dan periksa metadatanya
      const storage = getStorageProvider();
      const dbFile = await prisma.fileAsset.findUnique({ where: { id: res.body.data.id } });
      const filePath = storage.getFilePath(dbFile.storageKey);
      const savedBuffer = fs.readFileSync(filePath);

      const metadata = await sharp(savedBuffer).metadata();
      // EXIF metadata harus tidak ada (undefined)
      expect(metadata.exif).toBeUndefined();
    });
  });

  // ===========================================================================
  // 2. AKSES BERKAS & URL BERTANDA TANGAN (/files/:id/url)
  // ===========================================================================
  describe('2. Otorisasi Akses Berkas & URL Bertanda Tangan', () => {
    let fileAsset;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validJpg, 'bukti.jpg');

      fileAsset = res.body.data;
    });

    test('Pemilik berkas dapat memperoleh URL bertanda tangan (200)', async () => {
      const res = await request(app)
        .get(`/api/files/${fileAsset.id}/url`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('url');
      expect(res.body.data.expiresIn).toBe(300);
    });

    test('Admin dapat memperoleh URL bertanda tangan untuk semua berkas (200)', async () => {
      const res = await request(app)
        .get(`/api/files/${fileAsset.id}/url`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('url');
    });

    test('Pengguna lain yang bukan peserta transaksi ditolak (403 Forbidden)', async () => {
      const res = await request(app)
        .get(`/api/files/${fileAsset.id}/url`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/akses ditolak|tidak memiliki izin/i);
    });

    test('Pembeli dalam transaksi terkait diizinkan mengakses URL bukti pengiriman setelah diserahkan (200)', async () => {
      // Buat transaksi status PAID
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'PAID',
      });

      // Penjual menyerahkan bukti pengiriman yang memuat fileAsset.id
      await request(app)
        .post(`/api/transactions/${tx.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          courier: 'JNE',
          trackingNumber: 'JNE12345678',
          fileIds: [fileAsset.id],
        });

      // Sekarang pembeli transaksi tersebut berhak mengakses URL berkas
      const res = await request(app)
        .get(`/api/files/${fileAsset.id}/url`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('url');
    });
  });

  // ===========================================================================
  // 3. UNDUHAN BERKAS LOKAL BERTANDA TANGAN (/api/files/download/*)
  // ===========================================================================
  describe('3. Unduhan Berkas Lokal dengan Tanda Tangan HMAC', () => {
    let fileAsset;
    let signedUrl;

    beforeEach(async () => {
      const uploadRes = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validPng, 'resi.png');

      fileAsset = uploadRes.body.data;

      const urlRes = await request(app)
        .get(`/api/files/${fileAsset.id}/url`)
        .set('Authorization', `Bearer ${sellerToken}`);

      signedUrl = urlRes.body.data.url;
    });

    test('Berhasil mengunduh berkas dengan URL bertanda tangan yang valid (200)', async () => {
      const res = await request(app).get(signedUrl);

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toMatch(/image\/png/i);
      expect(res.body).toBeInstanceOf(Buffer);
    });

    test('Menolak jika signature HMAC diubah / dipalsukan (403)', async () => {
      const tamperedUrl = signedUrl.replace(/signature=[0-9a-f]+/, 'signature=deadbeef12345678');
      const res = await request(app).get(tamperedUrl);

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/tanda tangan url tidak valid/i);
    });

    test('Menolak jika timestamp expires sudah kedaluwarsa (403)', async () => {
      const storage = getStorageProvider();
      // Generate URL with expiration 10 seconds in the past
      const expiredUrl = await storage.getSignedUrl({
        key: (await prisma.fileAsset.findUnique({ where: { id: fileAsset.id } })).storageKey,
        expiresInSeconds: -10,
      });

      const res = await request(app).get(expiredUrl);

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/kedaluwarsa/i);
    });
  });

  // ===========================================================================
  // 4. BUKTI PENGIRIMAN (POST /transactions/:id/shipment)
  // ===========================================================================
  describe('4. Penyerahan Bukti Pengiriman (POST /transactions/:id/shipment)', () => {
    let txPaid;

    beforeEach(async () => {
      txPaid = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'PAID',
        amount: 250000,
      });
    });

    test('PUT /transactions/:id/status menolak target SHIPPED dan mengarahkan ke endpoint shipment (400)', async () => {
      const res = await request(app)
        .put(`/api/transactions/${txPaid.id}/status`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ status: 'SHIPPED' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/endpoint pengiriman/i);
    });

    test('Wajib menyertakan minimal satu bukti pengiriman: berkas, kurir+resi, atau catatan (400)', async () => {
      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({}); // Kosong tanpa bukti

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/minimal satu bukti pengiriman/i);
    });

    test('Sukses dengan kurir dan nomor resi fisik: status berubah SHIPPED & autoReleaseAt terisi (200)', async () => {
      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          courier: 'SiCepat',
          trackingNumber: '001234567890',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('SHIPPED');
      expect(res.body.data.shippedAt).toBeDefined();
      expect(res.body.data.autoReleaseAt).toBeDefined();
      expect(res.body.data.shipmentProof).toBeDefined();
      expect(res.body.data.shipmentProof.courier).toBe('SiCepat');
      expect(res.body.data.shipmentProof.trackingNumber).toBe('001234567890');
    });

    test('Sukses dengan catatan pengiriman (produk digital / akun) (200)', async () => {
      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          note: 'Akun premium telah dikirimkan via email pembeli.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('SHIPPED');
      expect(res.body.data.shipmentProof.note).toMatch(/akun premium/i);
    });

    test('Sukses dengan unggahan berkas bukti pengiriman (fileIds) (200)', async () => {
      // Upload file terlebih dahulu
      const uploadRes = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${sellerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validJpg, 'resi.jpg');

      const fileId = uploadRes.body.data.id;

      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          fileIds: [fileId],
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('SHIPPED');
      expect(res.body.data.shipmentProof.fileIds).toContain(fileId);
    });

    test('Menolak jika fileId bukan milik penjual atau tujuannya bukan SHIPMENT_PROOF (400)', async () => {
      // Stranger uploads a file
      const strangerFileRes = await request(app)
        .post('/api/files')
        .set('Authorization', `Bearer ${strangerToken}`)
        .field('purpose', 'SHIPMENT_PROOF')
        .attach('file', validJpg, 'stranger.jpg');

      const strangerFileId = strangerFileRes.body.data.id;

      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          fileIds: [strangerFileId],
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/tidak valid atau bukan milik anda/i);
    });

    test('Ditolak jika bukan penjual yang menyerahkan bukti pengiriman (403)', async () => {
      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ courier: 'JNE', trackingNumber: 'JNE12345' });

      expect(res.status).toBe(403);
      expect(res.body.message).toMatch(/hanya penjual/i);
    });

    test('Ditolak jika status transaksi bukan PAID (400)', async () => {
      // Transaksi masih PENDING
      const txPending = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'PENDING',
      });

      const res = await request(app)
        .post(`/api/transactions/${txPending.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ courier: 'JNE', trackingNumber: 'JNE12345' });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/hanya dapat diserahkan saat status transaksi PAID/i);
    });

    test('GET /transactions/:id menyertakan ringkasan shipmentProof tanpa URL file', async () => {
      await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ courier: 'J&T', trackingNumber: 'JT112233' });

      const res = await request(app)
        .get(`/api/transactions/${txPaid.id}`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.shipmentProof).toBeDefined();
      expect(res.body.data.shipmentProof.courier).toBe('J&T');
      expect(res.body.data.shipmentProof.trackingNumber).toBe('JT112233');
      // Tidak menyertakan URL file langsung di ringkasan
      expect(res.body.data.shipmentProof).not.toHaveProperty('url');
      expect(res.body.data.shipmentProof).not.toHaveProperty('signedUrl');
    });

    test('Atomisitas: jika pembaruan status transaksi gagal, bukti pengiriman tidak tersimpan', async () => {
      // Simulasi race condition: status transaksi diubah sebelum shipment dieksekusi
      await prisma.transaction.update({
        where: { id: txPaid.id },
        data: { status: 'CANCELLED' },
      });

      const res = await request(app)
        .post(`/api/transactions/${txPaid.id}/shipment`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ courier: 'JNE', trackingNumber: 'JNE99999' });

      expect(res.status).toBe(400);

      // Verifikasi di DB: tidak ada ShipmentProof yang tersimpan
      const proofCount = await prisma.shipmentProof.count({
        where: { transactionId: txPaid.id },
      });
      expect(proofCount).toBe(0);
    });
  });

  // ===========================================================================
  // 5. PEMBERSIHAN BERKAS YATIM (cleanupOrphanFiles)
  // ===========================================================================
  describe('5. Pembersihan Berkas Yatim (cleanupOrphanFiles)', () => {
    test('Membersihkan berkas tanpa referensi yang berumur lebih dari 24 jam', async () => {
      // 1. Berkas yatim tua (> 24 jam)
      const orphanOld = await prisma.fileAsset.create({
        data: {
          ownerId: seller.id,
          purpose: 'SHIPMENT_PROOF',
          storageKey: 'shipment_proof/orphan_old.jpg',
          mime: 'image/jpeg',
          size: 1024,
          sha256: 'abc123',
          createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000), // 25 jam yang lalu
        },
      });

      // 2. Berkas baru (< 24 jam) tanpa referensi
      const freshFile = await prisma.fileAsset.create({
        data: {
          ownerId: seller.id,
          purpose: 'SHIPMENT_PROOF',
          storageKey: 'shipment_proof/fresh.jpg',
          mime: 'image/jpeg',
          size: 1024,
          sha256: 'def456',
          createdAt: new Date(),
        },
      });

      // 3. Berkas tua (> 24 jam) yang TERIKAT pada ShipmentProof
      const referencedOld = await prisma.fileAsset.create({
        data: {
          ownerId: seller.id,
          purpose: 'SHIPMENT_PROOF',
          storageKey: 'shipment_proof/referenced_old.jpg',
          mime: 'image/jpeg',
          size: 1024,
          sha256: 'ghi789',
          createdAt: new Date(Date.now() - 30 * 60 * 60 * 1000),
        },
      });

      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'SHIPPED',
      });
      await prisma.shipmentProof.create({
        data: {
          transactionId: tx.id,
          submittedById: seller.id,
          fileIds: [referencedOld.id],
        },
      });

      // Jalankan fungsi pembersihan
      const cleanupResult = await fileService.cleanupOrphanFiles();

      expect(cleanupResult.cleanedCount).toBe(1);
      expect(cleanupResult.orphanIds).toContain(orphanOld.id);

      // Verifikasi status di database
      const dbOrphanOld = await prisma.fileAsset.findUnique({ where: { id: orphanOld.id } });
      expect(dbOrphanOld.deletedAt).not.toBeNull();

      const dbFresh = await prisma.fileAsset.findUnique({ where: { id: freshFile.id } });
      expect(dbFresh.deletedAt).toBeNull(); // Tidak dihapus karena masih baru

      const dbReferencedOld = await prisma.fileAsset.findUnique({
        where: { id: referencedOld.id },
      });
      expect(dbReferencedOld.deletedAt).toBeNull(); // Tidak dihapus karena ada referensi
    });
  });
});
