// =============================================================================
// Integration Tests: Scheduler, Background Worker & Advisory Locks (Prompt 12)
// =============================================================================

const prisma = require('../../src/config/prisma');
const { createUser, createTransaction, resetDb, disconnectDb } = require('../helpers');
const {
  JOB_LOCKS,
  withAdvisoryLock,
  runAutoRelease,
  runExpirePending,
  runReminder,
} = require('../../src/worker');

describe('Background Worker & Scheduler System (Prompt 12)', () => {
  let buyer;
  let seller;

  beforeAll(async () => {
    await resetDb();
  });

  beforeEach(async () => {
    await resetDb();

    buyer = await createUser({ name: 'Pembeli Worker', balance: 500000 });
    seller = await createUser({ name: 'Penjual Worker', balance: 100000 });
  });

  afterAll(async () => {
    await disconnectDb();
  });

  describe('1. Auto-Release Job (runAutoRelease)', () => {
    it('Hanya me-release transaksi SHIPPED yang autoReleaseAt sudah lewat dan TIDAK menyentuh DISPUTED', async () => {
      const pastTime = new Date(Date.now() - 3600 * 1000); // 1 jam lalu
      const futureTime = new Date(Date.now() + 72 * 3600 * 1000); // 3 hari lagi

      // 1. Transaksi jatuh tempo (harus auto-release)
      const dueTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 200000,
        buyerFee: 2000,
        sellerFee: 2000,
        status: 'SHIPPED',
      });
      await prisma.transaction.update({
        where: { id: dueTx.id },
        data: { autoReleaseAt: pastTime },
      });

      // 2. Transaksi belum jatuh tempo (tidak boleh di-release)
      const futureTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 300000,
        status: 'SHIPPED',
      });
      await prisma.transaction.update({
        where: { id: futureTx.id },
        data: { autoReleaseAt: futureTime },
      });

      // 3. Transaksi bersengketa (DISPUTED) (tidak boleh disentuh)
      const disputedTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 400000,
        status: 'DISPUTED',
      });
      await prisma.transaction.update({
        where: { id: disputedTx.id },
        data: { autoReleaseAt: pastTime },
      });

      const initialSellerBalance = (await prisma.user.findUnique({ where: { id: seller.id } }))
        .balance;

      // Jalankan auto-release worker job
      const result = await runAutoRelease();

      expect(result.processed).toBe(1);
      expect(result.failed).toBe(0);

      // Verifikasi Transaksi 1: COMPLETED
      const checkDue = await prisma.transaction.findUnique({ where: { id: dueTx.id } });
      expect(checkDue.status).toBe('COMPLETED');
      expect(checkDue.heldAmount).toBe(0n);

      // Verifikasi Transaksi 2: Tetap SHIPPED
      const checkFuture = await prisma.transaction.findUnique({ where: { id: futureTx.id } });
      expect(checkFuture.status).toBe('SHIPPED');

      // Verifikasi Transaksi 3: Tetap DISPUTED
      const checkDisputed = await prisma.transaction.findUnique({ where: { id: disputedTx.id } });
      expect(checkDisputed.status).toBe('DISPUTED');

      // Verifikasi saldo penjual bertambah: amount (200.000) - sellerFee (2.000) = 198.000
      const finalSeller = await prisma.user.findUnique({ where: { id: seller.id } });
      expect(finalSeller.balance).toBe(initialSellerBalance + 198000n);
    });
  });

  describe('2. Expire Pending Job (runExpirePending)', () => {
    it('Membatalkan transaksi PENDING yang telah kedaluwarsa dengan cancelReason EXPIRED', async () => {
      const pastTime = new Date(Date.now() - 3600 * 1000);
      const futureTime = new Date(Date.now() + 24 * 3600 * 1000);

      // Transaksi expired
      const expiredTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 100000,
        status: 'PENDING',
      });
      await prisma.transaction.update({
        where: { id: expiredTx.id },
        data: { expiresAt: pastTime },
      });

      // Transaksi aktif
      const activeTx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 150000,
        status: 'PENDING',
      });
      await prisma.transaction.update({
        where: { id: activeTx.id },
        data: { expiresAt: futureTime },
      });

      const result = await runExpirePending();

      expect(result.processed).toBe(1);

      const checkExpired = await prisma.transaction.findUnique({ where: { id: expiredTx.id } });
      expect(checkExpired.status).toBe('CANCELLED');
      expect(checkExpired.cancelReason).toBe('EXPIRED');

      const checkActive = await prisma.transaction.findUnique({ where: { id: activeTx.id } });
      expect(checkActive.status).toBe('PENDING');
    });
  });

  describe('3. Reminder Auto-Release Job (runReminder)', () => {
    it('Mengirimkan pengingat ke pembeli tepat 1 kali pada transaksi yang mendekati auto-release', async () => {
      const in12Hours = new Date(Date.now() + 12 * 3600 * 1000);

      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 250000,
        status: 'SHIPPED',
      });
      await prisma.transaction.update({
        where: { id: tx.id },
        data: { autoReleaseAt: in12Hours, reminderSentAt: null },
      });

      // Run reminder job first time
      const res1 = await runReminder();
      expect(res1.processed).toBe(1);

      // Verifikasi reminderSentAt terisi
      const txAfter = await prisma.transaction.findUnique({ where: { id: tx.id } });
      expect(txAfter.reminderSentAt).not.toBeNull();

      // Verifikasi notifikasi tersimpan
      const notifs = await prisma.notification.findMany({
        where: { userId: buyer.id, type: 'AUTO_RELEASE_REMINDER' },
      });
      expect(notifs).toHaveLength(1);
      expect(notifs[0].title).toContain('Pengingat Konfirmasi Penerimaan');

      // Run reminder job second time (idempoten: tidak boleh kirim ulang)
      const res2 = await runReminder();
      expect(res2.processed).toBe(0);

      const notifsAfter = await prisma.notification.findMany({
        where: { userId: buyer.id, type: 'AUTO_RELEASE_REMINDER' },
      });
      expect(notifsAfter).toHaveLength(1);
    });
  });

  describe('4. PostgreSQL Advisory Locks (Konkurensi Worker)', () => {
    it('Dua worker paralel bersaing pada lock yang sama: tepat 1 berhasil eksekusi dan 1 dilewati', async () => {
      let executionCount = 0;
      const testJob = async () => {
        executionCount += 1;
        // Tunggu sebentar untuk mensimulasikan pekerjaan yang sedang berlangsung
        await new Promise((resolve) => setTimeout(resolve, 150));
        return 'DONE';
      };

      // Jalankan dua pemanggilan worker dengan lockId yang sama secara paralel
      const [res1, res2] = await Promise.all([
        withAdvisoryLock(JOB_LOCKS.AUTO_RELEASE, 'testAutoReleaseWorker1', testJob),
        withAdvisoryLock(JOB_LOCKS.AUTO_RELEASE, 'testAutoReleaseWorker2', testJob),
      ]);

      const results = [res1, res2];
      const executed = results.filter((r) => r.skipped === false);
      const skipped = results.filter((r) => r.skipped === true);

      expect(executed).toHaveLength(1);
      expect(skipped).toHaveLength(1);
      expect(skipped[0].reason).toBe('LOCK_HELD_BY_ANOTHER_INSTANCE');
      expect(executionCount).toBe(1);
    });
  });
});
