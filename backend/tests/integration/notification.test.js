// =============================================================================
// Integration Tests: Notification & Push System (Prompt 12)
// =============================================================================

const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');
const { setFcmProvider, FakeFcmProvider } = require('../../src/providers/fcm');
const notificationService = require('../../src/services/notification.service');
const escrowService = require('../../src/services/escrow.service');
const disputeService = require('../../src/services/dispute.service');

describe('Notification & Push System (Prompt 12)', () => {
  let app;
  let buyer;
  let seller;
  let buyerToken;
  let sellerToken;
  let fakeFcm;

  beforeAll(async () => {
    app = createApp();
    await resetDb();
  });

  beforeEach(async () => {
    await resetDb();

    fakeFcm = new FakeFcmProvider();
    setFcmProvider(fakeFcm);

    buyer = await createUser({
      name: 'Pembeli Notif',
      balance: 500000,
      fcmToken: 'fcm_token_buyer_12345',
    });
    seller = await createUser({
      name: 'Penjual Notif',
      balance: 100000,
      fcmToken: 'fcm_token_seller_67890',
    });
    buyerToken = tokenFor(buyer);
    sellerToken = tokenFor(seller);
  });

  afterAll(async () => {
    await disconnectDb();
  });

  describe('1. notificationService.notify & FCM Dispatch', () => {
    it('Menyimpan notifikasi ke database dan memanggil provider FCM', async () => {
      const notif = await notificationService.notify(buyer.id, {
        type: 'TEST_ALERT',
        title: 'Halo Pembeli',
        body: 'Ini adalah uji coba notifikasi.',
        data: { testKey: 'testValue' },
      });

      expect(notif.id).toBeDefined();
      expect(notif.userId).toBe(buyer.id);
      expect(notif.title).toBe('Halo Pembeli');
      expect(notif.readAt).toBeNull();

      // Verifikasi di DB
      const dbNotif = await prisma.notification.findUnique({ where: { id: notif.id } });
      expect(dbNotif).not.toBeNull();
      expect(dbNotif.body).toBe('Ini adalah uji coba notifikasi.');

      // Verifikasi di Fake FCM Provider
      const sent = fakeFcm.getSentMessages();
      expect(sent).toHaveLength(1);
      expect(sent[0].token).toBe('fcm_token_buyer_12345');
      expect(sent[0].title).toBe('Halo Pembeli');
      expect(sent[0].data.testKey).toBe('testValue');
    });

    it('Kegagalan FCM tidak menggagalkan penyimpanan notifikasi atau alur utama', async () => {
      // Mock FCM provider to throw an unexpected network error
      const failingFcm = {
        send: jest.fn().mockRejectedValue(new Error('Koneksi timeout ke server FCM')),
      };
      setFcmProvider(failingFcm);

      const notif = await notificationService.notify(buyer.id, {
        type: 'TRANSACTION_UPDATE',
        title: 'Pembaruan Transaksi',
        body: 'Status berubah.',
      });

      // Tetap sukses menyimpan notifikasi ke DB tanpa melempar error
      expect(notif).toBeDefined();
      expect(notif.id).toBeDefined();
      const inDb = await prisma.notification.findUnique({ where: { id: notif.id } });
      expect(inDb).not.toBeNull();
    });

    it('Membersihkan token FCM yang tidak valid dari profil pengguna', async () => {
      // Set invalid token
      await prisma.user.update({
        where: { id: buyer.id },
        data: { fcmToken: 'invalid_fcm_token' },
      });

      // notify should catch registration-token-not-registered and clear the fcmToken
      await notificationService.notify(buyer.id, {
        type: 'TEST_CLEANUP',
        title: 'Uji Bersih Token',
        body: 'Mendeteksi token kedaluwarsa.',
      });

      const updatedUser = await prisma.user.findUnique({ where: { id: buyer.id } });
      expect(updatedUser.fcmToken).toBeNull();
    });
  });

  describe('2. Endpoint Inbox Notifikasi (/api/notifications)', () => {
    beforeEach(async () => {
      // Buat beberapa notifikasi untuk buyer dan seller
      await notificationService.notify(buyer.id, {
        type: 'INFO_1',
        title: 'Notif Pembeli 1',
        body: 'Pesan pertama pembeli.',
      });
      await notificationService.notify(buyer.id, {
        type: 'INFO_2',
        title: 'Notif Pembeli 2',
        body: 'Pesan kedua pembeli.',
      });
      await notificationService.notify(seller.id, {
        type: 'INFO_SELLER',
        title: 'Notif Penjual',
        body: 'Pesan khusus penjual.',
      });
    });

    it('GET /api/notifications: hanya mengembalikan notifikasi milik pengguna terautentikasi', async () => {
      const res = await request(app)
        .get('/api/notifications')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(2);
      res.body.data.forEach((item) => {
        expect(item.userId).toBe(buyer.id);
      });
    });

    it('GET /api/notifications/unread-count: menghitung notifikasi belum dibaca milik sendiri', async () => {
      const res = await request(app)
        .get('/api/notifications/unread-count')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.unreadCount).toBe(2);
    });

    it('POST /api/notifications/:id/read: menandai notifikasi telah dibaca', async () => {
      const listRes = await request(app)
        .get('/api/notifications')
        .set('Authorization', `Bearer ${buyerToken}`);
      const notifId = listRes.body.data[0].id;

      const readRes = await request(app)
        .post(`/api/notifications/${notifId}/read`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(readRes.status).toBe(200);
      expect(readRes.body.data.readAt).not.toBeNull();

      // Cek sisa unread count
      const countRes = await request(app)
        .get('/api/notifications/unread-count')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(countRes.body.data.unreadCount).toBe(1);
    });

    it('POST /api/notifications/:id/read: ditolak saat mencoba menandai notifikasi milik orang lain (404)', async () => {
      const sellerNotif = await prisma.notification.findFirst({ where: { userId: seller.id } });

      const res = await request(app)
        .post(`/api/notifications/${sellerNotif.id}/read`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toMatch(/Notifikasi tidak ditemukan/i);
    });

    it('POST /api/notifications/read-all: menandai semua notifikasi unread milik pengguna', async () => {
      const res = await request(app)
        .post('/api/notifications/read-all')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.count).toBe(2);

      // Verifikasi unread count buyer menjadi 0
      const countBuyer = await request(app)
        .get('/api/notifications/unread-count')
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(countBuyer.body.data.unreadCount).toBe(0);

      // Verifikasi notifikasi seller tetap belum terbaca
      const countSeller = await request(app)
        .get('/api/notifications/unread-count')
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(countSeller.body.data.unreadCount).toBe(1);
    });
  });

  describe('3. Pemicu Event Notifikasi pada Alur Bisnis Nyata', () => {
    it('Event: Transaksi dibuat mengirim notifikasi ke pihak lawan', async () => {
      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 250000,
        itemDescription: 'Keyboard Mekanikal',
      });

      const notifs = await prisma.notification.findMany({
        where: { userId: seller.id },
      });

      expect(notifs.length).toBeGreaterThanOrEqual(1);
      const match = notifs.find((n) => n.type === 'TRANSACTION_CREATED');
      expect(match).toBeDefined();
      expect(match.title).toContain('Transaksi Baru Dibuat');
      expect(match.body).toContain(tx.code);
    });

    it('Event: Sengketa diajukan mengirim notifikasi ke penjual', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 150000,
        status: 'PAID',
      });

      await disputeService.openDispute(tx.id, buyer.id, {
        reason: 'NOT_RECEIVED',
        description: 'Barang tidak kunjung dikirim oleh penjual dalam 3 hari.',
      });

      const sellerNotifs = await prisma.notification.findMany({
        where: { userId: seller.id, type: 'TRANSACTION_DISPUTED' },
      });

      expect(sellerNotifs).toHaveLength(1);
      expect(sellerNotifs[0].title).toContain('Sengketa Diajukan');
      expect(sellerNotifs[0].body).toContain('NOT_RECEIVED');
    });

    it('Event: Sengketa diputuskan mengirim notifikasi ke kedua pihak', async () => {
      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 300000,
        status: 'SHIPPED',
      });

      const dispute = await disputeService.openDispute(tx.id, buyer.id, {
        reason: 'DEFECTIVE',
        description: 'Layar produk pecah berkeping-keping saat pertama diterima.',
      });

      const admin = await createUser({ name: 'Admin Resolusi', role: 'ADMIN' });

      await disputeService.resolveDispute(dispute.id, admin.id, {
        decision: 'REFUND_TO_BUYER',
        note: 'Bukti kerusakan pembeli valid dan disetujui pengembalian dana.',
      });

      const buyerNotifs = await prisma.notification.findMany({
        where: { userId: buyer.id, type: 'DISPUTE_RESOLVED' },
      });
      const sellerNotifs = await prisma.notification.findMany({
        where: { userId: seller.id, type: 'DISPUTE_RESOLVED' },
      });

      expect(buyerNotifs).toHaveLength(1);
      expect(sellerNotifs).toHaveLength(1);
      expect(buyerNotifs[0].body).toContain('dikembalikan penuh ke pembeli');
      expect(sellerNotifs[0].body).toContain('dikembalikan penuh ke pembeli');
    });
  });
});
