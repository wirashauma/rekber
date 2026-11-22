// =============================================================================
// Chat & Realtime Messaging Integration Tests (Prompt 13)
// =============================================================================

const http = require('http');
const ioClient = require('socket.io-client');
const request = require('supertest');
const app = require('../../src/app');
const { initSocket, closeSocket } = require('../../src/socket');
const {
  createUser,
  tokenFor,
  createTransaction,
  createDispute,
  resetDb,
  disconnectDb,
  prisma,
} = require('../helpers');
const { resetMessageRateLimit } = require('../../src/middlewares/chatRateLimit.middleware');
const { clearNotificationThrottle } = require('../../src/services/chat.service');
const events = require('../../src/notifications/events');

describe('Chat & Realtime Messaging System (Prompt 13)', () => {
  let server;
  let serverPort;
  let buyer;
  let seller;
  let stranger;
  let admin;
  let buyerToken;
  let sellerToken;
  let strangerToken;
  let adminToken;
  let transaction;

  beforeAll(async () => {
    // Start an HTTP server with Socket.IO attached on a random port
    server = http.createServer(app);
    initSocket(server);
    await new Promise((resolve) => {
      server.listen(0, () => {
        serverPort = server.address().port;
        resolve();
      });
    });
  });

  afterAll(async () => {
    await closeSocket();
    await new Promise((resolve) => server.close(resolve));
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();
    resetMessageRateLimit();
    clearNotificationThrottle();

    buyer = await createUser({ name: 'Buyer User', balance: 500000 });
    seller = await createUser({ name: 'Seller User', balance: 100000 });
    stranger = await createUser({ name: 'Stranger User', balance: 50000 });
    admin = await createUser({ name: 'Platform Admin', role: 'ADMIN' });

    buyerToken = tokenFor(buyer);
    sellerToken = tokenFor(seller);
    strangerToken = tokenFor(stranger);
    adminToken = tokenFor(admin);

    transaction = await createTransaction({
      buyerId: buyer.id,
      sellerId: seller.id,
      amount: 150000,
      status: 'PAID',
    });
  });

  // Helper function to create authenticated socket client
  const createSocketClient = (token) => {
    return ioClient(`http://localhost:${serverPort}`, {
      auth: { token },
      transports: ['websocket'],
      autoConnect: true,
      reconnection: false,
    });
  };

  // ===========================================================================
  // 1. REST ACCESS CONTROL & PARTICIPANT ISOLATION
  // ===========================================================================
  describe('1. Kontrol Akses & Partisipan Chat (REST)', () => {
    it('Pembeli dan penjual dapat membaca dan mengirim pesan', async () => {
      const sendRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: 'Halo, pesanan saya kapan dikirim?' });

      expect(sendRes.status).toBe(201);
      expect(sendRes.body.success).toBe(true);
      expect(sendRes.body.data.body).toBe('Halo, pesanan saya kapan dikirim?');
      expect(sendRes.body.data.senderId).toBe(buyer.id);

      const getRes = await request(app)
        .get(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(getRes.status).toBe(200);
      expect(getRes.body.success).toBe(true);
      expect(getRes.body.messages.length).toBe(1);
      expect(getRes.body.messages[0].body).toBe('Halo, pesanan saya kapan dikirim?');
    });

    it('Pihak ketiga (non-peserta) ditolak saat membaca atau mengirim pesan (403 Forbidden)', async () => {
      const sendRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${strangerToken}`)
        .send({ type: 'TEXT', body: 'Pesan penyusup' });

      expect(sendRes.status).toBe(403);
      expect(sendRes.body.message).toContain('tidak memiliki akses');

      const getRes = await request(app)
        .get(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(getRes.status).toBe(403);
    });

    it('Admin DITOLAK mengakses chat jika status transaksi BUKAN DISPUTED (403)', async () => {
      const getRes = await request(app)
        .get(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(getRes.status).toBe(403);
      expect(getRes.body.message).toContain('status sengketa (DISPUTED)');

      const sendRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ type: 'TEXT', body: 'Pesan admin' });

      expect(sendRes.status).toBe(403);
    });

    it('Admin DIIZINKAN mengakses chat saat transaksi berstatus DISPUTED', async () => {
      // Ubah status ke DISPUTED dan buat sengketa
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'DISPUTED' },
      });
      await createDispute({
        transactionId: transaction.id,
        openedById: buyer.id,
        reason: 'NOT_RECEIVED',
      });

      const getRes = await request(app)
        .get(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(getRes.status).toBe(200);
      expect(getRes.body.success).toBe(true);

      const sendRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ type: 'TEXT', body: 'Halo, saya admin yang menangani sengketa ini.' });

      expect(sendRes.status).toBe(201);
      expect(sendRes.body.data.senderId).toBe(admin.id);
    });
  });

  // ===========================================================================
  // 2. TERMINAL TRANSACTION ENFORCEMENT
  // ===========================================================================
  describe('2. Transaksi Terminal: Boleh Dibaca, Ditolak Kirim Pesan Baru', () => {
    it('Transaksi COMPLETED: pesan dapat dibaca, tapi kirim pesan ditolak (400)', async () => {
      // Kirim satu pesan dulu saat masih aktif
      await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ type: 'TEXT', body: 'Terima kasih atas pesanannya.' });

      // Ubah status menjadi COMPLETED (terminal)
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'COMPLETED' },
      });

      // Membaca chat tetap diizinkan
      const getRes = await request(app)
        .get(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(getRes.status).toBe(200);
      expect(getRes.body.messages.length).toBe(1);

      // Mengirim pesan baru harus ditolak
      const sendRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: 'Halo lagi' });

      expect(sendRes.status).toBe(400);
      expect(sendRes.body.message).toContain('selesai atau dibatalkan');
    });

    it('Transaksi CANCELLED dan REFUNDED: kirim pesan baru ditolak (400)', async () => {
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'CANCELLED' },
      });

      const sendCancelled = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: 'Tes kirim' });
      expect(sendCancelled.status).toBe(400);

      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'REFUNDED' },
      });

      const sendRefunded = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ type: 'TEXT', body: 'Tes kirim' });
      expect(sendRefunded.status).toBe(400);
    });
  });

  // ===========================================================================
  // 3. TIPE PESAN & LAMPIRAN GAMBAR (CHAT_IMAGE)
  // ===========================================================================
  describe('3. Tipe Pesan (TEXT, IMAGE, SYSTEM) & Lampiran Gambar', () => {
    it('Pengguna biasa tidak dapat mengirim pesan bertipe SYSTEM secara langsung (400)', async () => {
      const res = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'SYSTEM', body: 'Palsu pesan sistem' });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('hanya dapat dibuat oleh sistem');
    });

    it('Validasi teks: kosong atau melebihi 2000 karakter ditolak (422)', async () => {
      const emptyRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: '   ' });

      expect(emptyRes.status).toBe(422);

      const longText = 'a'.repeat(2001);
      const longRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: longText });

      expect(longRes.status).toBe(422);
    });

    it('Kirim pesan IMAGE dengan file CHAT_IMAGE yang valid berhasil', async () => {
      // Buat fileAsset milik pembeli dengan tujuan CHAT_IMAGE
      const fileAsset = await prisma.fileAsset.create({
        data: {
          ownerId: buyer.id,
          purpose: 'CHAT_IMAGE',
          storageKey: 'chat_images/buyer_test_image.png',
          mime: 'image/png',
          size: 10240,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        },
      });

      const res = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          type: 'IMAGE',
          fileId: fileAsset.id,
          body: 'Ini foto kondisi barang',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.type).toBe('IMAGE');
      expect(res.body.data.fileId).toBe(fileAsset.id);
      expect(res.body.data.body).toBe('Ini foto kondisi barang');
    });

    it('Kirim pesan IMAGE dengan file milik pengguna lain atau bukan CHAT_IMAGE ditolak', async () => {
      const strangerFile = await prisma.fileAsset.create({
        data: {
          ownerId: stranger.id,
          purpose: 'CHAT_IMAGE',
          storageKey: 'chat_images/stranger_img.png',
          mime: 'image/png',
          size: 5000,
          sha256: 'dummy_hash_1',
        },
      });

      const resForeign = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'IMAGE', fileId: strangerFile.id });

      expect(resForeign.status).toBe(403);
      expect(resForeign.body.message).toContain('pemilik berkas');

      const nonChatFile = await prisma.fileAsset.create({
        data: {
          ownerId: buyer.id,
          purpose: 'SHIPMENT_PROOF',
          storageKey: 'proofs/buyer_resi.png',
          mime: 'image/png',
          size: 5000,
          sha256: 'dummy_hash_2',
        },
      });

      const resWrongPurpose = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'IMAGE', fileId: nonChatFile.id });

      expect(resWrongPurpose.status).toBe(400);
      expect(resWrongPurpose.body.message).toContain('CHAT_IMAGE');
    });

    it('Kebijakan Akses Berkas (fileAccessPolicies.CHAT_IMAGE): Pembeli & Penjual diizinkan, Admin hanya saat DISPUTED', async () => {
      const fileService = require('../../src/services/file.service');

      const fileAsset = await prisma.fileAsset.create({
        data: {
          ownerId: seller.id,
          purpose: 'CHAT_IMAGE',
          storageKey: 'chat_images/seller_catalog.png',
          mime: 'image/png',
          size: 15000,
          sha256: 'hash_seller_img',
        },
      });

      await prisma.chatMessage.create({
        data: {
          transactionId: transaction.id,
          senderId: seller.id,
          type: 'IMAGE',
          fileId: fileAsset.id,
        },
      });

      // Penjual (pemilik) dan pembeli dapat mengakses
      const sellerAccess = await fileService.fileAccessPolicies.CHAT_IMAGE(fileAsset, seller);
      const buyerAccess = await fileService.fileAccessPolicies.CHAT_IMAGE(fileAsset, buyer);
      const strangerAccess = await fileService.fileAccessPolicies.CHAT_IMAGE(fileAsset, stranger);

      expect(sellerAccess).toBe(true);
      expect(buyerAccess).toBe(true);
      expect(strangerAccess).toBe(false);

      // Admin saat belum DISPUTED ditolak
      const adminAccessPending = await fileService.fileAccessPolicies.CHAT_IMAGE(fileAsset, admin);
      expect(adminAccessPending).toBe(false);

      // Ubah status ke DISPUTED -> Admin kini diizinkan
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'DISPUTED' },
      });
      const adminAccessDisputed = await fileService.fileAccessPolicies.CHAT_IMAGE(fileAsset, admin);
      expect(adminAccessDisputed).toBe(true);
    });
  });

  // ===========================================================================
  // 4. PAGINATION & RATE LIMITING
  // ===========================================================================
  describe('4. Pagination & Pembatasan Frekuensi (Rate Limit 20/menit)', () => {
    it('Mendukung cursor pagination pada GET /transactions/:id/messages', async () => {
      // Masukkan 5 pesan berurutan
      for (let i = 1; i <= 5; i++) {
        await prisma.chatMessage.create({
          data: {
            transactionId: transaction.id,
            senderId: buyer.id,
            body: `Pesan ${i}`,
          },
        });
      }

      // Ambil halaman pertama: limit 2
      const page1 = await request(app)
        .get(`/api/transactions/${transaction.id}/messages?limit=2`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(page1.status).toBe(200);
      expect(page1.body.messages.length).toBe(2);
      expect(page1.body.hasMore).toBe(true);
      expect(page1.body.nextCursor).toBeDefined();

      // Ambil halaman kedua memakai nextCursor
      const page2 = await request(app)
        .get(`/api/transactions/${transaction.id}/messages?limit=2&cursor=${page1.body.nextCursor}`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(page2.status).toBe(200);
      expect(page2.body.messages.length).toBe(2);
      expect(page2.body.messages[0].id).not.toBe(page1.body.messages[0].id);
    });

    it('Membatasi pengiriman pesan maksimal 20 per menit per user (429 Too Many Requests)', async () => {
      // Kirim 20 pesan secepatnya
      for (let i = 0; i < 20; i++) {
        const res = await request(app)
          .post(`/api/transactions/${transaction.id}/messages`)
          .set('Authorization', `Bearer ${buyerToken}`)
          .send({ type: 'TEXT', body: `Pesan ke-${i + 1}` });

        expect(res.status).toBe(201);
      }

      // Pesan ke-21 harus ditolak dengan status 429
      const overRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'TEXT', body: 'Pesan melebihi kuota limit' });

      expect(overRes.status).toBe(429);
      expect(overRes.body.message).toContain('maksimal 20 pesan per menit');
    });
  });

  // ===========================================================================
  // 5. STATUS BACA (READ STATE)
  // ===========================================================================
  describe('5. Status Baca (ChatReadState)', () => {
    it('POST /transactions/:id/messages/read memperbarui lastReadAt pengguna', async () => {
      const readRes = await request(app)
        .post(`/api/transactions/${transaction.id}/messages/read`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(readRes.status).toBe(200);
      expect(readRes.body.success).toBe(true);
      expect(readRes.body.data.lastReadAt).toBeDefined();

      const recordInDb = await prisma.chatReadState.findUnique({
        where: {
          transactionId_userId: {
            transactionId: transaction.id,
            userId: buyer.id,
          },
        },
      });

      expect(recordInDb).not.toBeNull();
      expect(recordInDb.userId).toBe(buyer.id);
    });
  });

  // ===========================================================================
  // 6. PESAN SYSTEM OTOMATIS SAAT PERUBAHAN STATUS
  // ===========================================================================
  describe('6. Pesan SYSTEM Otomatis pada Perubahan Status Transaksi', () => {
    it('Event perubahan status memanggil chat.postSystem dan memunculkan pesan SYSTEM', async () => {
      // Panggil event onTransactionShipped
      await events.onTransactionShipped(transaction, { trackingNumber: 'JNE12345678' });

      const messages = await prisma.chatMessage.findMany({
        where: {
          transactionId: transaction.id,
          type: 'SYSTEM',
        },
      });

      expect(messages.length).toBeGreaterThanOrEqual(1);
      const shippedMsg = messages.find((m) => m.body.includes('JNE12345678'));
      expect(shippedMsg).toBeDefined();
      expect(shippedMsg.senderId).toBeNull();
    });
  });

  // ===========================================================================
  // 7. REALTIME SOCKET.IO: AUTENTIKASI, ISOLASI ROOM & REALTIME EVENTS
  // ===========================================================================
  describe('7. Socket.IO Realtime: Autentikasi, Isolasi Room & Events', () => {
    it('Handshake: Menolak koneksi socket tanpa token atau token tidak valid', async () => {
      // 1. Tanpa token
      const noTokenSocket = ioClient(`http://localhost:${serverPort}`, {
        transports: ['websocket'],
        autoConnect: false,
      });

      const noTokenErr = await new Promise((resolve) => {
        noTokenSocket.on('connect_error', (err) => resolve(err.message));
        noTokenSocket.connect();
      });
      noTokenSocket.disconnect();
      expect(noTokenErr).toContain('Token tidak disertakan');

      // 2. Token kadaluwarsa / salah
      const badTokenSocket = ioClient(`http://localhost:${serverPort}`, {
        auth: { token: 'invalid_expired_token' },
        transports: ['websocket'],
        autoConnect: false,
      });

      const badTokenErr = await new Promise((resolve) => {
        badTokenSocket.on('connect_error', (err) => resolve(err.message));
        badTokenSocket.connect();
      });
      badTokenSocket.disconnect();
      expect(badTokenErr).toContain('Token tidak valid atau kedaluwarsa');
    });

    it('Koneksi socket berhasil dengan JWT valid dan isolasi room terjamin', async () => {
      const buyerSocket = createSocketClient(buyerToken);
      const strangerSocket = createSocketClient(strangerToken);

      await new Promise((resolve) => buyerSocket.on('connect', resolve));
      await new Promise((resolve) => strangerSocket.on('connect', resolve));

      // 1. Stranger mencoba join room transaksi -> Ditolak
      const strangerJoinResult = await new Promise((resolve) => {
        strangerSocket.emit('join', { transactionId: transaction.id }, resolve);
      });
      expect(strangerJoinResult.success).toBe(false);
      expect(strangerJoinResult.message).toContain('tidak memiliki akses');

      // 2. Pembeli join room transaksi -> Berhasil
      const buyerJoinResult = await new Promise((resolve) => {
        buyerSocket.emit('join', { transactionId: transaction.id }, resolve);
      });
      expect(buyerJoinResult.success).toBe(true);
      expect(buyerJoinResult.room).toBe(`tx:${transaction.id}`);

      buyerSocket.disconnect();
      strangerSocket.disconnect();
    });

    it('Dua klien socket saling kirim pesan realtime (message:new), read (message:read), dan typing', async () => {
      const buyerSocket = createSocketClient(buyerToken);
      const sellerSocket = createSocketClient(sellerToken);

      await new Promise((resolve) => buyerSocket.on('connect', resolve));
      await new Promise((resolve) => sellerSocket.on('connect', resolve));

      // Kedua belah pihak bergabung ke ruang transaksi
      await new Promise((resolve) =>
        buyerSocket.emit('join', { transactionId: transaction.id }, resolve)
      );
      await new Promise((resolve) =>
        sellerSocket.emit('join', { transactionId: transaction.id }, resolve)
      );

      // Penjual mendengar event message:new saat pembeli mengirim pesan
      const buyerMessagePromise = new Promise((resolve) => {
        sellerSocket.on('message:new', (msg) => {
          if (msg.body === 'Halo penjual dari socket') {
            resolve(msg);
          }
        });
      });

      // Pembeli mengirim pesan via socket
      buyerSocket.emit('message:send', {
        transactionId: transaction.id,
        type: 'TEXT',
        body: 'Halo penjual dari socket',
      });

      const receivedMsg = await buyerMessagePromise;
      expect(receivedMsg.body).toBe('Halo penjual dari socket');
      expect(receivedMsg.senderId).toBe(buyer.id);

      // Pengujian event typing: Penjual mengetik, Pembeli menerima indikator typing
      const typingPromise = new Promise((resolve) => {
        buyerSocket.on('typing', (data) => {
          if (data.userId === seller.id) {
            resolve(data);
          }
        });
      });

      sellerSocket.emit('typing', {
        transactionId: transaction.id,
        isTyping: true,
      });

      const typingData = await typingPromise;
      expect(typingData.isTyping).toBe(true);
      expect(typingData.userId).toBe(seller.id);

      // Pengujian event message:read: Penjual membaca, Pembeli menerima event message:read
      const readPromise = new Promise((resolve) => {
        buyerSocket.on('message:read', (data) => {
          if (data.userId === seller.id) {
            resolve(data);
          }
        });
      });

      sellerSocket.emit('message:read', {
        transactionId: transaction.id,
      });

      const readData = await readPromise;
      expect(readData.transactionId).toBe(transaction.id);
      expect(readData.userId).toBe(seller.id);

      buyerSocket.disconnect();
      sellerSocket.disconnect();
    });

    it('Notifikasi pesan baru dikirim ke lawan bicara yang TIDAK ada di room (dengan throttle 5 menit)', async () => {
      // Penjual mengirim pesan saat Pembeli TIDAK terhubung ke room
      await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ type: 'TEXT', body: 'Pesanan sedang dipacking ya' });

      // Cek apakah ada notifikasi CHAT_MESSAGE untuk pembeli
      const buyerNotifs = await prisma.notification.findMany({
        where: {
          userId: buyer.id,
          type: 'CHAT_MESSAGE',
        },
      });

      expect(buyerNotifs.length).toBe(1);
      expect(buyerNotifs[0].title).toContain(transaction.code);
      expect(buyerNotifs[0].body).toContain('Pesanan sedang dipacking ya');

      // Kirim pesan kedua dalam interval < 5 menit -> Harus di-throttle (tidak menambah notifikasi)
      await request(app)
        .post(`/api/transactions/${transaction.id}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ type: 'TEXT', body: 'Mohon ditunggu' });

      const buyerNotifsAfterThrottle = await prisma.notification.findMany({
        where: {
          userId: buyer.id,
          type: 'CHAT_MESSAGE',
        },
      });

      // Tetap 1 karena kena throttle 5 menit
      expect(buyerNotifsAfterThrottle.length).toBe(1);
    });
  });
});
