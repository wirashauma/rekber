// =============================================================================
// Concurrency Tests: Race Conditions, Double-Spending & Transition Clashes
// =============================================================================

const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const escrowService = require('../../src/services/escrow.service');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');

const app = createApp();

describe('Finance Concurrency Tests: Anti-Race Condition & Anti-Double Spending', () => {
  beforeEach(async () => {
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  /**
   * TUGAS 1:
   * 20 request PUT status PAID paralel pada transaksi yang sama
   * → tepat 1 berhasil; saldo berkurang tepat sekali.
   */
  test('1. 20 request PUT status PAID paralel pada transaksi yang sama → tepat 1 berhasil & saldo terpotong 1x', async () => {
    const initialBuyerBalance = 500000;
    const amount = 100000;
    const buyerFee = 1000;
    const sellerFee = 1000;
    const totalDebit = amount + buyerFee; // 101.000

    const buyer = await createUser({ name: 'Buyer Concurrency', balance: initialBuyerBalance });
    const seller = await createUser({ name: 'Seller Concurrency', balance: 0 });

    const tx = await createTransaction({
      buyerId: buyer.id,
      sellerId: seller.id,
      amount,
      buyerFee,
      sellerFee,
      status: 'PENDING',
    });

    const buyerToken = tokenFor(buyer);

    // Kirim 20 request PUT status PAID secara paralel
    const promises = Array.from({ length: 20 }, () =>
      request(app)
        .put(`/api/transactions/${tx.id}/status`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ status: 'PAID' })
    );

    const responses = await Promise.all(promises);

    const successResponses = responses.filter((r) => r.status === 200);
    const conflictResponses = responses.filter((r) => r.status === 409);

    // Tepat 1 berhasil, 19 ditolak dengan 409 Conflict
    expect(successResponses).toHaveLength(1);
    expect(conflictResponses).toHaveLength(19);

    // Saldo buyer berkurang tepat sekali (500.000 - 101.000 = 399.000)
    const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
    expect(updatedBuyer.balance).toBe(BigInt(initialBuyerBalance - totalDebit));

    // Entri ledger ESCROW_HOLD tercatat tepat 1 kali
    const holdEntries = await prisma.ledgerEntry.findMany({
      where: { transactionId: tx.id, type: 'ESCROW_HOLD' },
    });
    expect(holdEntries).toHaveLength(1);
    expect(holdEntries[0].amount).toBe(BigInt(totalDebit));
    expect(holdEntries[0].balanceAfter).toBe(BigInt(initialBuyerBalance - totalDebit));

    // Status transaksi adalah PAID dengan heldAmount yang tepat
    const updatedTx = await prisma.transaction.findUnique({ where: { id: tx.id } });
    expect(updatedTx.status).toBe('PAID');
    expect(updatedTx.heldAmount).toBe(BigInt(totalDebit));
  });

  /**
   * TUGAS 2:
   * 10 request COMPLETED paralel → penjual dibayar sekali; fee tercatat sekali.
   */
  test('2. 10 request COMPLETED paralel → penjual dibayar tepat sekali & fee tercatat sekali', async () => {
    const initialSellerBalance = 50000;
    const amount = 200000;
    const buyerFee = 2000;
    const sellerFee = 2000;
    const heldAmount = amount + buyerFee; // 202.000
    const sellerPayout = amount - sellerFee; // 198.000
    const totalPlatformFee = buyerFee + sellerFee; // 4.000

    const buyer = await createUser({ name: 'Buyer Completed', balance: 0 });
    const seller = await createUser({ name: 'Seller Completed', balance: initialSellerBalance });

    const tx = await createTransaction({
      buyerId: buyer.id,
      sellerId: seller.id,
      amount,
      buyerFee,
      sellerFee,
      heldAmount,
      status: 'SHIPPED',
    });

    const buyerToken = tokenFor(buyer);

    // Kirim 10 request COMPLETED paralel
    const promises = Array.from({ length: 10 }, () =>
      request(app)
        .put(`/api/transactions/${tx.id}/status`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ status: 'COMPLETED' })
    );

    const responses = await Promise.all(promises);

    const successResponses = responses.filter((r) => r.status === 200);
    const conflictResponses = responses.filter((r) => r.status === 409);

    // Tepat 1 berhasil, 9 ditolak dengan 409 Conflict
    expect(successResponses).toHaveLength(1);
    expect(conflictResponses).toHaveLength(9);

    // Penjual menerima payout tepat sekali (50.000 + 198.000 = 248.000)
    const updatedSeller = await prisma.user.findUnique({ where: { id: seller.id } });
    expect(updatedSeller.balance).toBe(BigInt(initialSellerBalance + sellerPayout));

    // Entri ledger ESCROW_RELEASE untuk penjual tercatat tepat 1 kali
    const releaseEntries = await prisma.ledgerEntry.findMany({
      where: { transactionId: tx.id, type: 'ESCROW_RELEASE' },
    });
    expect(releaseEntries).toHaveLength(1);
    expect(releaseEntries[0].amount).toBe(BigInt(sellerPayout));

    // Entri ledger PLATFORM_FEE tercatat tepat 1 kali
    const feeEntries = await prisma.ledgerEntry.findMany({
      where: { transactionId: tx.id, type: 'PLATFORM_FEE' },
    });
    expect(feeEntries).toHaveLength(1);
    expect(feeEntries[0].amount).toBe(BigInt(totalPlatformFee));
    expect(feeEntries[0].userId).toBeNull();

    // heldAmount kembali menjadi 0
    const updatedTx = await prisma.transaction.findUnique({ where: { id: tx.id } });
    expect(updatedTx.status).toBe('COMPLETED');
    expect(updatedTx.heldAmount).toBe(0n);
  });

  /**
   * TUGAS 3:
   * Pembeli bersaldo cukup untuk 1 transaksi memulai PAID pada 5 transaksi berbeda paralel
   * → tidak pernah negatif; sisanya ditolak.
   */
  test('3. Pembeli bersaldo cukup untuk 1 transaksi memulai PAID pada 5 transaksi berbeda paralel → tidak pernah negatif & sisanya ditolak', async () => {
    // Saldo pembeli hanya cukup untuk tepat 1 transaksi senilai Rp 100.000
    const buyerBalance = 100000;
    const buyer = await createUser({ name: 'Buyer Saldo Pas', balance: buyerBalance });
    const seller = await createUser({ name: 'Seller Test', balance: 0 });

    // Buat 5 transaksi berbeda, masing-masing Rp 100.000
    const transactions = await Promise.all(
      Array.from({ length: 5 }, () =>
        createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          buyerFee: 0,
          sellerFee: 0,
          status: 'PENDING',
        })
      )
    );

    const buyerToken = tokenFor(buyer);

    // Panggil pembayaran untuk ke-5 transaksi secara bersamaan
    const promises = transactions.map((t) =>
      request(app)
        .put(`/api/transactions/${t.id}/status`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ status: 'PAID' })
    );

    const responses = await Promise.all(promises);

    const successResponses = responses.filter((r) => r.status === 200);
    const insufficientBalanceResponses = responses.filter((r) => r.status === 400);

    // Tepat 1 transaksi berhasil dibayar, 4 transaksi ditolak karena saldo tidak mencukupi
    expect(successResponses).toHaveLength(1);
    expect(insufficientBalanceResponses).toHaveLength(4);

    for (const res of insufficientBalanceResponses) {
      expect(res.body.message).toContain('Saldo tidak mencukupi');
    }

    // Saldo pembeli tepat menjadi 0, dan tidak pernah bernilai negatif
    const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
    expect(updatedBuyer.balance).toBe(0n);
    expect(updatedBuyer.balance >= 0n).toBe(true);

    // Tepat 1 transaksi berstatus PAID, 4 sisanya tetap PENDING
    const updatedTransactions = await prisma.transaction.findMany({
      where: { id: { in: transactions.map((t) => t.id) } },
    });
    const paidTxs = updatedTransactions.filter((t) => t.status === 'PAID');
    const pendingTxs = updatedTransactions.filter((t) => t.status === 'PENDING');
    expect(paidTxs).toHaveLength(1);
    expect(pendingTxs).toHaveLength(4);
  });

  /**
   * TUGAS 4:
   * COMPLETED (pembeli) vs REFUNDED (admin/penjual) paralel
   * → tepat satu menang; invarian uang terjaga.
   */
  test('4. COMPLETED (pembeli) vs REFUNDED (penjual) paralel → tepat satu menang & invarian uang terjaga', async () => {
    const amount = 150000;
    const buyerFee = 1500;
    const sellerFee = 1500;
    const heldAmount = amount + buyerFee; // 151.500

    const buyer = await createUser({ name: 'Buyer Invariant', balance: 0 });
    const seller = await createUser({ name: 'Seller Invariant', balance: 0 });

    const tx = await createTransaction({
      buyerId: buyer.id,
      sellerId: seller.id,
      amount,
      buyerFee,
      sellerFee,
      heldAmount,
      status: 'PAID',
    });

    // Menjalankan releaseEscrow (menuju COMPLETED) dan refundEscrow (menuju REFUNDED) secara paralel
    const results = await Promise.allSettled([
      escrowService.releaseEscrow(null, tx.id, buyer.id),
      escrowService.refundEscrow(null, tx.id, seller.id, 'Refund kesepakatan'),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    // Tepat satu yang menang (fulfilled), dan satu digagalkan dengan 409 Conflict
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason.statusCode).toBe(409);
    expect(rejected[0].reason.message).toContain('Status transaksi sudah berubah');

    // Periksa invarian uang: uang tidak bocor atau tercetak ganda
    const [finalBuyer, finalSeller, finalTx, feeAgg] = await Promise.all([
      prisma.user.findUnique({ where: { id: buyer.id } }),
      prisma.user.findUnique({ where: { id: seller.id } }),
      prisma.transaction.findUnique({ where: { id: tx.id } }),
      prisma.ledgerEntry.aggregate({
        where: { transactionId: tx.id, type: 'PLATFORM_FEE' },
        _sum: { amount: true },
      }),
    ]);

    const platformFee = feeAgg._sum.amount || 0n;

    // Total dana yang didistribusikan harus tepat sama dengan dana tertahan awal (heldAmount = 151.500)
    const distributedMoney = finalBuyer.balance + finalSeller.balance + platformFee;
    expect(distributedMoney).toBe(BigInt(heldAmount));
    expect(finalTx.heldAmount).toBe(0n);

    // Verifikasi state akhir
    if (finalTx.status === 'COMPLETED') {
      expect(finalSeller.balance).toBe(BigInt(amount - sellerFee));
      expect(finalBuyer.balance).toBe(0n);
      expect(platformFee).toBe(BigInt(buyerFee + sellerFee));
    } else {
      expect(finalTx.status).toBe('REFUNDED');
      expect(finalBuyer.balance).toBe(BigInt(heldAmount));
      expect(finalSeller.balance).toBe(0n);
      expect(platformFee).toBe(0n);
    }
  });
});
