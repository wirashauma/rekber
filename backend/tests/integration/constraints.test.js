const { createUser, resetDb, prisma } = require('../helpers');
const { generateTransactionCode } = require('../../src/utils/code');

describe('Database Check Constraints & Integrity Tests', () => {
  beforeEach(async () => {
    await resetDb();
  });

  test('Database menolak saldo negatif pada User (CHECK balance >= 0)', async () => {
    // Attempt to create user with negative balance directly in DB
    await expect(
      prisma.user.create({
        data: {
          name: 'Negative Balance User',
          email: 'negative.balance@example.com',
          password: 'Password123',
          balance: -1000n,
        },
      })
    ).rejects.toThrow(/check_users_balance_non_negative/i);
  });

  test('Database menolak held_amount negatif pada Transaction (CHECK held_amount >= 0)', async () => {
    const buyer = await createUser({ balance: 500000 });
    const seller = await createUser({ balance: 100000 });

    await expect(
      prisma.transaction.create({
        data: {
          code: generateTransactionCode(),
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 50000n,
          heldAmount: -500n, // Invalid negative held_amount
          itemDescription: 'Item Test Negative Hold',
        },
      })
    ).rejects.toThrow(/check_transactions_held_amount_non_negative/i);
  });

  test('Database menolak amount <= 0 pada LedgerEntry (CHECK amount > 0)', async () => {
    const user = await createUser({ balance: 100000 });

    // Amount = 0
    await expect(
      prisma.ledgerEntry.create({
        data: {
          userId: user.id,
          type: 'TOPUP',
          direction: 'CREDIT',
          amount: 0n, // Invalid amount <= 0
          balanceAfter: 100000n,
          idempotencyKey: 'idemp-zero-amount',
        },
      })
    ).rejects.toThrow(/check_ledger_entries_amount_positive/i);

    // Amount < 0
    await expect(
      prisma.ledgerEntry.create({
        data: {
          userId: user.id,
          type: 'ADJUSTMENT',
          direction: 'DEBIT',
          amount: -5000n, // Invalid negative amount
          balanceAfter: 95000n,
          idempotencyKey: 'idemp-negative-amount',
        },
      })
    ).rejects.toThrow(/check_ledger_entries_amount_positive/i);
  });

  test('Database menolak transaksi di mana buyerId == sellerId (CHECK buyer_id <> seller_id)', async () => {
    const user = await createUser({ balance: 100000 });

    await expect(
      prisma.transaction.create({
        data: {
          code: generateTransactionCode(),
          buyerId: user.id,
          sellerId: user.id, // Self transaction directly inserted
          amount: 50000n,
          itemDescription: 'Self Transaction Directly In DB',
        },
      })
    ).rejects.toThrow(/check_transactions_buyer_not_seller/i);
  });

  test('Database menegakkan keunikan kode transaksi 8 karakter (code UNIQUE)', async () => {
    const buyer = await createUser({ balance: 500000 });
    const seller = await createUser({ balance: 100000 });
    const duplicateCode = 'ABCDEFGH';

    await prisma.transaction.create({
      data: {
        code: duplicateCode,
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 25000n,
        itemDescription: 'First Transaction',
      },
    });

    await expect(
      prisma.transaction.create({
        data: {
          code: duplicateCode,
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 30000n,
          itemDescription: 'Second Duplicate Transaction',
        },
      })
    ).rejects.toThrow();
  });
});
