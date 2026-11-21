// =============================================================================
// Idempotency Tests: Replay Resistance in Ledger Mutations
// =============================================================================

const prisma = require('../../src/config/prisma');
const ledgerService = require('../../src/services/ledger.service');
const { createUser, resetDb, disconnectDb } = require('../helpers');

describe('Finance Idempotency Tests: Zero Double-Effect Guarantee', () => {
  beforeEach(async () => {
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  /**
   * TUGAS 5:
   * Replay idempotencyKey pada ledger.service → tanpa efek ganda.
   */
  describe('Idempotency Replay pada credit()', () => {
    test('Replay sekuensial credit(): mengembalikan entri asli tanpa menambah saldo ganda', async () => {
      const user = await createUser({ balance: 100000 });
      const idempotencyKey = `idemp:credit:seq:${Date.now()}`;

      // Panggilan 1
      const res1 = await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
        })
      );

      // Panggilan 2, 3, 4 (replay)
      const res2 = await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
        })
      );
      const res3 = await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
        })
      );

      expect(res2.id).toBe(res1.id);
      expect(res3.id).toBe(res1.id);
      expect(res1.balanceAfter).toBe(150000n);

      // Verifikasi saldo di DB hanya bertambah tepat 50.000 (menjadi 150.000)
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(150000n);

      // Hanya ada 1 baris di tabel ledger_entries untuk idempotencyKey ini
      const entries = await prisma.ledgerEntry.findMany({ where: { idempotencyKey } });
      expect(entries).toHaveLength(1);
    });

    test('Replay paralel credit(): 10 request bersamaan dengan idempotencyKey sama → saldo bertambah 1x', async () => {
      const user = await createUser({ balance: 200000 });
      const idempotencyKey = `idemp:credit:parallel:${Date.now()}`;

      // 10 request kredit serentak
      const promises = Array.from({ length: 10 }, () =>
        prisma.$transaction((tx) =>
          ledgerService.credit(tx, {
            userId: user.id,
            amount: 100000,
            type: 'TOPUP',
            idempotencyKey,
          })
        )
      );

      const results = await Promise.all(promises);

      // Semua pemanggil menerima ID entri yang sama
      const firstId = results[0].id;
      for (const res of results) {
        expect(res.id).toBe(firstId);
        expect(res.balanceAfter).toBe(300000n);
      }

      // Saldo di DB bertambah tepat sekali menjadi 300.000
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(300000n);

      // Jumlah baris ledger tepat 1
      const count = await prisma.ledgerEntry.count({ where: { idempotencyKey } });
      expect(count).toBe(1);
    });
  });

  describe('Idempotency Replay pada debit()', () => {
    test('Replay sekuensial debit(): mengembalikan entri asli tanpa memotong saldo ganda', async () => {
      const user = await createUser({ balance: 300000 });
      const idempotencyKey = `idemp:debit:seq:${Date.now()}`;

      // Panggilan 1
      const res1 = await prisma.$transaction((tx) =>
        ledgerService.debit(tx, {
          userId: user.id,
          amount: 70000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        })
      );

      // Panggilan 2, 3 (replay)
      const res2 = await prisma.$transaction((tx) =>
        ledgerService.debit(tx, {
          userId: user.id,
          amount: 70000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        })
      );
      const res3 = await prisma.$transaction((tx) =>
        ledgerService.debit(tx, {
          userId: user.id,
          amount: 70000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        })
      );

      expect(res2.id).toBe(res1.id);
      expect(res3.id).toBe(res1.id);
      expect(res1.balanceAfter).toBe(230000n);

      // Saldo di DB terpotong tepat sekali menjadi 230.000
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(230000n);

      const count = await prisma.ledgerEntry.count({ where: { idempotencyKey } });
      expect(count).toBe(1);
    });

    test('Replay paralel debit(): 10 request bersamaan dengan idempotencyKey sama → saldo terpotong 1x', async () => {
      const user = await createUser({ balance: 500000 });
      const idempotencyKey = `idemp:debit:parallel:${Date.now()}`;

      // 10 request debit serentak dengan idempotencyKey sama
      const promises = Array.from({ length: 10 }, () =>
        prisma.$transaction((tx) =>
          ledgerService.debit(tx, {
            userId: user.id,
            amount: 150000,
            type: 'ESCROW_HOLD',
            idempotencyKey,
          })
        )
      );

      const results = await Promise.all(promises);

      const firstId = results[0].id;
      for (const res of results) {
        expect(res.id).toBe(firstId);
        expect(res.balanceAfter).toBe(350000n);
      }

      // Saldo terpotong tepat 1 kali menjadi 350.000
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(350000n);

      const count = await prisma.ledgerEntry.count({ where: { idempotencyKey } });
      expect(count).toBe(1);
    });
  });

  describe('Idempotency Replay pada kredit pendapatan platform (userId: null)', () => {
    test('Replay fee platform tidak menggandakan pendapatan platform', async () => {
      const idempotencyKey = `idemp:platform:fee:${Date.now()}`;

      const res1 = await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: null,
          amount: 4000,
          type: 'PLATFORM_FEE',
          idempotencyKey,
        })
      );

      const res2 = await prisma.$transaction((tx) =>
        ledgerService.credit(tx, {
          userId: null,
          amount: 4000,
          type: 'PLATFORM_FEE',
          idempotencyKey,
        })
      );

      expect(res2.id).toBe(res1.id);

      const feeEntries = await prisma.ledgerEntry.findMany({
        where: { idempotencyKey },
      });
      expect(feeEntries).toHaveLength(1);
    });
  });
});
