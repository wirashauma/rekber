// =============================================================================
// Unit Tests: src/services/ledger.service.js
// =============================================================================

const prisma = require('../../src/config/prisma');
const ledgerService = require('../../src/services/ledger.service');
const { createUser, resetDb, disconnectDb } = require('../helpers');

describe('Unit Test: src/services/ledger.service.js', () => {
  beforeEach(async () => {
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  describe('credit()', () => {
    test('Kredit saldo user: saldo bertambah dan LedgerEntry tercatat dengan balanceAfter yang benar', async () => {
      const user = await createUser({ balance: 100000 });
      const idempotencyKey = `test:credit:${Date.now()}`;

      const entry = await prisma.$transaction(async (tx) => {
        return await ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
          referenceType: 'PAYMENT',
          referenceId: 'ref-123',
        });
      });

      expect(entry).toBeDefined();
      expect(entry.userId).toBe(user.id);
      expect(entry.direction).toBe('CREDIT');
      expect(entry.amount).toBe(50000n);
      expect(entry.balanceAfter).toBe(150000n);
      expect(entry.idempotencyKey).toBe(idempotencyKey);

      // Verifikasi user di DB
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(150000n);
    });

    test('Kredit pendapatan platform (userId: null): tidak mengubah saldo user manapun', async () => {
      const idempotencyKey = `test:platform:fee:${Date.now()}`;

      const entry = await prisma.$transaction(async (tx) => {
        return await ledgerService.credit(tx, {
          userId: null,
          amount: 5000,
          type: 'PLATFORM_FEE',
          idempotencyKey,
          referenceType: 'TRANSACTION',
        });
      });

      expect(entry).toBeDefined();
      expect(entry.userId).toBeNull();
      expect(entry.direction).toBe('CREDIT');
      expect(entry.type).toBe('PLATFORM_FEE');
      expect(entry.amount).toBe(5000n);
      expect(entry.balanceAfter).toBe(5000n);
    });

    test('Idempotency replay pada credit: mengembalikan entri yang ada tanpa menambah saldo ganda', async () => {
      const user = await createUser({ balance: 100000 });
      const idempotencyKey = `test:credit:replay:${Date.now()}`;

      // Panggilan pertama
      const entry1 = await prisma.$transaction(async (tx) => {
        return await ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
        });
      });

      // Panggilan kedua (replay jaringan / retry)
      const entry2 = await prisma.$transaction(async (tx) => {
        return await ledgerService.credit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'TOPUP',
          idempotencyKey,
        });
      });

      expect(entry2.id).toBe(entry1.id);
      expect(entry2.balanceAfter).toBe(150000n);

      // Saldo user harus tetap 150000n, bukan 200000n
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(150000n);
    });
  });

  describe('debit()', () => {
    test('Debit saldo user jika saldo cukup: saldo berkurang dan LedgerEntry tercatat', async () => {
      const user = await createUser({ balance: 200000 });
      const idempotencyKey = `test:debit:${Date.now()}`;

      const entry = await prisma.$transaction(async (tx) => {
        return await ledgerService.debit(tx, {
          userId: user.id,
          amount: 75000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        });
      });

      expect(entry).toBeDefined();
      expect(entry.userId).toBe(user.id);
      expect(entry.direction).toBe('DEBIT');
      expect(entry.amount).toBe(75000n);
      expect(entry.balanceAfter).toBe(125000n);

      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(125000n);
    });

    test('UPDATE bersyarat menolak debit jika saldo tidak mencukupi (400 Bad Request)', async () => {
      const user = await createUser({ balance: 30000 });
      const idempotencyKey = `test:debit:insufficient:${Date.now()}`;

      await expect(
        prisma.$transaction(async (tx) => {
          return await ledgerService.debit(tx, {
            userId: user.id,
            amount: 50000,
            type: 'ESCROW_HOLD',
            idempotencyKey,
          });
        })
      ).rejects.toMatchObject({
        statusCode: 400,
        message: expect.stringContaining('Saldo tidak mencukupi'),
      });

      // Saldo tidak berkurang
      const currentUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(currentUser.balance).toBe(30000n);
    });

    test('Idempotency replay pada debit: mengembalikan entri yang ada tanpa memotong saldo ganda', async () => {
      const user = await createUser({ balance: 200000 });
      const idempotencyKey = `test:debit:replay:${Date.now()}`;

      // Panggilan pertama
      const entry1 = await prisma.$transaction(async (tx) => {
        return await ledgerService.debit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        });
      });

      // Panggilan kedua
      const entry2 = await prisma.$transaction(async (tx) => {
        return await ledgerService.debit(tx, {
          userId: user.id,
          amount: 50000,
          type: 'ESCROW_HOLD',
          idempotencyKey,
        });
      });

      expect(entry2.id).toBe(entry1.id);
      expect(entry2.balanceAfter).toBe(150000n);

      // Saldo user tetap 150000n, bukan 100000n
      const updatedUser = await prisma.user.findUnique({ where: { id: user.id } });
      expect(updatedUser.balance).toBe(150000n);
    });
  });
});
