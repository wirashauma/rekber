// =============================================================================
// Edge Cases & Full Coverage Tests for Escrow and Ledger Services
// =============================================================================

const { createUser, resetDb, disconnectDb } = require('../helpers');
const prisma = require('../../src/config/prisma');
const ledgerService = require('../../src/services/ledger.service');
const escrowService = require('../../src/services/escrow.service');

describe('Finance Service Coverage & Edge Cases', () => {
  let buyer;
  let seller;
  let admin;

  beforeAll(async () => {
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  beforeEach(async () => {
    await resetDb();
    buyer = await createUser({
      name: 'Buyer Edge',
      email: 'buyer-edge@example.com',
      role: 'USER',
      balance: 500000n,
    });
    seller = await createUser({
      name: 'Seller Edge',
      email: 'seller-edge@example.com',
      role: 'USER',
      balance: 100000n,
    });
    admin = await createUser({
      name: 'Admin Edge',
      email: 'admin-edge@example.com',
      role: 'ADMIN',
      balance: 0n,
    });
  });

  describe('ledger.service edge cases & error branches', () => {
    test('credit() menolak jika idempotencyKey kosong', async () => {
      await expect(
        prisma.$transaction((tx) =>
          ledgerService.credit(tx, {
            userId: buyer.id,
            amount: 10000,
            type: 'TOPUP',
          })
        )
      ).rejects.toThrow('Idempotency key wajib');
    });

    test('debit() menolak jika idempotencyKey kosong', async () => {
      await expect(
        prisma.$transaction((tx) =>
          ledgerService.debit(tx, {
            userId: buyer.id,
            amount: 10000,
            type: 'ESCROW_HOLD',
          })
        )
      ).rejects.toThrow('Idempotency key wajib');
    });

    test('debit() menolak jika userId kosong', async () => {
      await expect(
        prisma.$transaction((tx) =>
          ledgerService.debit(tx, {
            userId: null,
            amount: 10000,
            type: 'ESCROW_HOLD',
            idempotencyKey: 'debit-no-user',
          })
        )
      ).rejects.toThrow('User ID wajib diisi');
    });

    test('debit() menolak jika userId tidak ditemukan di database', async () => {
      await expect(
        prisma.$transaction((tx) =>
          ledgerService.debit(tx, {
            userId: '00000000-0000-0000-0000-000000000000',
            amount: 10000,
            type: 'ESCROW_HOLD',
            idempotencyKey: 'debit-nonexistent-user',
          })
        )
      ).rejects.toThrow('Pengguna tidak ditemukan');
    });

    test('credit() menangani P2002 race condition idempotency_key', async () => {
      const existingEntry = { id: 'entry-123', idempotencyKey: 'p2002-credit-key' };
      const mockTx = {
        $executeRawUnsafe: jest.fn().mockResolvedValue(1),
        ledgerEntry: {
          findUnique: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce(existingEntry),
          create: jest.fn().mockRejectedValue({
            code: 'P2002',
            meta: { target: ['idempotency_key'] },
          }),
        },
        user: {
          update: jest.fn().mockResolvedValue({ balance: 1000n }),
        },
      };

      const result = await ledgerService.credit(mockTx, {
        userId: buyer.id,
        amount: 1000,
        type: 'TOPUP',
        idempotencyKey: 'p2002-credit-key',
      });
      expect(result).toBe(existingEntry);
    });

    test('debit() menangani P2002 race condition idempotency_key', async () => {
      const existingEntry = { id: 'entry-456', idempotencyKey: 'p2002-debit-key' };
      const mockTx = {
        $executeRawUnsafe: jest.fn().mockResolvedValue(1),
        ledgerEntry: {
          findUnique: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce(existingEntry),
          create: jest.fn().mockRejectedValue({
            code: 'P2002',
            meta: { target: ['idempotency_key'] },
          }),
        },
        user: {
          updateMany: jest.fn().mockResolvedValue({ count: 1 }),
          findUnique: jest.fn().mockResolvedValue({ balance: 500n }),
        },
      };

      const result = await ledgerService.debit(mockTx, {
        userId: buyer.id,
        amount: 1000,
        type: 'ESCROW_HOLD',
        idempotencyKey: 'p2002-debit-key',
      });
      expect(result).toBe(existingEntry);
    });

    test('getLedgerEntries() mengembalikan data dengan cursor pagination', async () => {
      // Create 3 ledger entries
      for (let i = 1; i <= 3; i++) {
        await prisma.$transaction((tx) =>
          ledgerService.credit(tx, {
            userId: buyer.id,
            amount: 1000 * i,
            type: 'TOPUP',
            idempotencyKey: `topup-pagination-${i}`,
          })
        );
      }

      // Fetch first page with limit 2
      const page1 = await ledgerService.getLedgerEntries(buyer.id, { limit: 2 });
      expect(page1.items).toHaveLength(2);
      expect(page1.nextCursor).toBeDefined();

      // Fetch second page using cursor
      const page2 = await ledgerService.getLedgerEntries(buyer.id, {
        cursor: page1.nextCursor,
        limit: 2,
      });
      expect(page2.items.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('escrow.service edge cases & error branches', () => {
    test('createTransaction menolak transaksi diri sendiri (buyer === seller)', async () => {
      await expect(
        escrowService.createTransaction({
          buyerId: buyer.id,
          sellerId: buyer.id,
          amount: 50000,
          itemDescription: 'Self buy',
        })
      ).rejects.toThrow('Pembeli dan penjual tidak boleh orang yang sama');
    });

    test('createTransaction menolak jika penjual tidak ditemukan', async () => {
      await expect(
        escrowService.createTransaction({
          buyerId: buyer.id,
          sellerId: '00000000-0000-0000-0000-000000000000',
          amount: 50000,
          itemDescription: 'Nonexistent seller',
        })
      ).rejects.toThrow('Penjual tidak ditemukan');
    });

    test('createTransaction menolak jika pembeli tidak ditemukan', async () => {
      await expect(
        escrowService.createTransaction({
          buyerId: '00000000-0000-0000-0000-000000000000',
          sellerId: seller.id,
          amount: 50000,
          itemDescription: 'Nonexistent buyer',
        })
      ).rejects.toThrow('Pembeli tidak ditemukan');
    });

    test('createTransaction menolak jika nominal melebihi max_transaction_amount', async () => {
      await expect(
        escrowService.createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 200000000, // 200 million > 100 million max
          itemDescription: 'Too large amount',
        })
      ).rejects.toThrow('melebihi batas maksimal');
    });

    test('cancelPending berhasil membatalkan transaksi status PENDING', async () => {
      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Pending item',
      });

      const cancelled = await escrowService.cancelPending(
        null,
        tx.id,
        buyer.id,
        'Dibatalkan oleh pembeli'
      );
      expect(cancelled.status).toBe('CANCELLED');
      expect(cancelled.cancelReason).toBe('Dibatalkan oleh pembeli');
    });

    test('cancelPending menolak jika transaksi tidak ditemukan', async () => {
      await expect(
        escrowService.cancelPending(null, '00000000-0000-0000-0000-000000000000', buyer.id)
      ).rejects.toThrow('Transaksi tidak ditemukan');
    });

    test('cancelPending menolak jika transaksi bukan status PENDING', async () => {
      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Pending item',
      });
      await escrowService.holdEscrow(null, tx.id, buyer.id);

      await expect(escrowService.cancelPending(null, tx.id, buyer.id)).rejects.toThrow(
        'Status transaksi sudah berubah'
      );
    });

    test('holdEscrow menolak jika transaksi tidak ditemukan atau bukan PENDING', async () => {
      await expect(
        escrowService.holdEscrow(null, '00000000-0000-0000-0000-000000000000', buyer.id)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Test item',
      });
      await escrowService.holdEscrow(null, tx.id, buyer.id);

      await expect(escrowService.holdEscrow(null, tx.id, buyer.id)).rejects.toThrow(
        'Status transaksi sudah berubah'
      );
    });

    test('markShipped menolak jika transaksi tidak ditemukan atau bukan PAID', async () => {
      await expect(
        escrowService.markShipped(null, '00000000-0000-0000-0000-000000000000', seller.id)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Test item',
      });

      await expect(escrowService.markShipped(null, tx.id, seller.id)).rejects.toThrow(
        'Status transaksi sudah berubah'
      );
    });

    test('releaseEscrow menolak jika transaksi tidak ditemukan atau bukan SHIPPED', async () => {
      await expect(
        escrowService.releaseEscrow(null, '00000000-0000-0000-0000-000000000000', buyer.id)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Test item',
      });

      await expect(escrowService.releaseEscrow(null, tx.id, buyer.id)).rejects.toThrow(
        'Status transaksi sudah berubah'
      );
    });

    test('refundEscrow menolak jika transaksi tidak ditemukan atau bukan PAID/DISPUTED', async () => {
      await expect(
        escrowService.refundEscrow(null, '00000000-0000-0000-0000-000000000000', admin.id)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Test item',
      });

      await expect(escrowService.refundEscrow(null, tx.id, admin.id)).rejects.toThrow(
        'Status transaksi sudah berubah'
      );
    });

    test('executeTransition menolak jika transaksi tidak ditemukan atau transisi ilegal', async () => {
      await expect(
        escrowService.executeTransition('00000000-0000-0000-0000-000000000000', 'PAID', buyer)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Test item',
      });

      // PENDING → COMPLETED is illegal
      await expect(escrowService.executeTransition(tx.id, 'COMPLETED', buyer)).rejects.toThrow(
        'Transisi status tidak valid'
      );

      // PENDING → DISPUTED must go via dispute endpoint
      await expect(escrowService.executeTransition(tx.id, 'DISPUTED', buyer)).rejects.toThrow(
        'Transisi status sengketa'
      );

      // Seller cannot pay (only buyer can execute PENDING → PAID)
      await expect(escrowService.executeTransition(tx.id, 'PAID', seller)).rejects.toThrow(
        'Hanya pembeli'
      );
    });

    test('getTransactionById, getTransactionByCode, getTransactions verifikasi lengkap', async () => {
      const tx = await escrowService.createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        amount: 50000,
        itemDescription: 'Query test',
      });

      // getTransactionById
      const byId = await escrowService.getTransactionById(tx.id, buyer.id, buyer.role);
      expect(byId.id).toBe(tx.id);

      await expect(
        escrowService.getTransactionById(
          '00000000-0000-0000-0000-000000000000',
          buyer.id,
          buyer.role
        )
      ).rejects.toThrow('Transaksi tidak ditemukan');

      // getTransactionByCode
      const byCode = await escrowService.getTransactionByCode(tx.code, seller.id, seller.role);
      expect(byCode.id).toBe(tx.id);

      await expect(
        escrowService.getTransactionByCode('NONEXIST', buyer.id, buyer.role)
      ).rejects.toThrow('Transaksi tidak ditemukan');

      // getTransactions
      const list = await escrowService.getTransactions(buyer.id);
      expect(list.length).toBeGreaterThanOrEndWith
        ? expect(list.length).toBeGreaterThanOrEqual(1)
        : expect(list.length).toBeGreaterThanOrEqual(1);
      expect(list[0].id).toBe(tx.id);
    });
  });
});
