// =============================================================================
// Manual Verification Script: Worker Auto-Release Flow (Prompt 12)
// =============================================================================

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');
const prisma = require('../src/config/prisma');
const { createUser, createTransaction } = require('../tests/helpers');
const { startScheduler, stopScheduler } = require('../src/worker');

const run = async () => {
  console.log('--- [PROMPT 12] Memulai Verifikasi Alur Worker & Auto-Release ---');

  // 1. Setup Pembeli & Penjual
  const buyer = await createUser({ name: 'Pembeli Worker E2E', balance: 500000 });
  const seller = await createUser({ name: 'Penjual Worker E2E', balance: 100000 });

  console.log(`[1] User dibuat: Buyer=${buyer.id}, Seller=${seller.id}`);

  // 2. Buat transaksi SHIPPED dengan autoReleaseAt 1 detik di masa lalu
  const amount = 300000;
  const buyerFee = 3000;
  const sellerFee = 3000;

  const tx = await createTransaction({
    buyerId: buyer.id,
    sellerId: seller.id,
    amount,
    buyerFee,
    sellerFee,
    heldAmount: amount + buyerFee,
    status: 'SHIPPED',
  });

  const dueTime = new Date(Date.now() - 2000); // 2 detik lalu
  await prisma.transaction.update({
    where: { id: tx.id },
    data: { autoReleaseAt: dueTime },
  });

  console.log(
    `[2] Transaksi SHIPPED dibuat: ${tx.id}, code=${tx.code}, autoReleaseAt=${dueTime.toISOString()}`
  );

  // 3. Jalankan scheduler dengan interval dipercepat via env (per 2 detik)
  process.env.WORKER_ACCELERATED_INTERVAL = 'true';
  const tasks = startScheduler();
  console.log(
    '[3] Scheduler dimulai dengan WORKER_ACCELERATED_INTERVAL=true. Menunggu eksekusi cron (3 detik)...'
  );

  // Tunggu 4 detik agar cron job berjalan
  await new Promise((resolve) => setTimeout(resolve, 4000));

  // 4. Hentikan scheduler
  stopScheduler(tasks);
  console.log('[4] Scheduler dihentikan.');

  // 5. Periksa status transaksi dan saldo
  const txAfter = await prisma.transaction.findUnique({ where: { id: tx.id } });
  console.log(
    `[5] Status transaksi pasca-worker: ${txAfter.status}, heldAmount: ${txAfter.heldAmount}`
  );

  if (txAfter.status !== 'COMPLETED' || txAfter.heldAmount !== 0n) {
    throw new Error('VERIFIKASI GAGAL: Transaksi belum ter-auto-release!');
  }

  const sellerAfter = await prisma.user.findUnique({ where: { id: seller.id } });
  console.log(`[6] Saldo akhir Penjual: Rp ${sellerAfter.balance.toLocaleString('id-ID')}`);

  // 6. Periksa notifikasi ke penjual
  const notifs = await prisma.notification.findMany({
    where: { userId: seller.id, type: 'TRANSACTION_COMPLETED' },
  });
  console.log(`[7] Notifikasi diterima penjual: ${notifs.length} pesan.`);
  if (notifs.length > 0) {
    console.log(`    Judul: "${notifs[0].title}", Pesan: "${notifs[0].body}"`);
  }

  console.log('=== [OK] TRANSAKSI BERHASIL TER-AUTO-RELEASE SECARA OTOMATIS OLEH WORKER ===');
};

run()
  .catch((err) => {
    console.error('Verifikasi Gagal:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
