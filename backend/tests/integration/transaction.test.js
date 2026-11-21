const request = require('supertest');
const app = require('../../src/app');
const { createUser, tokenFor, createTransaction, prisma } = require('../helpers');

describe('Karakterisasi Transaksi Escrow Backend (/api/transactions)', () => {
  describe('POST /api/transactions (Pembuatan Transaksi)', () => {
    test('Sukses membuat transaksi baru oleh pembeli dengan status awal PENDING', async () => {
      const buyer = await createUser({ name: 'Pembeli Satu', balance: 500000 });
      const seller = await createUser({ name: 'Penjual Satu', balance: 0 });
      const token = tokenFor(buyer);

      const payload = {
        sellerId: seller.id,
        amount: 150000,
        itemDescription: 'Pembelian Akun Game Online Level 100',
      };

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send(payload);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.status).toBe('PENDING');
      expect(res.body.data.amount).toBe(150000);
      expect(res.body.data.buyerId).toBe(buyer.id);
      expect(res.body.data.sellerId).toBe(seller.id);
    });

    test('Gagal jika amount kurang dari Rp 1.000 (422 Unprocessable Entity)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const token = tokenFor(buyer);

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send({
          sellerId: seller.id,
          amount: 500, // min Rp 1.000
          itemDescription: 'Barang Murah Banget',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].field).toBe('amount');
    });

    test('Gagal jika itemDescription kurang dari 5 karakter (422 Unprocessable Entity)', async () => {
      const buyer = await createUser();
      const seller = await createUser();
      const token = tokenFor(buyer);

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send({
          sellerId: seller.id,
          amount: 50000,
          itemDescription: 'Test', // < 5 karakter
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.errors[0].field).toBe('itemDescription');
    });

    test('Gagal jika pembeli dan penjual adalah user yang sama (400 Bad Request)', async () => {
      const buyer = await createUser();
      const token = tokenFor(buyer);

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send({
          sellerId: buyer.id,
          amount: 50000,
          itemDescription: 'Beli barang dari diri sendiri',
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Pembeli dan penjual tidak boleh orang yang sama');
    });

    test('Gagal jika lawan transaksi tidak ditemukan (404 Not Found)', async () => {
      const buyer = await createUser();
      const token = tokenFor(buyer);

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send({
          sellerId: '00000000-0000-0000-0000-000000000000',
          amount: 50000,
          itemDescription: 'Beli barang penjual fiktif',
        });

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Penjual tidak ditemukan');
    });

    test('Gagal jika tidak ada buyerId maupun sellerId pada payload (400 Bad Request)', async () => {
      const user = await createUser();
      const token = tokenFor(user);

      const res = await request(app)
        .post('/api/transactions')
        .set('Authorization', `Bearer ${token}`)
        .send({
          amount: 50000,
          itemDescription: 'Transaksi tanpa lawan',
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain(
        'Lawan transaksi (buyerId atau sellerId) harus ditentukan'
      );
    });
  });

  describe('GET /api/transactions (Daftar & Detail Transaksi)', () => {
    test('Mengambil daftar transaksi yang melibatkan user terkait', async () => {
      const user1 = await createUser({ name: 'User Utama' });
      const user2 = await createUser({ name: 'User Lawan' });
      const user3 = await createUser({ name: 'User Asing' });

      await createTransaction({ buyerId: user1.id, sellerId: user2.id, amount: 100000 });
      await createTransaction({ buyerId: user2.id, sellerId: user1.id, amount: 200000 });
      await createTransaction({ buyerId: user2.id, sellerId: user3.id, amount: 300000 }); // tidak melibatkan user1

      const token = tokenFor(user1);
      const res = await request(app)
        .get('/api/transactions')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(2);
    });

    test('Detail transaksi dapat diakses oleh Pembeli', async () => {
      const buyer = await createUser({ name: 'Pembeli' });
      const seller = await createUser({ name: 'Penjual' });
      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/${tx.id}`)
        .set('Authorization', `Bearer ${tokenFor(buyer)}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(tx.id);
    });

    test('Detail transaksi dapat diakses oleh Penjual', async () => {
      const buyer = await createUser({ name: 'Pembeli' });
      const seller = await createUser({ name: 'Penjual' });
      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/${tx.id}`)
        .set('Authorization', `Bearer ${tokenFor(seller)}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(tx.id);
    });

    test('Detail transaksi dapat diakses oleh ADMIN platform', async () => {
      const buyer = await createUser({ name: 'Pembeli' });
      const seller = await createUser({ name: 'Penjual' });
      const admin = await createUser({ name: 'Admin Rekber', role: 'ADMIN' });
      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/${tx.id}`)
        .set('Authorization', `Bearer ${tokenFor(admin)}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(tx.id);
    });

    test('403 Forbidden jika diakses oleh user non-peserta (bukan buyer, bukan seller, bukan admin)', async () => {
      const buyer = await createUser({ name: 'Pembeli' });
      const seller = await createUser({ name: 'Penjual' });
      const stranger = await createUser({ name: 'Orang Ketiga' });
      const tx = await createTransaction({ buyerId: buyer.id, sellerId: seller.id });

      const res = await request(app)
        .get(`/api/transactions/${tx.id}`)
        .set('Authorization', `Bearer ${tokenFor(stranger)}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Anda tidak memiliki akses ke transaksi ini');
    });

    test('404 Not Found jika transaksi tidak ditemukan', async () => {
      const user = await createUser();
      const res = await request(app)
        .get('/api/transactions/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${tokenFor(user)}`);

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });

    test('422 Unprocessable Entity jika ID bukan format UUID', async () => {
      const user = await createUser();
      const res = await request(app)
        .get('/api/transactions/bukan-uuid')
        .set('Authorization', `Bearer ${tokenFor(user)}`);

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/transactions/:id/status (Transisi State Machine & Efek Saldo)', () => {
    describe('Alur PENDING → PAID', () => {
      test('Sukses oleh Buyer jika saldo mencukupi: status menjadi PAID & saldo buyer terpotong', async () => {
        const buyer = await createUser({ name: 'Buyer Saldo Cukup', balance: 300000 });
        const seller = await createUser({ name: 'Seller', balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 200000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('PAID');

        // Verifikasi saldo buyer berkurang
        const updatedBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
        expect(updatedBuyer.balance).toBe(100000n);
      });

      test('Gagal oleh Buyer jika saldo tidak mencukupi (400 Bad Request)', async () => {
        const buyer = await createUser({ name: 'Buyer Miskin', balance: 50000 });
        const seller = await createUser({ name: 'Seller', balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 200000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(400);
        expect(res.body.success).toBe(false);
        expect(res.body.message).toContain('Saldo tidak mencukupi');

        // Saldo buyer tidak berubah
        const currentBuyer = await prisma.user.findUnique({ where: { id: buyer.id } });
        expect(currentBuyer.balance).toBe(50000n);
      });

      test('Gagal jika transisi PENDING → PAID dipicu oleh Penjual (403 Forbidden)', async () => {
        const buyer = await createUser({ balance: 300000 });
        const seller = await createUser({ balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(403);
        expect(res.body.message).toContain('Hanya pembeli yang dapat melakukan aksi ini');
      });

      test('Gagal jika transisi PENDING → PAID dipicu oleh orang ketiga (403 Forbidden)', async () => {
        const buyer = await createUser({ balance: 300000 });
        const seller = await createUser();
        const stranger = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(stranger)}`)
          .send({ status: 'PAID' });

        expect(res.status).toBe(403);
      });
    });

    describe('Alur SHIPPED → COMPLETED', () => {
      test('Sukses oleh Buyer: status menjadi COMPLETED & dana escrow dirilis ke saldo Penjual', async () => {
        const buyer = await createUser({ name: 'Buyer', balance: 0 });
        const seller = await createUser({ name: 'Seller', balance: 50000 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 150000,
          status: 'SHIPPED',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'COMPLETED' });

        expect(res.status).toBe(200);
        expect(res.body.data.status).toBe('COMPLETED');

        // Verifikasi saldo seller bertambah Rp 150.000 menjadi Rp 200.000
        const updatedSeller = await prisma.user.findUnique({ where: { id: seller.id } });
        expect(updatedSeller.balance).toBe(200000n);
      });

      test('Gagal jika transisi SHIPPED → COMPLETED dicoba oleh Penjual sendiri (403 Forbidden)', async () => {
        const buyer = await createUser();
        const seller = await createUser({ balance: 0 });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 150000,
          status: 'SHIPPED',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(seller)}`)
          .send({ status: 'COMPLETED' });

        expect(res.status).toBe(403);
        expect(res.body.message).toContain('Hanya pembeli yang dapat melakukan aksi ini');
      });
    });

    describe('Alur PAID → CANCELLED (Karakterisasi Perilaku Saat Ini)', () => {
      test('Admin mencoba PAID → CANCELLED ditolak 400 karena belum didaftarkan di VALID_TRANSITIONS', async () => {
        const buyer = await createUser({ balance: 100000 });
        const seller = await createUser();
        const admin = await createUser({ role: 'ADMIN' });
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'PAID',
        });

        // Pada kode saat ini, VALID_TRANSITIONS['PAID'] hanya berisi ['SHIPPED', 'DISPUTED'].
        // Walaupun ada logika refund di line 225, transisi ini tertahan di validasi transisi (line 168).
        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(admin)}`)
          .send({ status: 'CANCELLED' });

        expect(res.status).toBe(400);
        expect(res.body.success).toBe(false);
        expect(res.body.message).toContain('Transisi status tidak valid: PAID → CANCELLED');
      });
    });

    describe('Transisi Invalid Lainnya', () => {
      test('Ditolak jika lompat status tidak valid: PENDING → COMPLETED (400 Bad Request)', async () => {
        const buyer = await createUser({ balance: 500000 });
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'PENDING',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'COMPLETED' });

        expect(res.status).toBe(400);
        expect(res.body.success).toBe(false);
        expect(res.body.message).toContain('Transisi status tidak valid');
      });

      test('Ditolak jika mencoba mengubah transaksi yang sudah COMPLETED (terminal state) (400)', async () => {
        const buyer = await createUser();
        const seller = await createUser();
        const tx = await createTransaction({
          buyerId: buyer.id,
          sellerId: seller.id,
          amount: 100000,
          status: 'COMPLETED',
        });

        const res = await request(app)
          .put(`/api/transactions/${tx.id}/status`)
          .set('Authorization', `Bearer ${tokenFor(buyer)}`)
          .send({ status: 'PENDING' });

        expect(res.status).toBe(400);
        expect(res.body.success).toBe(false);
        expect(res.body.message).toContain('Transisi status tidak valid');
      });
    });
  });

  describe('Perilaku Transaksi & Wallet yang Diketahui Salah / Akan Diganti', () => {
    test.todo(
      'Top-up saldo virtual instan tanpa verifikasi payment gateway (akan diganti di Prompt 8)'
    );
    test.todo(
      'Withdraw saldo instan lama tanpa verifikasi rekening bank/approval admin (akan diganti di Prompt 9)'
    );
    test.todo(
      'DISPUTED sebagai terminal state tanpa alur mediasi resolusi admin (akan diubah di Prompt 11)'
    );
  });
});
