// =============================================================================
// Integrity Tests: Fee Rounding Invariants, SQL Constraints, Auth & Reconcile CLI
// =============================================================================

const { spawnSync } = require('child_process');
const path = require('path');
const request = require('supertest');
const { createApp } = require('../../src/app');
const prisma = require('../../src/config/prisma');
const { calculateFee } = require('../../src/utils/money');
const { createUser, tokenFor, createTransaction, resetDb, disconnectDb } = require('../helpers');

const app = createApp();

describe('Finance Integrity Tests: Fee Precision, SQL Constraints, IDOR & Audit Script', () => {
  beforeEach(async () => {
    await resetDb();
  });

  afterAll(async () => {
    await disconnectDb();
  });

  /**
   * TUGAS 7:
   * Pembulatan fee untuk harga 1.000; 1.001; 99.999; 1.000.000; 4.999.999 pada tiap feePayer:
   * buyerFee + sellerFee = total fee; dana release + fee = dana tertahan.
   */
  describe('7. Pembulatan Fee & Presisi Invarian Matematika', () => {
    const testCases = [1000, 1001, 99999, 1000000, 4999999];
    const feePayers = ['BUYER', 'SELLER', 'SPLIT'];

    testCases.forEach((amount) => {
      feePayers.forEach((payer) => {
        test(`Nominal Rp ${amount.toLocaleString('id-ID')} dengan feePayer ${payer}: fee & dana tertahan selalu presisi`, () => {
          const { totalFee, buyerFee, sellerFee } = calculateFee({
            amount,
            feePercent: 2,
            feeMin: 1000,
            feePayer: payer,
          });

          // Invarian 1: buyerFee + sellerFee HARUS sama dengan totalFee
          expect(buyerFee + sellerFee).toBe(totalFee);

          // Invarian 2: Dana yang ditahan di awal = amount + buyerFee
          const heldAmount = BigInt(amount) + buyerFee;

          // Invarian 3: Dana yang diterima penjual saat release = amount - sellerFee
          const sellerRelease = BigInt(amount) - sellerFee;

          // Invarian 4: Dana release (penjual) + Total Fee (platform) HARUS tepat sama dengan dana tertahan!
          // (amount - sellerFee) + (buyerFee + sellerFee) = amount + buyerFee = heldAmount
          expect(sellerRelease + totalFee).toBe(heldAmount);

          // Pengecekan spesifik per pembayar:
          if (payer === 'BUYER') {
            expect(buyerFee).toBe(totalFee);
            expect(sellerFee).toBe(0n);
            expect(sellerRelease).toBe(BigInt(amount));
          } else if (payer === 'SELLER') {
            expect(buyerFee).toBe(0n);
            expect(sellerFee).toBe(totalFee);
            expect(heldAmount).toBe(BigInt(amount));
          } else if (payer === 'SPLIT') {
            // Pada pembagian SPLIT ganjil, buyer menanggung selisih 1 rupiah (ceiling)
            expect(buyerFee >= sellerFee).toBe(true);
            expect(buyerFee - sellerFee <= 1n).toBe(true);
          }
        });
      });
    });
  });

  /**
   * TUGAS 8:
   * Constraint database: saldo negatif dan buyer=seller ditolak langsung di SQL.
   */
  describe('8. Database Check Constraints di Level SQL Engine', () => {
    test('SQL menolak saldo negatif pada tabel users (check_users_balance_non_negative)', async () => {
      const user = await createUser({ balance: 50000 });

      // Coba paksa update balance menjadi negatif via SQL mentah
      await expect(
        prisma.$executeRawUnsafe('UPDATE "users" SET "balance" = -1 WHERE "id" = $1', user.id)
      ).rejects.toThrow();
    });

    test('SQL menolak transaksi di mana buyerId sama dengan sellerId (check_transactions_buyer_not_seller)', async () => {
      const user = await createUser();

      // Coba paksa insert transaksi buyerId == sellerId via SQL mentah
      await expect(
        prisma.$executeRawUnsafe(
          `INSERT INTO "transactions" ("id", "buyer_id", "seller_id", "amount", "status", "code", "item_description", "updatedAt")
           VALUES (gen_random_uuid(), $1, $1, 10000, 'PENDING', 'SQLCHECK', 'Deskripsi barang', NOW())`,
          user.id
        )
      ).rejects.toThrow();
    });

    test('SQL menolak held_amount negatif pada transaksi (check_transactions_held_amount_non_negative)', async () => {
      const tx = await createTransaction();

      await expect(
        prisma.$executeRawUnsafe(
          'UPDATE "transactions" SET "held_amount" = -500 WHERE "id" = $1',
          tx.id
        )
      ).rejects.toThrow();
    });

    test('SQL menolak entri buku besar bernilai non-positif (check_ledger_entries_amount_positive)', async () => {
      const user = await createUser();

      // Coba insert amount = 0 ke ledger_entries
      await expect(
        prisma.$executeRawUnsafe(
          `INSERT INTO "ledger_entries" ("id", "user_id", "type", "direction", "amount", "balance_after", "idempotency_key", "created_at")
           VALUES (gen_random_uuid(), $1, 'ADJUSTMENT', 'CREDIT', 0, 1000, 'sql:zero:amt', NOW())`,
          user.id
        )
      ).rejects.toThrow();
    });
  });

  /**
   * TUGAS 9:
   * Otorisasi: user ketiga tidak bisa baca/ubah transaksi (IDOR);
   * USER tidak dapat melakukan transisi khusus ADMIN;
   * token user nonaktif ditolak.
   */
  describe('9. Kontrol Akses, Otorisasi, IDOR & Proteksi Akun Nonaktif', () => {
    test('IDOR: Pihak ketiga ditolak saat membaca detail transaksi via ID (403 Forbidden)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const stranger = await createUser();

      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/${tx.id}`)
        .set('Authorization', `Bearer ${tokenFor(stranger)}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('tidak memiliki akses');
    });

    test('IDOR: Pihak ketiga ditolak saat mencari transaksi via kode (404 Not Found)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const stranger = await createUser();

      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/code/${tx.code}`)
        .set('Authorization', `Bearer ${tokenFor(stranger)}`);

      // 404 diberikan agar tidak membocorkan eksistensi kode ke pihak ketiga
      expect(res.status).toBe(404);
    });

    test('IDOR: Pihak ketiga ditolak saat mencoba mengubah status transaksi pihak lain (403 Forbidden)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const stranger = await createUser();

      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'PAID',
      });

      const res = await request(app)
        .put(`/api/transactions/${tx.id}/status`)
        .set('Authorization', `Bearer ${tokenFor(stranger)}`)
        .send({ status: 'REFUNDED' });

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('tidak memiliki akses');
    });

    test('USER biasa ditolak saat mencoba melakukan aksi wewenang khusus ADMIN (403 Forbidden)', async () => {
      const buyer = await createUser();
      const seller = await createUser();

      const tx = await createTransaction({
        buyerId: buyer.id,
        sellerId: seller.id,
        status: 'PAID',
      });

      // Pembeli mencoba melakukan refund paksa tanpa wewenang admin (PAID -> REFUNDED wewenang SELLER atau ADMIN)
      const res = await request(app)
        .put(`/api/transactions/${tx.id}/status`)
        .set('Authorization', `Bearer ${tokenFor(buyer)}`)
        .send({ status: 'REFUNDED' });

      expect(res.status).toBe(403);
    });

    test('Token autentikasi pengguna nonaktif (isActive: false) ditolak oleh sistem (403 Forbidden)', async () => {
      const deactivatedUser = await createUser({ isActive: false });

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${tokenFor(deactivatedUser)}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('Akun Anda telah dinonaktifkan');
    });
  });

  /**
   * TUGAS 10:
   * Script reconcile: exit 0 pada data sehat, non-nol pada data yang sengaja dirusak (di DB test).
   */
  describe('10. Verifikasi CLI Script scripts/reconcile.js', () => {
    const scriptPath = path.resolve(__dirname, '../../scripts/reconcile.js');

    test('Script reconcile keluar dengan exit code 0 pada database yang sehat', () => {
      const result = spawnSync(process.execPath, [scriptPath], {
        env: {
          ...process.env,
          NODE_ENV: 'test',
          DATABASE_URL: process.env.DATABASE_URL_TEST,
        },
        encoding: 'utf-8',
      });

      expect(result.status).toBe(0);
      expect(result.stdout).toContain('REKONSILIASI BERHASIL');
    });

    test('Script reconcile keluar dengan exit code non-nol (exit 1) saat mendeteksi saldo dirusak', async () => {
      const user = await createUser({ balance: 100000 });

      // Rusak data secara sengaja di database test tanpa mencatat entri buku besar
      await prisma.$executeRawUnsafe(
        'UPDATE "users" SET "balance" = "balance" + 88888 WHERE "id" = $1',
        user.id
      );

      const result = spawnSync(process.execPath, [scriptPath], {
        env: {
          ...process.env,
          NODE_ENV: 'test',
          DATABASE_URL: process.env.DATABASE_URL_TEST,
        },
        encoding: 'utf-8',
      });

      expect(result.status).not.toBe(0);
      expect(result.status).toBe(1);
      const combinedOutput = (result.stdout || '') + (result.stderr || '');
      expect(combinedOutput).toContain('REKONSILIASI GAGAL');
      expect(combinedOutput).toContain('SELISIH SALDO PENGGUNA');
    });
  });
});
