// =============================================================================
// Property-Based Finance Test: Random Fuzzing & Conservation of Money
// =============================================================================

const prisma = require('../../src/config/prisma');
const escrowService = require('../../src/services/escrow.service');
const ledgerService = require('../../src/services/ledger.service');
const { reconcile } = require('../../src/services/reconcile.service');
const { createUser, resetDb, disconnectDb } = require('../helpers');

jest.setTimeout(60000);

describe('Finance Property Test: 200 Randomized Operations & Conservation of Money Law', () => {
  beforeEach(async () => {
    await resetDb();

    // Pastikan Platform Settings dasar ada
    const defaultSettings = [
      { key: 'fee_percent', value: '2' },
      { key: 'fee_min', value: '1000' },
      { key: 'fee_payer_default', value: 'SPLIT' },
      { key: 'auto_release_hours', value: '72' },
      { key: 'pending_expire_hours', value: '24' },
      { key: 'max_transaction_amount', value: '5000000' },
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

  /**
   * Deterministic Pseudo-Random Number Generator (Mulberry32)
   * Menggunakan fixed seed (123456789) agar pengujian repeatable dan tidak flaky.
   */
  const createRng = (seed = 123456789) => {
    let s = seed >>> 0;
    return () => {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = Math.imul(s ^ (s >>> 15), 1 | s);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };

  test('6. 200 operasi acak dengan fixed seed → reconcile() 100% konsisten & hukum kekekalan uang terbukti', async () => {
    const rng = createRng(987654321);

    // 1. Buat pool pengguna (4 pengguna)
    const users = await Promise.all([
      createUser({ name: 'User Alpha', balance: 0 }),
      createUser({ name: 'User Beta', balance: 0 }),
      createUser({ name: 'User Gamma', balance: 0 }),
      createUser({ name: 'User Delta', balance: 0 }),
    ]);

    let totalExternalCredits = 0n;

    // Inisialisasi saldo awal tiap pengguna via ADJUSTMENT
    for (let i = 0; i < users.length; i++) {
      const initialAmount = 500000n;
      await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: users[i].id,
          amount: initialAmount,
          type: 'ADJUSTMENT',
          idempotencyKey: `init:user:${users[i].id}`,
        })
      );
      totalExternalCredits += initialAmount;
    }

    const feePayers = ['BUYER', 'SELLER', 'SPLIT'];
    const createdTransactions = [];

    // 2. Jalankan 200 operasi finansial acak
    const TOTAL_OPERATIONS = 200;

    for (let op = 0; op < TOTAL_OPERATIONS; op++) {
      const actionRoll = rng();

      if (actionRoll < 0.15) {
        // [A] Top-up / Injeksi dana eksternal (ADJUSTMENT)
        const targetUser = users[Math.floor(rng() * users.length)];
        const topupAmount = BigInt(Math.floor(rng() * 50000) + 10000); // 10.000 - 60.000

        await prisma.$transaction((tx) =>
          ledgerService.credit(tx, {
            userId: targetUser.id,
            amount: topupAmount,
            type: 'ADJUSTMENT',
            idempotencyKey: `fuzz:topup:${op}:${Date.now()}`,
          })
        );
        totalExternalCredits += topupAmount;
      } else if (actionRoll < 0.45) {
        // [B] Buat Transaksi Escrow Baru
        const buyerIdx = Math.floor(rng() * users.length);
        let sellerIdx = Math.floor(rng() * users.length);
        while (sellerIdx === buyerIdx) {
          sellerIdx = (sellerIdx + 1) % users.length;
        }

        const buyer = users[buyerIdx];
        const seller = users[sellerIdx];
        const amount = Math.floor(rng() * 40000) + 5000; // 5.000 - 45.000
        const feePayer = feePayers[Math.floor(rng() * feePayers.length)];

        try {
          const newTx = await escrowService.createTransaction({
            buyerId: buyer.id,
            sellerId: seller.id,
            amount,
            itemDescription: `Fuzz Transaction #${op}`,
            feePayer,
          });
          createdTransactions.push(newTx);
        } catch {
          // Expected business rejection (misal batas minimum dsb.)
        }
      } else {
        // [C] Transisi Status Transaksi yang Ada
        if (createdTransactions.length === 0) continue;

        const txIndex = Math.floor(rng() * createdTransactions.length);
        const candidateTx = createdTransactions[txIndex];

        // Ambil status terkini dari DB
        const currentTx = await prisma.transaction.findUnique({
          where: { id: candidateTx.id },
        });
        if (!currentTx) continue;

        try {
          switch (currentTx.status) {
            case 'PENDING':
              if (rng() < 0.8) {
                // Bayar transaksi
                await escrowService.executeTransition(currentTx.id, 'PAID', {
                  id: currentTx.buyerId,
                  role: 'USER',
                });
              } else {
                // Batalkan transaksi
                await escrowService.executeTransition(
                  currentTx.id,
                  'CANCELLED',
                  { id: currentTx.buyerId, role: 'USER' },
                  'Batal oleh buyer'
                );
              }
              break;

            case 'PAID':
              if (rng() < 0.85) {
                // Tandai kirim via submitShipmentProof
                await escrowService.submitShipmentProof(currentTx.id, currentTx.sellerId, {
                  courier: 'JNE',
                  trackingNumber: 'JNE-PROPERTY-TEST',
                });
              } else {
                // Refund penjual
                await escrowService.executeTransition(
                  currentTx.id,
                  'REFUNDED',
                  { id: currentTx.sellerId, role: 'USER' },
                  'Refund fuzz'
                );
              }
              break;

            case 'SHIPPED':
              // Selesaikan transaksi
              await escrowService.executeTransition(currentTx.id, 'COMPLETED', {
                id: currentTx.buyerId,
                role: 'USER',
              });
              break;

            default:
              // Terminal states (COMPLETED, CANCELLED, REFUNDED)
              break;
          }
        } catch {
          // Saldo tidak mencukupi, dsb. ditangani dengan aman
        }
      }
    }

    // 3. Verifikasi Audit Rekonsiliasi (reconcile())
    const audit = await reconcile();
    expect(audit.isReconciled).toBe(true);
    expect(audit.userDiscrepancies).toHaveLength(0);
    expect(audit.escrowDiscrepancies).toHaveLength(0);

    // 4. Verifikasi Hukum Kekekalan Uang (Conservation of Money Law)
    // Total uang sistem = Saldo semua pengguna + Total dana tertahan escrow + Pendapatan platform
    const allUsers = await prisma.user.findMany({
      where: { id: { in: users.map((u) => u.id) } },
    });
    const totalUserBalances = allUsers.reduce((sum, u) => sum + u.balance, 0n);

    const activeTxs = await prisma.transaction.findMany({
      where: { status: { in: ['PAID', 'SHIPPED', 'DISPUTED'] } },
    });
    const totalHeldAmount = activeTxs.reduce((sum, t) => sum + t.heldAmount, 0n);

    const platformFeeAgg = await prisma.ledgerEntry.aggregate({
      where: { userId: null, type: 'PLATFORM_FEE' },
      _sum: { amount: true },
    });
    const totalPlatformRevenue = platformFeeAgg._sum.amount || 0n;

    const totalSystemMoney = totalUserBalances + totalHeldAmount + totalPlatformRevenue;

    // Hukum kekekalan uang: Total uang sistem HARUS PERSIS SAMA dengan total kredit eksternal!
    expect(totalSystemMoney).toBe(totalExternalCredits);
  });
});
