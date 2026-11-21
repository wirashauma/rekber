// =============================================================================
// Verification Script: End-to-End Dispute & Resolution Flow (Prompt 11)
// =============================================================================

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');
const prisma = require('../src/config/prisma');
const { createUser, createTransaction } = require('../tests/helpers');
const disputeService = require('../src/services/dispute.service');
const { reconcile } = require('../src/services/reconcile.service');
const { DISPUTE_REASON, DISPUTE_DECISION } = require('../src/constants/dispute');

const run = async () => {
  console.log('--- Memulai Verifikasi Alur Sengketa & Resolusi Admin ---');

  // 1. Buat pengguna
  const buyer = await createUser({ name: 'Pembeli Sengketa E2E', balance: 1000000 });
  const seller = await createUser({ name: 'Penjual Sengketa E2E', balance: 200000 });
  const admin = await createUser({ name: 'Admin Resolusi E2E', role: 'ADMIN' });

  console.log(`[1] User dibuat: Buyer=${buyer.id}, Seller=${seller.id}, Admin=${admin.id}`);

  // 2. Buat transaksi berstatus SHIPPED
  const amount = 500000n;
  const buyerFee = 5000n;
  const sellerFee = 5000n;
  const heldAmount = amount + buyerFee;

  const tx = await createTransaction({
    buyerId: buyer.id,
    sellerId: seller.id,
    amount: Number(amount),
    buyerFee: Number(buyerFee),
    sellerFee: Number(sellerFee),
    heldAmount: Number(heldAmount),
    status: 'SHIPPED',
  });

  // Set autoReleaseAt
  await prisma.transaction.update({
    where: { id: tx.id },
    data: { autoReleaseAt: new Date(Date.now() + 72 * 3600 * 1000) },
  });

  console.log(`[2] Transaksi SHIPPED dibuat: ${tx.id}, code=${tx.code}, heldAmount=${heldAmount}`);

  // 3. Pembeli mengajukan sengketa
  const dispute = await disputeService.openDispute(tx.id, buyer.id, {
    reason: DISPUTE_REASON.DEFECTIVE,
    description: 'Barang yang sampai rusak fisik parah dan tidak dapat dihidupkan sama sekali.',
  });

  console.log(
    `[3] Sengketa diajukan: Dispute ID=${dispute.id}, Status=${dispute.status}, Reason=${dispute.reason}`
  );

  const txAfterDispute = await prisma.transaction.findUnique({ where: { id: tx.id } });
  if (txAfterDispute.status !== 'DISPUTED' || txAfterDispute.autoReleaseAt !== null) {
    throw new Error(
      'Validasi gagal: Status transaksi harus DISPUTED dan autoReleaseAt harus null!'
    );
  }
  console.log('[✓] Status transaksi berhasil berubah menjadi DISPUTED & auto-release dibatalkan.');

  // 4. Pengiriman bukti dari pembeli dan penjual
  const buyerEvidence = await disputeService.submitEvidence(dispute.id, buyer.id, {
    note: 'Video rekaman unboxing paket dari awal buka kotak.',
  });
  console.log(`[4a] Bukti pembeli tercatat: ID=${buyerEvidence.id}`);

  const sellerEvidence = await disputeService.submitEvidence(dispute.id, seller.id, {
    note: 'Foto barang dan fungsi normal sebelum diserahkan ke kurir.',
  });
  console.log(`[4b] Bukti penjual tercatat: ID=${sellerEvidence.id}`);

  // 5. Admin meninjau sengketa (OPEN -> UNDER_REVIEW)
  const reviewedDispute = await disputeService.reviewDispute(dispute.id, admin.id);
  if (reviewedDispute.status !== 'UNDER_REVIEW') {
    throw new Error('Validasi gagal: Status sengketa harus UNDER_REVIEW!');
  }
  console.log('[5] Admin berhasil meninjau sengketa (Status: UNDER_REVIEW).');

  // 6. Admin menyelesaikan sengketa dengan keputusan REFUND_TO_BUYER
  const resolvedDispute = await disputeService.resolveDispute(dispute.id, admin.id, {
    decision: DISPUTE_DECISION.REFUND_TO_BUYER,
    note: 'Berdasarkan video unboxing pembeli, kerusakan terjadi sebelum diterima. Dana dikembalikan penuh ke pembeli.',
  });

  console.log(
    `[6] Sengketa diselesaikan: Status=${resolvedDispute.status}, Transaksi Status=${resolvedDispute.transaction.status}`
  );

  if (resolvedDispute.status !== 'RESOLVED_BUYER') {
    throw new Error('Validasi gagal: Status sengketa harus RESOLVED_BUYER!');
  }

  // 7. Verifikasi saldo akhir dan pembukuan
  const finalBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
  const finalSeller = await prisma.user.findUnique({ where: { id: seller.id } });

  console.log(`[7] Saldo akhir Buyer: Rp ${finalBuyer.balance.toLocaleString('id-ID')}`);
  console.log(`[7] Saldo akhir Seller: Rp ${finalSeller.balance.toLocaleString('id-ID')}`);

  // 8. Audit integritas saldo sistem lewat reconcile()
  const auditResult = await reconcile();
  console.log(
    `[8] Audit reconcile: isReconciled = ${auditResult.isReconciled}, User discrepancies = ${auditResult.userDiscrepancies.length}, Escrow discrepancies = ${auditResult.escrowDiscrepancies.length}`
  );

  if (!auditResult.isReconciled || auditResult.userDiscrepancies.length > 0 || auditResult.escrowDiscrepancies.length > 0) {
    throw new Error('Ditemukan selisih pada audit keuangan!');
  }

  console.log('=== SEMUA TAHAP VERIFIKASI SENGKETA BERHASIL DILALUI DENGAN SUKSES [OK] ===');
};

run()
  .catch((err) => {
    console.error('Verifikasi Gagal:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
