#!/usr/bin/env node
// =============================================================================
// reconcile.js - Audit CLI script to verify double-entry integrity
// Exits with non-zero status if any discrepancy is found.
// =============================================================================

const fs = require('fs');
const path = require('path');
require('dotenv').config();
if (!process.env.DATABASE_URL) {
  const fallbackEnv = fs.existsSync(path.resolve(__dirname, '../.env'))
    ? path.resolve(__dirname, '../.env')
    : path.resolve(__dirname, '../.env.test');
  require('dotenv').config({ path: fallbackEnv });
}
const prisma = require('../src/config/prisma');
const { reconcile } = require('../src/services/reconcile.service');

const main = async () => {
  console.log('🔍 Memulai audit rekonsiliasi buku besar & saldo escrow...');
  const startTime = Date.now();

  const result = await reconcile();
  const duration = Date.now() - startTime;

  console.log('====================================================');
  console.log('📊 HASIL REKONSILIASI KEUANGAN');
  console.log('====================================================');
  console.log(`Total Pengguna Diaudit     : ${result.stats.totalUsersAudited}`);
  console.log(`Total Transaksi Diaudit    : ${result.stats.totalTransactionsAudited}`);
  console.log(
    `Total Dana Tertahan Escrow : Rp ${Number(result.stats.totalActiveHeldAmount).toLocaleString('id-ID')}`
  );
  console.log(`Durasi Audit               : ${duration} ms`);
  console.log('----------------------------------------------------');

  if (result.userDiscrepancies.length > 0) {
    console.error(`❌ DITEMUKAN ${result.userDiscrepancies.length} SELISIH SALDO PENGGUNA:`);
    result.userDiscrepancies.forEach((d, idx) => {
      console.error(
        `  ${idx + 1}. User: ${d.email} (${d.userId})\n` +
          `     Saldo di DB   : Rp ${Number(d.currentBalance).toLocaleString('id-ID')}\n` +
          `     Saldo Ledger  : Rp ${Number(d.expectedBalance).toLocaleString('id-ID')}\n` +
          `     Selisih       : Rp ${Number(d.diff).toLocaleString('id-ID')}`
      );
    });
  }

  if (result.escrowDiscrepancies.length > 0) {
    console.error(`❌ DITEMUKAN ${result.escrowDiscrepancies.length} SELISIH DANA ESCROW:`);
    result.escrowDiscrepancies.forEach((d, idx) => {
      console.error(
        `  ${idx + 1}. Transaksi: ${d.code} (${d.transactionId}) [${d.status}]\n` +
          `     Held Amount DB: Rp ${Number(d.currentHeldAmount).toLocaleString('id-ID')}\n` +
          `     Expected Held : Rp ${Number(d.expectedHeldAmount).toLocaleString('id-ID')}\n` +
          `     Selisih       : Rp ${Number(d.diff).toLocaleString('id-ID')}`
      );
    });
  }

  if (result.isReconciled) {
    console.log('✅ REKONSILIASI BERHASIL: Semua saldo pengguna dan escrow 100% konsisten!');
    console.log('====================================================');
    process.exit(0);
  } else {
    console.error('❌ REKONSILIASI GAGAL: Terdeteksi ketidakkonsistenan saldo pada database.');
    console.log('====================================================');
    process.exit(1);
  }
};

main()
  .catch((err) => {
    console.error('Error saat menjalankan rekonsiliasi:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
