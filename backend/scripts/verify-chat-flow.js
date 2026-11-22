// =============================================================================
// Manual Verification Script: Realtime Chat Flow (Prompt 13)
// =============================================================================
// Simulates 2 Socket.IO clients (Buyer & Seller) exchanging real-time messages,
// typing indicators, and read receipts in a transaction room.

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env.test') });
require('../src/utils/money');
const http = require('http');
const ioClient = require('socket.io-client');
const app = require('../src/app');
const { initSocket, closeSocket } = require('../src/socket');
const prisma = require('../src/config/prisma');
const { createUser, tokenFor, createTransaction, resetDb } = require('../tests/helpers');

const runVerification = async () => {
  console.log('--- [PROMPT 13] Memulai Verifikasi Manual Percakapan Realtime Socket.IO ---');

  // 1. Jalankan HTTP Server dengan Socket.IO
  const server = http.createServer(app);
  initSocket(server);

  await new Promise((resolve) => {
    server.listen(0, resolve);
  });
  const port = server.address().port;
  console.log(`[1] Server HTTP + Socket.IO aktif pada port: ${port}`);

  try {
    // 2. Siapkan data pengujian
    await resetDb();
    const buyer = await createUser({ name: 'Budi (Pembeli)', balance: 500000 });
    const seller = await createUser({ name: 'Siti (Penjual)', balance: 200000 });
    const buyerToken = tokenFor(buyer);
    const sellerToken = tokenFor(seller);

    const transaction = await createTransaction({
      buyerId: buyer.id,
      sellerId: seller.id,
      amount: 150000,
      status: 'PAID',
    });
    console.log(
      `[2] Data dibuat: Transaksi ${transaction.code} (ID: ${transaction.id}), Pembeli=${buyer.name}, Penjual=${seller.name}`
    );

    // 3. Hubungkan kedua klien soket terautentikasi JWT
    const buyerSocket = ioClient(`http://localhost:${port}`, {
      auth: { token: buyerToken },
      transports: ['websocket'],
    });

    const sellerSocket = ioClient(`http://localhost:${port}`, {
      auth: { token: sellerToken },
      transports: ['websocket'],
    });

    await Promise.all([
      new Promise((res) => buyerSocket.on('connect', res)),
      new Promise((res) => sellerSocket.on('connect', res)),
    ]);
    console.log('[3] Kedua klien soket (Pembeli & Penjual) berhasil handshake JWT!');

    // 4. Kedua klien bergabung ke room transaksi
    const [buyerJoin, sellerJoin] = await Promise.all([
      new Promise((res) => buyerSocket.emit('join', { transactionId: transaction.id }, res)),
      new Promise((res) => sellerSocket.emit('join', { transactionId: transaction.id }, res)),
    ]);
    console.log(`[4] Bergabung ke room: Pembeli=${buyerJoin.room}, Penjual=${sellerJoin.room}`);

    // 5. Pembeli mengirim pesan -> Penjual menerima event message:new
    const sellerReceivedPromise = new Promise((resolve) => {
      sellerSocket.on('message:new', (msg) => {
        resolve(msg);
      });
    });

    buyerSocket.emit('message:send', {
      transactionId: transaction.id,
      type: 'TEXT',
      body: 'Halo Mbak Siti, apakah barang siap dikirim hari ini?',
    });

    const msg1 = await sellerReceivedPromise;
    console.log(
      `[5] Penjual menerima pesan realtime [message:new]:\n    "${msg1.sender?.name || 'Pembeli'}": "${msg1.body}"`
    );

    // 6. Penjual mulai mengetik -> Pembeli menerima indikator typing
    const buyerTypingPromise = new Promise((resolve) => {
      buyerSocket.on('typing', (data) => {
        resolve(data);
      });
    });

    sellerSocket.emit('typing', {
      transactionId: transaction.id,
      isTyping: true,
    });

    const typingEvt = await buyerTypingPromise;
    console.log(
      `[6] Pembeli menerima indikator pengetikan [typing]: "${typingEvt.name}" sedang mengetik (isTyping: ${typingEvt.isTyping})`
    );

    // 7. Penjual membalas pesan -> Pembeli menerima event message:new
    const buyerReceivedPromise = new Promise((resolve) => {
      buyerSocket.on('message:new', (msg) => {
        if (msg.senderId === seller.id) {
          resolve(msg);
        }
      });
    });

    sellerSocket.emit('message:send', {
      transactionId: transaction.id,
      type: 'TEXT',
      body: 'Halo Mas Budi! Siap, barang sudah selesai dipacking dan kurir pickup sore ini ya.',
    });

    const msg2 = await buyerReceivedPromise;
    console.log(
      `[7] Pembeli menerima balasan [message:new]:\n    "${msg2.sender?.name || 'Penjual'}": "${msg2.body}"`
    );

    // 8. Pembeli membaca pesan -> Penjual menerima event message:read
    const sellerReadPromise = new Promise((resolve) => {
      sellerSocket.on('message:read', (data) => {
        resolve(data);
      });
    });

    buyerSocket.emit('message:read', {
      transactionId: transaction.id,
    });

    const readEvt = await sellerReadPromise;
    console.log(
      `[8] Penjual menerima konfirmasi baca [message:read]: Pembeli membaca pesan pada ${readEvt.lastReadAt}`
    );

    // Tutup koneksi soket
    buyerSocket.disconnect();
    sellerSocket.disconnect();

    console.log(
      '=== [OK] UJI MANUAL DUA KLIEN SOKET SALING KIRIM PESAN REALTIME BERHASIL 100% ==='
    );
  } finally {
    await closeSocket();
    await new Promise((resolve) => server.close(resolve));
    await prisma.$disconnect();
  }
};

runVerification()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Gagal menjalankan verifikasi chat:', err);
    process.exit(1);
  });
